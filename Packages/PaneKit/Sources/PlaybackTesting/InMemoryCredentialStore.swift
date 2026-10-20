import Domain

public actor InMemoryCredentialStore: CredentialStore {
    private var credentials: [NetworkServer.ID: NetworkCredential]

    public init(credentials: [NetworkServer.ID: NetworkCredential] = [:]) {
        self.credentials = credentials
    }

    public func credential(for server: NetworkServer.ID) async throws -> NetworkCredential? {
        credentials[server]
    }

    public func save(_ credential: NetworkCredential, for server: NetworkServer.ID) async throws {
        credentials[server] = credential
    }

    public func deleteCredential(for server: NetworkServer.ID) async throws {
        credentials[server] = nil
    }
}
