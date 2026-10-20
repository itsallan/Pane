import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct PlayerModelTests {
    private let clock = ManualClock()
    private let source = MediaSource.stream(URL(filePath: "/movie.mkv"))

    private func playing(at position: Duration, duration: Duration = .seconds(600)) -> PlaybackState {
        PlaybackState(status: .playing, progress: PlaybackProgress(position: position, duration: duration), isSeekable: true)
    }

    private func start(
        _ engine: FakePlaybackEngine,
        thumbnails: (any ThumbnailProvider)? = nil
    ) async -> (PlayerModel, Task<Void, Never>) {
        let model = PlayerModel(engine: engine, source: source, thumbnails: thumbnails, clock: clock)
        let task = Task { await model.run() }
        await eventually { engine.calls.contains(.load(source)) && model.status == engine.state.status }
        return (model, task)
    }

    @Test func mirrorsEngineState() async {
        let chapters = [Chapter(id: 0, start: .zero), Chapter(id: 1, start: .seconds(300))]
        var state = playing(at: .seconds(42))
        state.chapters = chapters
        let engine = FakePlaybackEngine(stateOnLoad: state)
        let (model, task) = await start(engine)
        defer { task.cancel() }

        #expect(model.isPlaying)
        #expect(model.position == .seconds(42))
        #expect(model.duration == .seconds(600))
        #expect(model.chapters == chapters)
        #expect(model.canScrub)
    }

    @Test func surfacesLoadFailure() async {
        let engine = FakePlaybackEngine(failures: .init(load: .unresolvableBookmark))
        let model = PlayerModel(engine: engine, source: source, clock: clock)
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { model.failure != nil }
        #expect(model.failure == .unresolvableBookmark)
    }

    @Test func ignoresStaleTimeAfterSkipping() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .seconds(100)), landsSeeks: false)
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.skip(by: .seconds(10))
        #expect(model.position == .seconds(110))
        await eventually { engine.calls.contains(.seek(to: .seconds(110), precision: .exact)) }

        engine.send(playing(at: .seconds(100.25)))
        await settle()
        #expect(model.position == .seconds(110))

        engine.send(playing(at: .seconds(110.5)))
        await eventually { model.position == .seconds(110.5) }

        engine.send(playing(at: .seconds(111)))
        await eventually { model.position == .seconds(111) }
    }

    @Test func acceptsEngineTimeOnceTheSeekTimesOut() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .seconds(100)), landsSeeks: false)
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.skip(by: .seconds(30))
        engine.send(playing(at: .seconds(101)))
        await settle()
        #expect(model.position == .seconds(130))

        clock.advance(by: PlayerModel.seekTimeout)
        engine.send(playing(at: .seconds(124)))
        await eventually { model.position == .seconds(124) }
    }

    @Test func holdsTheScrubPositionAndSeeksOnRelease() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .seconds(100)), landsSeeks: false)
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.beginScrub()
        model.scrub(toFraction: 0.5)
        engine.send(playing(at: .seconds(101)))
        await settle()
        #expect(model.position == .seconds(300))

        model.endScrub()
        await eventually { engine.calls.contains(.seek(to: .seconds(300), precision: .exact)) }
        engine.send(playing(at: .seconds(101.25)))
        await settle()
        #expect(model.position == .seconds(300))
        #expect(!model.isScrubbing)
    }

    @Test func scrubbingIsIgnoredWhenNotSeekable() async {
        var state = playing(at: .seconds(10))
        state.isSeekable = false
        let engine = FakePlaybackEngine(stateOnLoad: state)
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.beginScrub()
        model.scrub(toFraction: 0.5)
        model.skip(by: .seconds(10))
        #expect(!model.isScrubbing)
        #expect(model.position == .seconds(10))
    }

    @Test func showsOnlyTheLatestThumbnailWhileScrubbing() async {
        let thumbnails = GatedThumbnailProvider()
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .zero, duration: .seconds(100)))
        let (model, task) = await start(engine, thumbnails: thumbnails)
        defer { task.cancel() }

        model.beginScrub()
        model.scrub(toFraction: 0.1)
        model.scrub(toFraction: 0.2)
        await eventually { await Set(thumbnails.requested).isSuperset(of: [.seconds(10), .seconds(20)]) }

        await thumbnails.release(.seconds(10))
        await settle()
        #expect(model.scrubThumbnail == nil)

        await thumbnails.release(.seconds(20))
        await eventually { model.scrubThumbnail == GatedThumbnailProvider.url(for: .seconds(20)) }

        model.endScrub()
        #expect(model.scrubThumbnail == nil)
    }

    @Test func hidesControlsAfterThreeSecondsOfPlayback() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .zero))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        #expect(model.areControlsVisible)
        // Advancing inside the loop covers the gap before the hide task starts sleeping.
        await eventually {
            clock.advance(by: PlayerModel.autoHideDelay)
            return !model.areControlsVisible
        }
        #expect(!model.areControlsVisible)
    }

    @Test func keepsControlsWhileScrubbingOrInAMenu() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .zero))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.beginScrub()
        await advancePastAutoHide()
        #expect(model.areControlsVisible)
        model.endScrub()

        model.isMenuPresented = true
        await advancePastAutoHide()
        #expect(model.areControlsVisible)

        model.isMenuPresented = false
        await eventually {
            clock.advance(by: PlayerModel.autoHideDelay)
            return !model.areControlsVisible
        }
        #expect(!model.areControlsVisible)
    }

    @Test func keepsControlsWhilePaused() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .zero))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        await engine.pause()
        await eventually { model.status == .paused }
        await advancePastAutoHide()
        #expect(model.areControlsVisible)
    }

    @Test func speedBoostRestoresThePreviousRate() async {
        var state = playing(at: .zero)
        state.rate = 1.5
        let engine = FakePlaybackEngine(stateOnLoad: state)
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.beginSpeedBoost()
        #expect(model.rate == 2)
        await eventually { engine.state.rate == 2 }

        model.endSpeedBoost()
        #expect(model.rate == 1.5)
        await eventually { engine.state.rate == 1.5 }
        #expect(!model.isSpeedBoosted)
    }

    @Test func pinchTogglesBetweenFitAndFill() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .zero))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.toggleVideoScaling()
        await eventually { engine.state.videoScaling == .fill }
        model.toggleVideoScaling()
        await eventually { engine.state.videoScaling == .fit }
        #expect(engine.calls.filter { if case .setVideoScaling = $0 { true } else { false } }.count == 2)
    }

    @Test func clampsVolumeToTheBoostRange() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .zero))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.beginVolumeAdjustment()
        model.setVolume(3)
        #expect(model.volume == 2)
        model.setVolume(-1)
        #expect(model.volume == 0)
        model.endVolumeAdjustment()
        await eventually { engine.state.volume == 0 }
    }

    @Test func brightnessGoesThroughTheInjectedScreen() {
        let screen = TestScreenBrightness(level: 0.5)
        let model = PlayerModel(engine: FakePlaybackEngine(), source: source, screenBrightness: screen, clock: clock)

        #expect(model.brightness == 0.5)
        model.setBrightness(1.4)
        #expect(screen.level == 1)
        #expect(model.brightness == 1)
    }

    private func advancePastAutoHide() async {
        for _ in 0..<10 {
            clock.advance(by: PlayerModel.autoHideDelay)
            await Task.yield()
        }
    }
}

@MainActor
private func eventually(_ condition: () async -> Bool) async {
    for _ in 0..<400 {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

/// Gives queued engine calls and state deliveries a chance to land before asserting that nothing changed.
@MainActor
private func settle() async {
    try? await Task.sleep(for: .milliseconds(50))
}

private actor GatedThumbnailProvider: ThumbnailProvider {
    private(set) var requested: [Duration] = []
    private var gates: [Duration: CheckedContinuation<Void, Never>] = [:]

    static func url(for position: Duration) -> URL {
        URL(filePath: "/thumbnails/\(position.components.seconds).jpg")
    }

    func thumbnail(for source: MediaSource, at position: Duration, maxPixelSize: Int) async throws(PlaybackError) -> URL {
        requested.append(position)
        await withCheckedContinuation { gates[position] = $0 }
        return Self.url(for: position)
    }

    func release(_ position: Duration) {
        gates.removeValue(forKey: position)?.resume()
    }
}

@MainActor
private final class TestScreenBrightness: ScreenBrightness {
    var level: Double

    init(level: Double) {
        self.level = level
    }
}
