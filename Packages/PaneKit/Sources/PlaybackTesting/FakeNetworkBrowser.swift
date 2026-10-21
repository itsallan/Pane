import Domain

/// Throws `.authenticationRequired` for a server that requires credentials until one is saved in `credentials`,
/// which is the flow a feature goes through when it prompts the user. A server listed in `passwords` also rejects
/// a saved credential whose password doesn't match, the way a share answers a mistyped password.
public struct FakeNetworkBrowser: NetworkBrowser {
    private let discovered: [NetworkServer]
    private let listings: [NetworkServer.ID: [String: [NetworkEntry]]]
    private let passwords: [NetworkServer.ID: String]
    private let credentials: any CredentialStore

    public init(
        servers: [NetworkServer] = [],
        listings: [NetworkServer.ID: [String: [NetworkEntry]]] = [:],
        passwords: [NetworkServer.ID: String] = [:],
        credentials: any CredentialStore = InMemoryCredentialStore()
    ) {
        discovered = servers
        self.listings = listings
        self.passwords = passwords
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
            guard let credential else { throw .authenticationRequired(server: server.id) }
            if let password = passwords[server.id], credential.password != password {
                throw .authenticationRequired(server: server.id)
            }
        }
        guard let paths = listings[server.id] else { throw .serverUnreachable(server.id) }
        return paths[path] ?? []
    }
}
