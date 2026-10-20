import Domain

/// Throws `.authenticationRequired` for a server that requires credentials until one is saved in `credentials`,
/// which is the flow a feature goes through when it prompts the user.
public struct FakeNetworkBrowser: NetworkBrowser {
    private let discovered: [NetworkServer]
    private let listings: [NetworkServer.ID: [String: [NetworkEntry]]]
    private let credentials: any CredentialStore

    public init(
        servers: [NetworkServer] = [],
        listings: [NetworkServer.ID: [String: [NetworkEntry]]] = [:],
        credentials: any CredentialStore = InMemoryCredentialStore()
    ) {
        discovered = servers
        self.listings = listings
        self.credentials = credentials
    }

    public func servers() -> AsyncStream<[NetworkServer]> {
        AsyncStream { continuation in
            continuation.yield(discovered)
            continuation.finish()
        }
    }

    public func contents(of server: NetworkServer, path: String) async throws(PlaybackError) -> [NetworkEntry] {
        if server.requiresCredentials {
            let credential = try? await credentials.credential(for: server.id)
            guard credential != nil else { throw .authenticationRequired(server: server.id) }
        }
        guard let paths = listings[server.id] else { throw .serverUnreachable(server.id) }
        return paths[path] ?? []
    }
}
