import Domain
import Foundation
import Security
import SwiftData
import Testing
@testable import Data

struct NetworkServerRepositoryTests {
    @Test func savesUpdatesAndDeletesServers() async throws {
        let repository = SwiftDataNetworkServerRepository(modelContainer: try .library(inMemory: true))
        var server = NetworkServer(kind: .sftp, host: "seedbox.example.com", port: 2222, displayName: "Seedbox", requiresCredentials: true)

        try await repository.save(server)
        server.displayName = "Box"
        try await repository.save(server)

        #expect(try await repository.servers() == [server])
        #expect(try await repository.server(withID: server.id) == server)
        try await repository.deleteServer(withID: server.id)
        #expect(try await repository.servers().isEmpty)
    }
}

struct StreamHistoryRepositoryTests {
    private let base = Date(timeIntervalSince1970: 1_000_000)

    @Test func reopeningMovesAStreamToTheTop() async throws {
        let repository = SwiftDataStreamHistoryRepository(modelContainer: try .library(inMemory: true))
        let first = URL(string: "https://example.com/a.m3u8")!
        let second = URL(string: "rtsp://camera.local/stream")!

        try await repository.record(first, at: base)
        try await repository.record(second, at: base.addingTimeInterval(10))
        try await repository.record(first, at: base.addingTimeInterval(20))

        #expect(try await repository.recentStreams().map(\.url) == [first, second])
    }

    @Test func keepsOnlyTheMostRecentThirty() async throws {
        let repository = SwiftDataStreamHistoryRepository(modelContainer: try .library(inMemory: true))
        for index in 0..<35 {
            try await repository.record(URL(string: "https://example.com/\(index).m3u8")!, at: base.addingTimeInterval(Double(index)))
        }

        let streams = try await repository.recentStreams()
        #expect(streams.count == 30)
        #expect(streams.first?.url.lastPathComponent == "34.m3u8")
    }

    @Test func deletesOneOrAll() async throws {
        let repository = SwiftDataStreamHistoryRepository(modelContainer: try .library(inMemory: true))
        let first = URL(string: "https://example.com/a.m3u8")!
        let second = URL(string: "https://example.com/b.m3u8")!
        try await repository.record(first, at: base)
        try await repository.record(second, at: base)

        try await repository.deleteStream(first)
        #expect(try await repository.recentStreams().map(\.url) == [second])
        try await repository.deleteAllStreams()
        #expect(try await repository.recentStreams().isEmpty)
    }
}

// The data protection keychain needs a signed host with an application identifier; an unsigned macOS test runner gets
// errSecMissingEntitlement, so these run on the simulator.
@Suite(.enabled(if: KeychainProbe.isAvailable, "This test runner has no keychain entitlement"))
struct KeychainCredentialStoreTests {
    private let store = KeychainCredentialStore(label: "Pane tests \(UUID().uuidString)")

    @Test func roundTripsAndDeletes() async throws {
        let server = UUID()

        try await store.save(NetworkCredential(user: "pane", password: "first"), for: server)
        try await store.save(NetworkCredential(user: "pane", password: "second"), for: server)
        #expect(try await store.credential(for: server) == NetworkCredential(user: "pane", password: "second"))

        try await store.deleteCredential(for: server)
        #expect(try await store.credential(for: server) == nil)
    }

    @Test func keepsServersApart() async throws {
        let nas = UUID()
        let seedbox = UUID()

        try await store.save(NetworkCredential(user: "a", password: "1"), for: nas)
        try await store.save(NetworkCredential(user: "b", password: "2"), for: seedbox)
        #expect(try await store.credential(for: nas)?.user == "a")
        #expect(try await store.credential(for: seedbox)?.user == "b")

        try await store.deleteCredential(for: nas)
        try await store.deleteCredential(for: seedbox)
    }
}

private enum KeychainProbe {
    static var isAvailable: Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: "probe-\(UUID().uuidString)",
            kSecUseDataProtectionKeychain: true,
            kSecValueData: Data(),
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
