import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct SubtitleSyncTests {
    private let source = MediaSource.stream(URL(filePath: "/movie.mkv"))
    private let srt = """
    1
    00:00:05,000 --> 00:00:07,000
    First line

    2
    00:00:10,000 --> 00:00:12,000
    Second line

    3
    00:00:20,000 --> 00:00:22,000
    Third line
    """

    private func playing(at position: Duration) -> PlaybackState {
        PlaybackState(
            status: .playing,
            progress: PlaybackProgress(position: position, duration: .seconds(600)),
            tracks: [MediaTrack(id: "spu/1", kind: .subtitle, language: "en")],
            selectedTrackIDs: ["spu/1"],
            isSeekable: true
        )
    }

    /// A model playing at 12 s with the test file added and selected.
    private func start() async throws -> (PlayerModel, FakePlaybackEngine, Task<Void, Never>) {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .seconds(12)))
        let model = PlayerModel(engine: engine, source: source, clock: ManualClock())
        let task = Task { await model.run() }
        await eventually { model.isPlaying }
        let file = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).srt")
        try Data(srt.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        await model.addSubtitle(from: file)
        await eventually { !model.subtitleSync.cues.isEmpty }
        return (model, engine, task)
    }

    @Test func embeddedTracksCanOnlyBeNudged() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .seconds(12)))
        let model = PlayerModel(engine: engine, source: source, clock: ManualClock())
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { model.isPlaying }

        #expect(!model.subtitleSync.canSyncByEar)
        model.subtitleSync.begin()
        #expect(!model.subtitleSync.isActive)

        model.subtitleSync.nudge(by: SubtitleSync.step)
        await eventually { engine.calls.contains(.setSubtitleDelay(.milliseconds(50))) }
        #expect(model.subtitleSync.delay == .milliseconds(50))
    }

    @Test func cuesFollowTheAddedTrack() async throws {
        let (model, _, task) = try await start()
        defer { task.cancel() }

        #expect(model.subtitleSync.cues.map(\.text) == ["First line", "Second line", "Third line"])
        #expect(model.subtitleSync.canSyncByEar)

        model.selectTrack(MediaTrack(id: "spu/1", kind: .subtitle))
        await eventually { model.subtitleSync.cues.isEmpty }
        #expect(!model.subtitleSync.canSyncByEar)
    }

    @Test func hearingALineAndPickingItSetsTheDelay() async throws {
        let (model, engine, task) = try await start()
        defer { task.cancel() }

        model.subtitleSync.begin()
        #expect(model.subtitleSync.phase == .listening)
        #expect(model.areControlsVisible)

        model.subtitleSync.heardLine()
        #expect(model.subtitleSync.phase == .picking(heardAt: .seconds(12)))
        await eventually { engine.calls.last == .pause }
        // With no delay yet, the line due at 12 s in the file is the 10 s one.
        #expect(model.subtitleSync.nearestCue(toHeard: .seconds(12))?.text == "Second line")

        let third = try #require(model.subtitleSync.cues.last)
        model.subtitleSync.pick(third)

        #expect(model.subtitleSync.phase == nil)
        #expect(model.subtitleSync.delay == .seconds(-8))
        await eventually { engine.calls.suffix(2) == [.setSubtitleDelay(.seconds(-8)), .play] }
    }

    @Test func cancellingWhilePickingResumes() async throws {
        let (model, engine, task) = try await start()
        defer { task.cancel() }

        model.subtitleSync.begin()
        model.subtitleSync.heardLine()
        await eventually { engine.calls.last == .pause }
        model.subtitleSync.cancel()

        #expect(model.subtitleSync.phase == nil)
        #expect(model.subtitleSync.delay == .zero)
        await eventually { engine.calls.last == .play }
    }
}
