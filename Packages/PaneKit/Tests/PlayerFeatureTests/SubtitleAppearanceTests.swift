import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct SubtitleAppearanceTests {
    private let source = MediaSource.stream(URL(filePath: "/movie.mkv"))

    private func start(saved: SavedStyles = SavedStyles()) async -> (PlayerModel, FakePlaybackEngine, Task<Void, Never>) {
        let engine = FakePlaybackEngine(stateOnLoad: PlaybackState(status: .playing, isSeekable: true))
        let progress = InMemoryProgressRepository()
        let item = MediaItem(title: "Movie", source: source)
        let model = PlayerModel(
            engine: engine,
            item: item,
            resume: ResumePlayback(engine: engine, progress: progress),
            saveProgress: SaveProgress(item: item.id, repository: progress, clock: ManualClock()),
            pickTracks: PickPreferredTracks(engine: engine, preferences: InMemoryPreferencesRepository()),
            subtitleStyle: SubtitleStyle(size: .large),
            saveSubtitleStyle: { style in await saved.append(style) },
            clock: ManualClock()
        )
        let task = Task { await model.run() }
        await eventually { model.isPlaying }
        return (model, engine, task)
    }

    @Test func editingPausesAndDoneResumes() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }

        model.subtitleAppearance.beginEditing()
        #expect(model.subtitleAppearance.isEditing)
        await eventually { engine.calls.last == .pause }

        model.subtitleAppearance.endEditing()
        #expect(!model.subtitleAppearance.isEditing)
        await eventually { engine.calls.last == .play }
    }

    @Test func editingWhilePausedStaysPaused() async {
        let (model, engine, task) = await start()
        defer { task.cancel() }
        model.togglePlayback()
        await eventually { model.status == .paused }

        model.subtitleAppearance.beginEditing()
        model.subtitleAppearance.endEditing()
        await settle()

        #expect(engine.calls.filter { $0 == .play }.isEmpty)
    }

    @Test func changesReachTheEngineAndAreSaved() async {
        let saved = SavedStyles()
        let (model, engine, task) = await start(saved: saved)
        defer { task.cancel() }
        #expect(model.subtitleAppearance.size == .large)

        model.subtitleAppearance.size = .small
        model.subtitleAppearance.size = .small

        let expected = SubtitleStyle(size: .small)
        await eventually { await saved.styles == [expected] }
        #expect(engine.calls.filter { $0 == .setSubtitleStyle(expected) }.count == 1)
        #expect(!model.subtitleAppearance.waitsForNextVideo)

        model.subtitleAppearance.background = .solid
        #expect(model.subtitleAppearance.waitsForNextVideo)
    }
}

private actor SavedStyles {
    private(set) var styles: [SubtitleStyle] = []

    func append(_ style: SubtitleStyle) {
        styles.append(style)
    }
}
