import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct ABLoopTests {
    private let source = MediaSource.stream(URL(filePath: "/movie.mkv"))

    private func playing(at position: Duration) -> PlaybackState {
        PlaybackState(status: .playing, progress: PlaybackProgress(position: position, duration: .seconds(600)), isSeekable: true)
    }

    private func start() async -> (PlayerModel, FakePlaybackEngine, Task<Void, Never>) {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .seconds(60)))
        let model = PlayerModel(engine: engine, source: source, clock: ManualClock())
        let task = Task { await model.run() }
        await eventually { model.position == .seconds(60) }
        return (model, engine, task)
    }

    @Test func marksAThenBThenClears() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }

        model.loop.mark()
        #expect(model.loop.start == .seconds(60))
        #expect(model.loop.range == nil)

        engine.send(playing(at: .seconds(75)))
        await eventually { model.position == .seconds(75) }
        model.loop.mark()
        #expect(model.loop.range == .seconds(60) ... .seconds(75))
        #expect(model.loop.start == nil)
        await eventually { engine.calls.contains(.setLoop(.seconds(60) ... .seconds(75))) }

        model.loop.mark()
        #expect(model.loop.range == nil)
        await eventually { engine.calls.last == .setLoop(nil) }
    }

    @Test func bBeforeAIsSwapped() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }

        model.loop.mark()
        engine.send(playing(at: .seconds(40)))
        await eventually { model.position == .seconds(40) }
        model.loop.mark()

        #expect(model.loop.range == .seconds(40) ... .seconds(60))
    }

    @Test func ignoresAnEndTooCloseToTheStart() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }

        model.loop.mark()
        engine.send(playing(at: .milliseconds(60500)))
        await eventually { model.position == .milliseconds(60500) }
        model.loop.mark()

        #expect(model.loop.range == nil)
        #expect(model.loop.start == .seconds(60))
        #expect(!engine.calls.contains { if case .setLoop = $0 { true } else { false } })
    }
}
