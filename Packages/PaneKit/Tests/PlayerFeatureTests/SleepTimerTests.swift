import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct SleepTimerTests {
    private let clock = ManualClock()

    private func start() async -> (PlayerModel, FakePlaybackEngine, Task<Void, Never>) {
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing, progress: PlaybackProgress(position: .zero, duration: .seconds(600))))
        let model = PlayerModel(engine: engine, source: .stream(URL(filePath: "/movie.mkv")), clock: clock)
        let task = Task { await model.run() }
        await eventually { model.isPlaying }
        return (model, engine, task)
    }

    @Test func pausesWhenTheMinutesRunOut() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }

        model.sleepTimer.setting = .minutes(15)
        #expect(model.sleepTimer.fireDate != nil)
        await settle()

        clock.advance(by: .seconds(14 * 60))
        await settle()
        #expect(!engine.calls.contains(.pause))

        clock.advance(by: .seconds(60))
        await eventually { engine.calls.contains(.pause) }
        #expect(model.sleepTimer.hasFired)
        #expect(model.sleepTimer.setting == nil)
        #expect(model.sleepTimer.fireDate == nil)
    }

    @Test func turningItOffCancels() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }

        model.sleepTimer.setting = .minutes(15)
        await settle()
        model.sleepTimer.setting = nil
        clock.advance(by: .seconds(15 * 60))
        await settle()

        #expect(!engine.calls.contains(.pause))
        #expect(!model.sleepTimer.hasFired)
    }

    @Test func endOfItemFiresWhenTheVideoEnds() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }

        model.sleepTimer.setting = .endOfItem
        #expect(model.sleepTimer.fireDate == nil)
        engine.send(PlaybackState(status: .ended, progress: PlaybackProgress(position: .seconds(600), duration: .seconds(600))))

        await eventually { model.sleepTimer.hasFired }
        #expect(model.sleepTimer.setting == nil)
    }
}
