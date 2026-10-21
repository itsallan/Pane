import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import Playback

struct StateBroadcastTests {
    @Test func newSubscriberGetsCurrentState() async {
        let broadcast = StateBroadcast()
        broadcast.send(PlaybackState(status: .playing))
        var iterator = broadcast.subscribe().makeAsyncIterator()
        #expect(await iterator.next()?.status == .playing)
    }

    @Test func finishEndsEverySubscriber() async {
        let broadcast = StateBroadcast()
        let stream = broadcast.subscribe()
        broadcast.finish()
        var received: [PlaybackState] = []
        for await state in stream {
            received.append(state)
        }
        #expect(received == [PlaybackState()])
    }

    @Test func identicalStatesAreNotRepeated() async {
        let broadcast = StateBroadcast()
        let stream = broadcast.subscribe()
        broadcast.send(PlaybackState())
        broadcast.send(PlaybackState(status: .paused))
        broadcast.finish()
        var statuses: [PlaybackState.Status] = []
        for await state in stream {
            statuses.append(state.status)
        }
        // Buffering is newest(1), so only the last distinct state is guaranteed.
        #expect(statuses.last == .paused)
        #expect(!statuses.contains(.playing))
    }
}

struct MediaLocationTests {
    @Test func networkSharesNeedTheirResolvedAddress() throws {
        let server = NetworkServer(kind: .smb, host: "nas.local", displayName: "NAS", requiresCredentials: false)
        let source = MediaSource.networkShare(server: server.id, path: "/movie.mkv")
        #expect(throws: PlaybackError.unknownServer(server.id)) {
            try MediaLocation(source)
        }

        let location = try MediaLocation(source, share: ShareAddress(server: server, path: "/movie.mkv", credential: nil))
        #expect(location.url.absoluteString == "smb://nas.local/movie.mkv")
        #expect(location.isRemote)
    }

    @Test func garbageBookmarkIsUnresolvable() {
        #expect(throws: PlaybackError.unresolvableBookmark) {
            try MediaLocation(.file(bookmark: Data([0, 1, 2, 3])))
        }
    }

    @Test func remoteOptionsAddNetworkCaching() {
        #expect(MediaOptions.options(isRemote: true)["network-caching"] != nil)
        #expect(MediaOptions.options(isRemote: false)["network-caching"] == nil)
        #expect(MediaOptions.options(isRemote: false)["codec"]?.hasPrefix("videotoolbox") == true)
    }
}

struct DurationConversionTests {
    @Test func convertsToLibVLCUnits() {
        let duration = Duration.seconds(2) + .milliseconds(345)
        #expect(duration.milliseconds == 2_345)
        #expect(duration.microseconds == 2_345_000)
    }
}

struct VLCPlaybackEngineTests {
    @Test func startsIdleAndCloses() async {
        let engine = VLCPlaybackEngine(drawable: nil)
        var iterator = engine.states().makeAsyncIterator()
        #expect(await iterator.next()?.status == .idle)
        await engine.close()
        #expect(await iterator.next() == nil)
    }

    @Test func loadRejectsUnresolvableSources() async {
        let engine = VLCPlaybackEngine(drawable: nil)
        await #expect(throws: PlaybackError.unresolvableBookmark) {
            try await engine.load(.file(bookmark: Data()))
        }
        await engine.close()
    }

    @Test func captureWithoutVideoFails() async {
        let engine = VLCPlaybackEngine(drawable: nil)
        await #expect(throws: PlaybackError.captureFailed) {
            try await engine.captureFrame()
        }
        await engine.close()
    }

    @Test func unknownTrackThrows() async {
        let engine = VLCPlaybackEngine(drawable: nil)
        await #expect(throws: PlaybackError.unknownTrack("nope")) {
            try await engine.selectTrack("nope")
        }
        await engine.close()
    }
}

struct VLCThumbnailProviderTests {
    @Test func failuresSurfaceAsPlaybackErrors() async {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let provider = VLCThumbnailProvider(directory: directory)
        await #expect(throws: PlaybackError.unresolvableBookmark) {
            try await provider.thumbnail(for: .file(bookmark: Data()), at: .seconds(12), maxPixelSize: 160)
        }
    }

    @Test func sharesWithoutAKnownServerFailCleanly() async {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let server = NetworkServer(kind: .smb, host: "nas.local", displayName: "NAS", requiresCredentials: false)
        let source = MediaSource.networkShare(server: server.id, path: "/movie.mkv")

        let unwired = VLCThumbnailProvider(directory: directory)
        await #expect(throws: PlaybackError.unknownServer(server.id)) {
            try await unwired.thumbnail(for: source, at: .seconds(12), maxPixelSize: 160)
        }

        let forgotten = VLCThumbnailProvider(directory: directory, servers: InMemoryNetworkServerRepository())
        await #expect(throws: PlaybackError.unknownServer(server.id)) {
            try await forgotten.thumbnail(for: source, at: .seconds(12), maxPixelSize: 160)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
    }
}
