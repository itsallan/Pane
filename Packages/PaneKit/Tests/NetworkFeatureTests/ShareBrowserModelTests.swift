import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import NetworkFeature

@MainActor
struct ShareBrowserModelTests {
    private let nas = NetworkServer(kind: .smb, host: "nas.local", displayName: "NAS", requiresCredentials: true)
    private let listing = [
        NetworkEntry(name: "b.mkv", path: "/b.mkv", isDirectory: false),
        NetworkEntry(name: "TV", path: "/TV", isDirectory: true),
        NetworkEntry(name: "a.mp4", path: "/a.mp4", isDirectory: false),
        NetworkEntry(name: "Movies", path: "/Movies", isDirectory: true),
    ]

    private func makeModel(
        credentials: InMemoryCredentialStore,
        servers: InMemoryNetworkServerRepository = InMemoryNetworkServerRepository(),
        listings: [NetworkServer.ID: [String: [NetworkEntry]]]? = nil
    ) -> ShareBrowserModel {
        let browser = FakeNetworkBrowser(listings: listings ?? [nas.id: ["/": listing]], passwords: [nas.id: "secret"], credentials: credentials)
        return ShareBrowserModel(server: nas, path: "/", title: "NAS", browser: browser, servers: servers, credentials: credentials)
    }

    @Test func listsFoldersThenFilesByName() async {
        let model = makeModel(credentials: InMemoryCredentialStore(credentials: [nas.id: NetworkCredential(user: "pane", password: "secret")]))

        await model.load()

        #expect(model.phase == .loaded)
        #expect(model.folders.map(\.name) == ["Movies", "TV"])
        #expect(model.files.map(\.name) == ["a.mp4", "b.mkv"])
    }

    @Test func asksToSignInThenSavesAndRetries() async throws {
        let credentials = InMemoryCredentialStore()
        let servers = InMemoryNetworkServerRepository()
        let model = makeModel(credentials: credentials, servers: servers)

        await model.load()
        #expect(model.phase == .failed(.signInRequired))
        #expect(model.signInRequest?.isRetry == false)

        await model.signIn(NetworkCredential(user: "pane", password: "secret"))

        #expect(model.signInRequest == nil)
        #expect(model.phase == .loaded)
        #expect(try await credentials.credential(for: nas.id)?.user == "pane")
        // The server is saved so a file played from it can be opened again later.
        #expect(try await servers.server(withID: nas.id) != nil)
    }

    @Test func aRejectedPasswordAsksAgainAndSaysWhy() async {
        let model = makeModel(credentials: InMemoryCredentialStore())

        await model.load()
        let firstRequest = model.signInRequest
        await model.signIn(NetworkCredential(user: "pane", password: "wrong"))

        #expect(model.phase == .failed(.signInRequired))
        // Same ID, so the open sheet updates instead of closing and reopening.
        #expect(model.signInRequest?.id == firstRequest?.id)
        #expect(!model.isSigningIn)
        #expect(model.signInRequest?.isRetry == true)
        #expect(model.signInRequest?.user == "pane")
    }

    @Test func anUnreachableServerSaysSo() async {
        let model = makeModel(credentials: InMemoryCredentialStore(credentials: [nas.id: NetworkCredential(user: "pane", password: "secret")]), listings: [:])

        await model.load()

        #expect(model.phase == .failed(.unreachable))
        #expect(model.signInRequest == nil)
    }

    @Test func loadsOnlyOnceUntilRefreshed() async throws {
        let credentials = InMemoryCredentialStore(credentials: [nas.id: NetworkCredential(user: "pane", password: "secret")])
        let model = makeModel(credentials: credentials)

        await model.loadIfNeeded()
        try await credentials.deleteCredential(for: nas.id)
        await model.loadIfNeeded()
        #expect(model.phase == .loaded)

        await model.load()
        #expect(model.phase == .failed(.signInRequired))
    }

    @Test(arguments: [("Sintel.mkv", true), ("clip.MP4", true), ("talk.ogg", true), ("notes.txt", false), ("subs.srt", false)])
    func marksWhatVLCCanPlay(name: String, isPlayable: Bool) {
        #expect(NetworkEntry(name: name, path: "/\(name)", isDirectory: false).isPlayable == isPlayable)
    }
}
