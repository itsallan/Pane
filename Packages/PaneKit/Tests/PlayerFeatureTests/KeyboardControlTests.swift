import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct KeyboardControlTests {
    private let clock = ManualClock()
    private let source = MediaSource.stream(URL(filePath: "/movie.mkv"))

    private func start(at position: Duration = .seconds(300), rate: Double = 1) async -> (PlayerModel, FakePlaybackEngine, Task<Void, Never>) {
        let state = PlaybackState(
            status: .playing,
            progress: PlaybackProgress(position: position, duration: .seconds(600)),
            rate: rate,
            isSeekable: true
        )
        let engine = FakePlaybackEngine(stateOnLoad: state)
        let model = PlayerModel(engine: engine, source: source, clock: clock)
        let task = Task { await model.run() }
        await eventually { model.isPlaying && model.rate == rate }
        return (model, engine, task)
    }

    @Test(arguments: [(1.0, 1.25), (1.1, 1.25), (2.9, 3.0), (3.0, 3.0)])
    func speedUpLandsOnTheNextQuarter(from rate: Double, to expected: Double) async {
        let (model, _, task) = await start(rate: rate)
        defer { task.cancel() }

        model.speedUp()

        #expect(model.rate == expected)
    }

    @Test(arguments: [(1.0, 0.75), (1.1, 1.0), (0.5, 0.5)])
    func slowDownLandsOnThePreviousQuarter(from rate: Double, to expected: Double) async {
        let (model, _, task) = await start(rate: rate)
        defer { task.cancel() }

        model.slowDown()

        #expect(model.rate == expected)
    }

    @Test func volumeStepsByATenthWithinTheBoostRange() async {
        let (model, _, task) = await start()
        defer { task.cancel() }

        model.raiseVolume()
        #expect(model.volume == 1.1)

        model.setVolume(0.05)
        model.lowerVolume()
        #expect(model.volume == 0)

        model.setVolume(2)
        model.raiseVolume()
        #expect(model.volume == 2)
    }

    @Test func repeatedFastForwardGoesFasterAndStopRestoresTheRate() async {
        let (model, engine, task) = await start(rate: 1.25)
        defer { task.cancel() }

        model.shuttleForward()
        #expect(model.rate == 1.5)
        model.shuttleForward()
        #expect(model.rate == 2)
        model.shuttleForward()
        model.shuttleForward()
        #expect(model.rate == 3)

        model.shuttleStop()
        #expect(model.rate == 1.25)
        await eventually { engine.calls.contains(.pause) && model.status == .paused }
    }

    @Test func fastForwardWhilePausedJustPlays() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }
        model.shuttleStop()
        await eventually { model.status == .paused }

        model.shuttleForward()

        await eventually { model.isPlaying }
        #expect(model.rate == 1)
        #expect(engine.calls.last == .play)
    }

    @Test func changingSpeedByHandEndsTheShuttle() async {
        let (model, _, task) = await start()
        defer { task.cancel() }

        model.shuttleForward()
        model.speedUp()
        model.shuttleStop()

        #expect(model.rate == 1.75)
    }

    @Test func quickRewindsJumpFurtherEachTime() async {
        let (model, _, task) = await start(at: .seconds(500))
        defer { task.cancel() }

        model.shuttleBackward()
        #expect(model.position == .seconds(490))
        model.shuttleBackward()
        #expect(model.position == .seconds(470))
        model.shuttleBackward()
        #expect(model.position == .seconds(430))
        model.shuttleBackward()
        model.shuttleBackward()
        #expect(model.position == .seconds(270))

        clock.advance(by: PlayerModel.shuttleRepeatWindow + .milliseconds(1))
        model.shuttleBackward()
        #expect(model.position == .seconds(260))
    }

    @Test func rewindDropsTheFastForwardSpeed() async {
        let (model, _, task) = await start()
        defer { task.cancel() }

        model.shuttleForward()
        model.shuttleBackward()

        #expect(model.rate == 1)
    }

    @Test func leavingThePointerHidesControlsOnlyWhenTheyCouldAutoHide() async {
        let (model, _, task) = await start()
        defer { task.cancel() }

        model.revealControls()
        model.isMenuPresented = true
        model.pointerDidLeave()
        #expect(model.areControlsVisible)

        model.isMenuPresented = false
        model.pointerDidLeave()
        #expect(!model.areControlsVisible)

        model.revealControls()
        #expect(model.areControlsVisible)
    }
}
