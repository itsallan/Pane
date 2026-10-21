import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class ShareBrowserModel {
    public enum Phase: Equatable, Sendable {
        case loading
        case loaded
        case failed(BrowseFailure)
    }

    public private(set) var server: NetworkServer
    public let path: String
    public let title: String
    public private(set) var phase = Phase.loading
    public private(set) var folders: [NetworkEntry] = []
    public private(set) var files: [NetworkEntry] = []
    public var signInRequest: SignInRequest?

    private let browser: any NetworkBrowser
    private let servers: any NetworkServerRepository
    private let credentials: any CredentialStore
    private var hasLoaded = false

    public init(
        server: NetworkServer,
        path: String,
        title: String,
        browser: any NetworkBrowser,
        servers: any NetworkServerRepository,
        credentials: any CredentialStore
    ) {
        self.server = server
        self.path = path
        self.title = title
        self.browser = browser
        self.servers = servers
        self.credentials = credentials
    }

    public var isEmpty: Bool { folders.isEmpty && files.isEmpty }

    /// Coming back from a subfolder shouldn't flash a spinner and re-list the share; pull to refresh does that.
    public func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    public func load() async {
        hasLoaded = true
        phase = .loading
        do throws(PlaybackError) {
            let entries = try await browser.contents(of: server, path: path)
            let sorted = entries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            folders = sorted.filter(\.isDirectory)
            files = sorted.filter { !$0.isDirectory }
            phase = .loaded
        } catch .authenticationRequired {
            phase = .failed(.signInRequired)
            await requestSignIn()
        } catch .serverUnreachable, .unknownServer {
            phase = .failed(.unreachable)
        } catch {
            phase = .failed(.failed)
        }
    }

    public func requestSignIn() async {
        let saved = try? await credentials.credential(for: server.id)
        // A saved login that still fails was rejected, which is worth saying instead of asking as if for the first time.
        signInRequest = SignInRequest(serverName: server.displayName, user: saved?.user ?? "", isRetry: saved != nil)
    }

    public func signIn(_ credential: NetworkCredential) async {
        signInRequest = nil
        server.requiresCredentials = true
        do {
            try await credentials.save(credential, for: server.id)
            // Saving the server is what lets a file from it play later: the library refers to it by ID.
            try await servers.save(server)
        } catch {
            phase = .failed(.failed)
            return
        }
        await load()
    }
}
