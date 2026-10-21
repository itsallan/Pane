import Domain
import Foundation
import Synchronization
@preconcurrency import VLCKit

/// Answers VLC's login dialogs from the credential the caller already looked up, once per request.
/// A second prompt for the same request means the share rejected it, so the dialog is dismissed and the
/// request is marked rejected, which callers turn into `.authenticationRequired`.
///
/// libvlc takes one dialog handler per instance, so there's one responder per `VLCLibrary`.
final class LoginResponder: NSObject, Sendable {
    private struct Request {
        let host: String
        let credential: NetworkCredential?
        var isAnswered = false
        var isRejected = false
    }

    static let shared = LoginResponder(library: .shared())

    // Mutex makes the provider and the request table safe to touch from VLC's dialog thread and from actors alike.
    private let provider: Mutex<VLCDialogProvider?>
    private let requests = Mutex<[UUID: Request]>([:])

    init(library: VLCLibrary) {
        provider = Mutex(VLCDialogProvider(library: library, customUI: true))
        super.init()
        provider.withLock { $0?.customRenderer = self }
    }

    func begin(host: String, credential: NetworkCredential?) -> UUID {
        let id = UUID()
        requests.withLock { $0[id] = Request(host: host, credential: credential) }
        return id
    }

    func wasRejected(_ id: UUID) -> Bool {
        requests.withLock { $0[id]?.isRejected ?? false }
    }

    func end(_ id: UUID) {
        requests.withLock { $0[id] = nil }
    }
}

extension LoginResponder: VLCCustomDialogRendererProtocol {
    func showLogin(withTitle title: String, message: String, defaultUsername username: String?, askingForStorage: Bool, withReference reference: NSValue) {
        let credential: NetworkCredential? = requests.withLock { requests in
            // libvlc's prompt names the host it's signing in to; fall back to the only open request if it doesn't.
            let text = "\(title) \(message)"
            let match = requests.first { text.localizedCaseInsensitiveContains($0.value.host) }?.key
                ?? (requests.count == 1 ? requests.first?.key : nil)
            guard let match, var request = requests[match] else { return nil }
            defer { requests[match] = request }
            guard let credential = request.credential, !request.isAnswered else {
                request.isRejected = true
                return nil
            }
            request.isAnswered = true
            return credential
        }
        provider.withLock { provider in
            if let credential {
                provider?.postUsername(credential.user, andPassword: credential.password, forDialogReference: reference, store: false)
            } else {
                provider?.dismissDialog(withReference: reference)
            }
        }
    }

    func showError(withTitle error: String, message: String) {}

    // Questions are things like accepting an unknown certificate; never say yes on the user's behalf.
    func showQuestion(withTitle title: String, message: String, type questionType: VLCDialogQuestionType, cancel cancelString: String?, action1String: String?, action2String: String?, withReference reference: NSValue) {
        provider.withLock { $0?.dismissDialog(withReference: reference) }
    }

    func showProgress(withTitle title: String, message: String, isIndeterminate: Bool, position: Float, cancel cancelString: String?, withReference reference: NSValue) {}

    func updateProgress(withReference reference: NSValue, message: String?, position: Float) {}

    func cancelDialog(withReference reference: NSValue) {}
}
