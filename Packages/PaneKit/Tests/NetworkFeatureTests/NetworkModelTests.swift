import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import NetworkFeature

@MainActor
struct NetworkModelTests {
    private let nas = NetworkServer(kind: .smb, host: "nas.local", displayName: "NAS", requiresCredentials: false)
    private let dlna = NetworkServer(kind: .upnp, host: "192.168.1.5", displayName: "MiniDLNA", requiresCredentials: false)

    @Test func nearbyLeavesOutSavedServers() async {
        let model = NetworkModel(
            browser: FakeNetworkBrowser(servers: [nas, dlna]),
            servers: InMemoryNetworkServerRepository(servers: [nas]),
            credentials: InMemoryCredentialStore()
        )

        await model.load()
        await model.discover()

        #expect(model.savedServers == [nas])
        #expect(model.nearbyServers == [dlna])
    }

    @Test func addingKeepsThePasswordOutOfTheServerRecord() async throws {
        let credentials = InMemoryCredentialStore()
        let servers = InMemoryNetworkServerRepository()
        let model = NetworkModel(browser: FakeNetworkBrowser(), servers: servers, credentials: credentials)
        let seedbox = NetworkServer(kind: .sftp, host: "seedbox.example.com", displayName: "Seedbox", requiresCredentials: true)

        await model.add(seedbox, credential: NetworkCredential(user: "me", password: "secret"))

        #expect(model.savedServers == [seedbox])
        #expect(try await credentials.credential(for: seedbox.id)?.password == "secret")
    }

    @Test func removingForgetsThePasswordToo() async throws {
        let credentials = InMemoryCredentialStore(credentials: [nas.id: NetworkCredential(user: "pane", password: "secret")])
        let model = NetworkModel(browser: FakeNetworkBrowser(servers: [nas]), servers: InMemoryNetworkServerRepository(servers: [nas]), credentials: credentials)
        await model.discover()

        await model.remove(nas)

        #expect(model.savedServers.isEmpty)
        #expect(model.nearbyServers == [nas])
        #expect(try await credentials.credential(for: nas.id) == nil)
    }
}
