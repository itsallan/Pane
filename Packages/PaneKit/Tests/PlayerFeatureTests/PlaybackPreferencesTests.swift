import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct PlaybackPreferencesTests {
    private let clock = ManualClock()
    private let item = MediaItem(title: "Movie", source: .stream(URL(filePath: "/movie.mkv")), duration: .seconds(600))

    private var playing: PlaybackState {
        PlaybackState(status: .playing, progress: PlaybackProgress(position: .zero, duration: .seconds(600)), isSeekable: true)
    }

    private func makeModel(
        engine: FakePlaybackEngine,
        playback: PlaybackPreferences,
        progress: InMemoryProgressRepository = InMemoryProgressRepository()
    ) -> PlayerModel {
        let preferences = InMemoryPreferencesRepository(playback: playback)
        return PlayerModel(
            engine: engine,
            item: item,
            resume: ResumePlayback(engine: engine, progress: progress),
            saveProgress: SaveProgress(item: item.id, repository: progress, clock: clock),
            pickTracks: PickPreferredTracks(engine: engine, preferences: preferences),
            preferences: preferences,
            clock: clock
        )
    }

    @Test func appliesThePreferencesWhenItLoads() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing)
        let preferences = PlaybackPreferences(
            defaultRate: 1.5,
            skipInterval: .seconds(30),
            usesHardwareDecoding: false,
            gestures: GesturePreferences(doubleTapSeeks: false)
        )
        let model = makeModel(engine: engine, playback: preferences)
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { engine.calls.contains(.setRate(1.5)) }
        #expect(model.skipInterval == .seconds(30))
        #expect(!model.gestures.doubleTapSeeks)
        let calls = engine.calls
        let decoding = calls.firstIndex(of: .setHardwareDecoding(false))
        let load = calls.firstIndex(of: .load(item.source))
        #expect(decoding != nil && load != nil && decoding! < load!)
    }

    @Test func skipsByTheChosenInterval() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing)
        let model = makeModel(engine: engine, playback: PlaybackPreferences(skipInterval: .seconds(15)))
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { model.isSeekable && model.skipInterval == .seconds(15) }

        model.skip(by: model.skipInterval)
        await eventually { engine.calls.contains(.seek(to: .seconds(15), precision: .exact)) }
        #expect(engine.calls.contains(.seek(to: .seconds(15), precision: .exact)))
    }

    @Test func askOffersTheSavedPositionInsteadOfSeeking() async {
        let progress = InMemoryProgressRepository(progress: [item.id: PlaybackProgress(position: .seconds(120), duration: .seconds(600))])
        let engine = FakePlaybackEngine(stateOnLoad: playing)
        let model = makeModel(engine: engine, playback: PlaybackPreferences(resume: .ask), progress: progress)
        let task = Task { await model.run() }
        defer { task.cancel() }

        await eventually { model.resumeOffer != nil }
        #expect(model.resumeOffer == .seconds(120))
        #expect(!engine.calls.contains { if case .seek = $0 { true } else { false } })

        model.acceptResumeOffer()
        #expect(model.resumeOffer == nil)
        await eventually { engine.calls.contains(.seek(to: .seconds(120), precision: .exact)) }
        #expect(engine.calls.contains(.seek(to: .seconds(120), precision: .exact)))
    }

    @Test func theOfferLapses() async {
        let progress = InMemoryProgressRepository(progress: [item.id: PlaybackProgress(position: .seconds(120), duration: .seconds(600))])
        let model = makeModel(engine: FakePlaybackEngine(stateOnLoad: playing), playback: PlaybackPreferences(resume: .ask), progress: progress)
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { model.resumeOffer != nil }

        clock.advance(by: PlayerModel.resumeOfferDuration)
        await eventually { model.resumeOffer == nil }
        #expect(model.resumeOffer == nil)
    }

    @Test func neverStartsFromTheBeginningWithoutAnOffer() async {
        let progress = InMemoryProgressRepository(progress: [item.id: PlaybackProgress(position: .seconds(120), duration: .seconds(600))])
        let engine = FakePlaybackEngine(stateOnLoad: playing)
        let model = makeModel(engine: engine, playback: PlaybackPreferences(resume: .never), progress: progress)
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { model.isSeekable }
        await settle()

        #expect(model.resumeOffer == nil)
        #expect(!engine.calls.contains { if case .seek = $0 { true } else { false } })
    }

    @Test func volumeStopsAtFullWithoutBoost() async {
        let engine = FakePlaybackEngine(stateOnLoad: playing)
        let model = makeModel(engine: engine, playback: PlaybackPreferences(allowsVolumeBoost: false))
        let task = Task { await model.run() }
        defer { task.cancel() }
        await eventually { !model.allowsVolumeBoost }

        model.setVolume(1.6)
        #expect(model.volume == 1)
        #expect(model.maximumVolume == 1)
    }
}
