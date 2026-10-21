import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct VolumeBoostTests {
    @Test func boostsUpToTwiceAndHoldsTheSliderWhileDragging() async {
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing))
        let model = PlayerModel(engine: engine, source: .stream(URL(filePath: "/movie.mkv")), clock: ManualClock())
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { model.isPlaying }

        model.beginVolumeAdjustment()
        model.volumeLevel = 2.5
        #expect(model.volume == 2)
        await eventually { engine.calls.last == .setVolume(2) }
        // A state from before the drag mustn't yank the slider back.
        engine.send(PlaybackState(status: .playing, volume: 1))
        await settle()
        #expect(model.volume == 2)
        model.endVolumeAdjustment()
    }
}
