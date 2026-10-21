import Domain

public actor InMemoryNetworkServerRepository: NetworkServerRepository {
    private var storage: [NetworkServer.ID: NetworkServer]

    public init(servers: [NetworkServer] = []) {
        storage = Dictionary(servers.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    public func servers() async throws -> [NetworkServer] {
        storage.values.sorted { $0.displayName < $1.displayName }
    }

    public func server(withID id: NetworkServer.ID) async throws -> NetworkServer? {
        storage[id]
    }

    public func save(_ server: NetworkServer) async throws {
        storage[server.id] = server
    }

    public func deleteServer(withID id: NetworkServer.ID) async throws {
        storage[id] = nil
    }
}
