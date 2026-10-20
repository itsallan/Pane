import Domain
import Foundation
import PlaybackTesting
import Testing

struct FakePlaybackEngineTests {
    @Test func newSubscriberGetsCurrentStateThenChanges() async {
        let engine = FakePlaybackEngine(state: PlaybackState(status: .paused))
        var states = engine.states().makeAsyncIterator()
        #expect(await states.next()?.status == .paused)
        await engine.play()
        #expect(await states.next()?.status == .playing)
    }

    @Test func fansOutToEverySubscriber() async {
        let engine = FakePlaybackEngine()
        var first = engine.states().makeAsyncIterator()
        var second = engine.states().makeAsyncIterator()
        _ = await (first.next(), second.next())
        engine.send(PlaybackState(status: .buffering(0.5)))
        #expect(await first.next()?.status == .buffering(0.5))
        #expect(await second.next()?.status == .buffering(0.5))
    }

    @Test func selectingAnUnknownTrackThrows() async {
        let engine = FakePlaybackEngine()
        await #expect(throws: PlaybackError.unknownTrack("missing")) {
            try await engine.selectTrack("missing")
        }
    }

    @Test func selectingReplacesTheTrackOfTheSameKind() async throws {
        let tracks = [
            MediaTrack(id: "a1", kind: .audio), MediaTrack(id: "a2", kind: .audio), MediaTrack(id: "s1", kind: .subtitle),
        ]
        let engine = FakePlaybackEngine(state: PlaybackState(tracks: tracks, selectedTrackIDs: ["a1", "s1"]))
        try await engine.selectTrack("a2")
        #expect(engine.state.selectedTrackIDs == ["a2", "s1"])
    }

    @Test func seeksClampToDuration() async {
        let engine = FakePlaybackEngine(state: PlaybackState(progress: PlaybackProgress(position: .seconds(10), duration: .seconds(60))))
        await engine.seek(by: .seconds(-30))
        #expect(engine.state.progress.position == .zero)
        await engine.seek(to: .seconds(90), precision: .fast)
        #expect(engine.state.progress.position == .seconds(60))
    }
}

struct ManualClockTests {
    @Test func sleepersWakeOnlyAfterTheirDeadline() async throws {
        let clock = ManualClock()
        let woke = InMemoryProgressRepository()
        let sleeper = Task {
            try await clock.sleep(until: ManualClock.Instant(offset: .seconds(10)))
            try await woke.markWatched(UUID())
        }
        clock.advance(by: .seconds(4))
        await Task.yield()
        #expect(await woke.writes.isEmpty)
        clock.advance(by: .seconds(6))
        try await sleeper.value
        #expect(await woke.writes.count == 1)
    }

    @Test func cancellingASleeperThrows() async {
        let clock = ManualClock()
        let sleeper = Task { try await clock.sleep(for: .seconds(10)) }
        sleeper.cancel()
        await #expect(throws: CancellationError.self) { try await sleeper.value }
    }
}

struct FakeNetworkBrowserTests {
    @Test func asksForCredentialsUntilOneIsSaved() async throws {
        let server = NetworkServer(kind: .smb, host: "nas.local", displayName: "NAS", requiresCredentials: true)
        let movies = [NetworkEntry(name: "Movies", path: "/Movies", isDirectory: true)]
        let credentials = InMemoryCredentialStore()
        let browser = FakeNetworkBrowser(servers: [server], listings: [server.id: ["/": movies]], credentials: credentials)

        await #expect(throws: PlaybackError.authenticationRequired(server: server.id)) {
            try await browser.contents(of: server, path: "/")
        }
        try await credentials.save(NetworkCredential(user: "pane", password: "secret"), for: server.id)
        #expect(try await browser.contents(of: server, path: "/") == movies)
    }

    @Test func credentialsNeverPrintTheirPassword() {
        let credential = NetworkCredential(user: "pane", password: "hunter2")
        #expect(!"\(credential)".contains("hunter2"))
        #expect(!String(reflecting: credential).contains("hunter2"))
    }
}
