import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct PlayerModelTrackTests {
    private let source = MediaSource.stream(URL(filePath: "/movie.mkv"))
    private let tracks = [
        MediaTrack(id: "audio/1", kind: .audio, language: "en"),
        MediaTrack(id: "audio/2", kind: .audio, language: "fr"),
        MediaTrack(id: "spu/3", kind: .subtitle, language: "en"),
    ]

    private func start(_ engine: FakePlaybackEngine) async -> (PlayerModel, Task<Void, Never>) {
        let model = PlayerModel(engine: engine, source: source, clock: ManualClock())
        let task = Task { await model.run() }
        await eventually { engine.calls.contains(.load(source)) && model.status == engine.state.status }
        return (model, task)
    }

    @Test func splitsTracksByKind() async {
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing, tracks: tracks, selectedTrackIDs: ["audio/1"]))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        #expect(model.audioTracks.map(\.id) == ["audio/1", "audio/2"])
        #expect(model.subtitleTracks.map(\.id) == ["spu/3"])
        #expect(model.areSubtitlesOff)
    }

    @Test func addsACopyOfTheSubtitleFile() async throws {
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing, tracks: tracks))
        let (model, task) = await start(engine)
        defer { task.cancel() }
        let file = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).srt")
        try Data("1\n00:00:01,000 --> 00:00:02,000\nHello\n".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        await model.addSubtitle(from: file)

        let added = try #require(engine.calls.compactMap { call -> URL? in
            guard case .addSubtitle(let url) = call else { return nil }
            return url
        }.first)
        #expect(added != file)
        #expect(added.lastPathComponent == file.lastPathComponent)
        #expect(FileManager.default.contents(atPath: added.path(percentEncoded: false)) == FileManager.default.contents(atPath: file.path(percentEncoded: false)))
        await eventually { !model.areSubtitlesOff }
        #expect(!model.areSubtitlesOff)
        #expect(!model.subtitleImportFailed)
    }

    @Test func reportsAnUnreadableSubtitleFile() async {
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing))
        let (model, task) = await start(engine)
        defer { task.cancel() }

        await model.addSubtitle(from: URL(filePath: "/missing/\(UUID().uuidString).srt"))

        #expect(model.subtitleImportFailed)
        #expect(!engine.calls.contains { if case .addSubtitle = $0 { true } else { false } })
    }

    @Test func trackSheetKeepsControlsUp() async {
        let clock = ManualClock()
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing))
        let model = PlayerModel(engine: engine, source: source, clock: clock)
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { model.isPlaying }

        model.isTrackSheetPresented = true
        clock.advance(by: PlayerModel.autoHideDelay * 2)
        await settle()

        #expect(model.areControlsVisible)
    }
}
