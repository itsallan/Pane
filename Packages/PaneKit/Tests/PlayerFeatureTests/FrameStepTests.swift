import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct FrameStepTests {
    @Test func stepsOnlyWhilePaused() async {
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing, progress: PlaybackProgress(position: .seconds(5), duration: .seconds(60)), isSeekable: true))
        let model = PlayerModel(engine: engine, source: .stream(URL(filePath: "/movie.mkv")), clock: ManualClock())
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { model.isPlaying }

        #expect(!model.canStepFrame)
        model.stepFrame()
        await settle()
        #expect(!engine.calls.contains(.stepFrame))

        model.togglePlayback()
        await eventually { model.status == .paused }
        #expect(model.canStepFrame)
        model.stepFrame()
        await eventually { engine.calls.last == .stepFrame }
        await eventually { model.position == .milliseconds(5040) }
    }
}
