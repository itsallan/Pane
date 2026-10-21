/// Servers the user added by hand or played from. Never holds secrets; those live in a `CredentialStore`.
public protocol NetworkServerRepository: Sendable {
    func servers() async throws -> [NetworkServer]
    func server(withID id: NetworkServer.ID) async throws -> NetworkServer?
    func save(_ server: NetworkServer) async throws
    func deleteServer(withID id: NetworkServer.ID) async throws
}
