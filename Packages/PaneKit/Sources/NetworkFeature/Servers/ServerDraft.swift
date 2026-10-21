import Domain
import Foundation

/// What the Add Server form holds, and the server and login it turns into.
struct ServerDraft: Equatable {
    var kind = NetworkServer.Kind.smb
    var host = ""
    var port: Int?
    var name = ""
    var user = ""
    var password = ""

    // People paste "smb://nas.local/Movies"; keep just the host.
    var trimmedHost: String {
        let text = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutScheme = text.range(of: "://").map { String(text[$0.upperBound...]) } ?? text
        return String(withoutScheme.prefix { $0 != "/" })
    }

    /// SFTP has no guest access, so it needs a user name; SMB can try as a guest.
    var canSave: Bool {
        !trimmedHost.isEmpty && !trimmedHost.contains(" ") && (kind != .sftp || !user.isEmpty)
    }

    var credential: NetworkCredential? {
        user.isEmpty ? nil : NetworkCredential(user: user, password: password)
    }

    func makeServer() -> NetworkServer {
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return NetworkServer(
            kind: kind,
            host: trimmedHost,
            port: port,
            displayName: displayName.isEmpty ? trimmedHost : displayName,
            requiresCredentials: credential != nil
        )
    }
}
