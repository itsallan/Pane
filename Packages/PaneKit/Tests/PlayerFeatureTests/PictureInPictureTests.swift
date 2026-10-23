import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct PictureInPictureTests {
    private let source = MediaSource.stream(URL(filePath: "/movie.mkv"))

    private func playing(supported: Bool, kinds: [MediaTrack.Kind] = [.video, .audio]) -> PlaybackState {
        PlaybackState(
            status: .playing,
            progress: PlaybackProgress(position: .seconds(60), duration: .seconds(600)),
            tracks: kinds.enumerated().map { MediaTrack(id: "\($0.offset)", kind: $0.element) },
            isSeekable: true,
            isPictureInPictureSupported: supported
        )
    }

    private func start(_ engine: FakePlaybackEngine) async -> (PlayerModel, Task<Void, Never>) {
        let model = PlayerModel(engine: engine, source: source, clock: ManualClock())
        let task = Task { await model.run() }
        await eventually { model.isPlaying }
        return (model, task)
    }

    @Test func togglesWhenSupported() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(supported: true))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        #expect(model.canUsePictureInPicture)
        model.togglePictureInPicture()
        await eventually { model.isPictureInPictureActive }
        #expect(model.isPictureInPictureActive)

        model.togglePictureInPicture()
        await eventually { !model.isPictureInPictureActive }
        #expect(engine.calls.filter { if case .setPictureInPicture = $0 { true } else { false } } == [
            .setPictureInPicture(true), .setPictureInPicture(false),
        ])
    }

    @Test func isUnavailableWithoutSupportOrVideo() async {
        let unsupported = FakePlaybackEngine(stateOnLoad: playing(supported: false))
        let (model, task) = await start(unsupported)
        defer { task.cancel() }
        #expect(!model.canUsePictureInPicture)
        model.togglePictureInPicture()
        await settle()
        #expect(!unsupported.calls.contains(.setPictureInPicture(true)))

        let audioOnly = FakePlaybackEngine(stateOnLoad: playing(supported: true, kinds: [.audio]))
        let (audioModel, audioTask) = await start(audioOnly)
        defer { audioTask.cancel() }
        #expect(!audioModel.canUsePictureInPicture)
    }

    @Test func keepsPlayingInTheBackgroundWhileActive() async {
        var state = playing(supported: true)
        state.isPictureInPictureActive = true
        let engine = FakePlaybackEngine(stateOnLoad: state)
        let (model, task) = await start(engine)
        defer { task.cancel() }

        model.sceneDidEnterBackground(pausesVideo: true)
        await settle()
        #expect(!engine.calls.contains(.pause))
    }
}
