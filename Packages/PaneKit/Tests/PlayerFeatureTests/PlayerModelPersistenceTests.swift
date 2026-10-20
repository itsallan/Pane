import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct PlayerModelPersistenceTests {
    private let clock = ManualClock()
    private let item = MediaItem(title: "Movie", source: .stream(URL(filePath: "/movie.mkv")), duration: .seconds(600))

    private func playing(at position: Duration, tracks: [MediaTrack] = [], selected: Set<MediaTrack.ID> = []) -> PlaybackState {
        PlaybackState(
            status: .playing,
            progress: PlaybackProgress(position: position, duration: .seconds(600)),
            tracks: tracks,
            selectedTrackIDs: selected,
            isSeekable: true
        )
    }

    private func makeModel(
        engine: FakePlaybackEngine,
        progress: InMemoryProgressRepository = InMemoryProgressRepository(),
        preferences: TrackPreferences = TrackPreferences()
    ) -> PlayerModel {
        PlayerModel(
            engine: engine,
            item: item,
            resume: ResumePlayback(engine: engine, progress: progress),
            saveProgress: SaveProgress(item: item.id, repository: progress, clock: clock),
            pickTracks: PickPreferredTracks(engine: engine, preferences: InMemoryPreferencesRepository(preferences: preferences)),
            clock: clock
        )
    }

    @Test func resumesAndHidesThePreSeekTime() async {
        let progress = InMemoryProgressRepository(progress: [item.id: PlaybackProgress(position: .seconds(120), duration: .seconds(600))])
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .zero), landsSeeks: false)
        let model = makeModel(engine: engine, progress: progress)
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { engine.calls.contains(.seek(to: .seconds(120), precision: .exact)) }
        engine.send(playing(at: .milliseconds(250)))
        await settle()
        #expect(model.position == .seconds(120))

        engine.send(playing(at: .seconds(120.25)))
        await eventually { model.position == .seconds(120.25) }
    }

    @Test func savesOnPause() async {
        let progress = InMemoryProgressRepository()
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .seconds(50)))
        let model = makeModel(engine: engine, progress: progress)
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { model.isPlaying }
        var paused = playing(at: .seconds(60))
        paused.status = .paused
        engine.send(paused)

        await eventually { await progress.writes.contains(.save(PlaybackProgress(position: .seconds(60), duration: .seconds(600)), item.id)) }
    }

    @Test func closingSavesThenClosesTheEngine() async {
        let progress = InMemoryProgressRepository()
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .seconds(200)))
        let model = makeModel(engine: engine, progress: progress)
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { model.position == .seconds(200) }
        await model.close()

        #expect(await progress.writes == [.save(PlaybackProgress(position: .seconds(200), duration: .seconds(600)), item.id)])
        #expect(engine.calls.last == .close)
    }

    @Test func aFailedLoadKeepsTheSavedPosition() async {
        let saved = PlaybackProgress(position: .seconds(300), duration: .seconds(600))
        let progress = InMemoryProgressRepository(progress: [item.id: saved])
        let engine = FakePlaybackEngine(failures: .init(load: .networkFailed))
        let model = makeModel(engine: engine, progress: progress)
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { model.failure != nil }
        model.sceneDidEnterBackground()
        await model.close()

        #expect(await progress.writes.isEmpty)
    }

    @Test func picksPreferredTracksOnceTracksSettle() async {
        let tracks = [
            MediaTrack(id: "audio/1", kind: .audio, language: "en", isDefault: true),
            MediaTrack(id: "audio/2", kind: .audio, language: "fr"),
        ]
        let engine = FakePlaybackEngine(stateOnLoad: playing(at: .zero, tracks: tracks, selected: ["audio/1"]))
        let model = makeModel(engine: engine, preferences: TrackPreferences(audioLanguages: [Locale.Language(identifier: "fr")]))
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { engine.calls.contains(.selectTrack("audio/2")) }
        engine.send(engine.state)
        await settle()
        #expect(engine.calls.filter { $0 == .selectTrack("audio/2") }.count == 1)
    }

    @Test func aManualPickBeforePlaybackIsKept() async {
        let tracks = [
            MediaTrack(id: "audio/1", kind: .audio, language: "en", isDefault: true),
            MediaTrack(id: "audio/2", kind: .audio, language: "fr"),
        ]
        var opening = playing(at: .zero, tracks: tracks, selected: ["audio/2"])
        opening.status = .opening
        let engine = FakePlaybackEngine(stateOnLoad: opening)
        let model = makeModel(engine: engine, preferences: TrackPreferences(audioLanguages: [Locale.Language(identifier: "en")]))
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { model.tracks.count == 2 }
        model.selectTrack(tracks[1])
        engine.update { $0.status = .playing }
        await settle()

        #expect(!engine.calls.contains(.selectTrack("audio/1")))
    }
}
