import Domain
import Foundation
import SwiftData

@ModelActor
public actor SwiftDataNetworkServerRepository: NetworkServerRepository {
    public func servers() async throws -> [NetworkServer] {
        let descriptor = FetchDescriptor<NetworkServerRecord>(sortBy: [SortDescriptor(\.displayName)])
        return try modelContext.fetch(descriptor).map(\.networkServer)
    }

    public func server(withID id: NetworkServer.ID) async throws -> NetworkServer? {
        try record(withID: id)?.networkServer
    }

    public func save(_ server: NetworkServer) async throws {
        if let existing = try record(withID: server.id) {
            existing.update(from: server)
        } else {
            modelContext.insert(NetworkServerRecord(server))
        }
        try modelContext.save()
    }

    public func deleteServer(withID id: NetworkServer.ID) async throws {
        try modelContext.delete(model: NetworkServerRecord.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }

    private func record(withID id: UUID) throws -> NetworkServerRecord? {
        try modelContext.fetch(FetchDescriptor<NetworkServerRecord>(predicate: #Predicate { $0.id == id })).first
    }
}
