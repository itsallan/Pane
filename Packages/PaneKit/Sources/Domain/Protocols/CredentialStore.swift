public protocol CredentialStore: Sendable {
    func credential(for server: NetworkServer.ID) async throws -> NetworkCredential?
    func save(_ credential: NetworkCredential, for server: NetworkServer.ID) async throws
    func deleteCredential(for server: NetworkServer.ID) async throws
}
