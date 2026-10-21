import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct PlaybackSpeedTests {
    @Test(arguments: [(0.25, 0.5), (1.35, 1.35), (3.0, 3.0), (4.0, 3.0)])
    func keepsTheRateInRange(requested: Double, applied: Double) async {
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing))
        let model = PlayerModel(engine: engine, source: .stream(URL(filePath: "/movie.mkv")), clock: ManualClock())
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { model.isPlaying }

        model.speed = requested

        #expect(model.speed == applied)
        await eventually { engine.calls.last == .setRate(applied) }
    }
}
