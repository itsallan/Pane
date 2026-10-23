import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct BackgroundPlaybackTests {
    private let source = MediaSource.stream(URL(filePath: "/movie.mkv"))

    private func playing(_ kinds: [MediaTrack.Kind]) -> PlaybackState {
        PlaybackState(
            status: .playing,
            progress: PlaybackProgress(position: .seconds(60), duration: .seconds(600)),
            tracks: kinds.enumerated().map { MediaTrack(id: "\($0.offset)", kind: $0.element) },
            isSeekable: true
        )
    }

    private func start(_ engine: FakePlaybackEngine) async -> (PlayerModel, Task<Void, Never>) {
        let model = PlayerModel(engine: engine, source: source, clock: ManualClock())
        let task = Task { await model.run() }
        await eventually { model.isPlaying }
        return (model, task)
    }

    @Test func pausesVideoInTheBackground() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing([.video, .audio]))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.sceneDidEnterBackground(pausesVideo: true)
        await eventually { engine.calls.contains(.pause) }
        #expect(engine.calls.contains(.pause))
    }

    @Test func keepsAudioPlayingInTheBackground() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing([.audio]))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.sceneDidEnterBackground(pausesVideo: true)
        await settle()
        #expect(!engine.calls.contains(.pause))
    }

    @Test func keepsVideoPlayingWhereTheWindowStaysVisible() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing([.video, .audio]))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.sceneDidEnterBackground()
        await settle()
        #expect(!engine.calls.contains(.pause))
    }

    @Test func playOnlyStartsWhatIsntPlaying() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing([.video]))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.play()
        await settle()
        #expect(!engine.calls.contains(.play))

        engine.update { $0.status = .paused }
        await eventually { model.status == .paused }
        model.play()
        await eventually { engine.calls.contains(.play) }
        #expect(engine.calls.contains(.play))
    }
}
