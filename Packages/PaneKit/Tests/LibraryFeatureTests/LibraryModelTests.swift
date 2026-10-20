import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import LibraryFeature

@MainActor
struct LibraryModelTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)
    private let folder = LibraryFolder(name: "Season 1")
    private let alpha: MediaItem
    private let bravo: MediaItem
    private let charlie: MediaItem
    private let delta: MediaItem

    init() {
        alpha = MediaItem(title: "Alpha", source: .stream(URL(filePath: "/a.mkv")), duration: .seconds(600), dateAdded: now)
        bravo = MediaItem(title: "Bravo", source: .stream(URL(filePath: "/b.mkv")), duration: .seconds(600), dateAdded: now - 10)
        charlie = MediaItem(title: "Charlie", source: .stream(URL(filePath: "/c.mkv")), duration: .seconds(600), dateAdded: now - 20, folderID: folder.id)
        delta = MediaItem(title: "delta", source: .stream(URL(filePath: "/d.mkv")), duration: .seconds(600), dateAdded: now - 30)
    }

    private func makeModel(
        scope: LibraryScope = .all,
        library: InMemoryLibraryRepository? = nil,
        progress: InMemoryProgressRepository? = nil,
        thumbnails: FakeThumbnailProvider = FakeThumbnailProvider()
    ) -> (LibraryModel, InMemoryLibraryRepository, InMemoryProgressRepository) {
        let library = library ?? InMemoryLibraryRepository(items: [alpha, bravo, charlie, delta], folders: [folder])
        let progress = progress ?? InMemoryProgressRepository(
            progress: [
                alpha.id: PlaybackProgress(position: .seconds(100), duration: .seconds(600)),
                bravo.id: PlaybackProgress(position: .seconds(200), duration: .seconds(600)),
                // Under 30 s: ResumePlayback would start over, so it isn't "continue watching".
                delta.id: PlaybackProgress(position: .seconds(10), duration: .seconds(600)),
            ],
            watched: [charlie.id],
            lastPlayed: [alpha.id: now - 100, bravo.id: now, charlie.id: now - 50, delta.id: now - 5]
        )
        let model = LibraryModel(scope: scope, library: library, progress: progress, importer: FakeMediaImporter(library: library), thumbnails: thumbnails)
        return (model, library, progress)
    }

    @Test func continueWatchingFollowsResumeRulesMostRecentFirst() async {
        let (model, _, _) = makeModel()
        await model.load()

        #expect(model.continueWatching.map(\.item.title) == ["Bravo", "Alpha"])
        #expect(model.entries.map(\.item.title) == ["Alpha", "Bravo", "Charlie", "delta"])
        #expect(!model.isEmpty)
    }

    @Test func sortsAndFilters() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.sortOrder = .title
        model.filter = .unwatched
        #expect(model.entries.map(\.item.title) == ["delta"])

        model.filter = .inProgress
        #expect(model.entries.map(\.item.title) == ["Alpha", "Bravo"])

        model.filter = .all
        model.sortOrder = .recentlyPlayed
        #expect(model.entries.map(\.item.title) == ["Bravo", "delta", "Charlie", "Alpha"])
    }

    @Test func searchMatchesTitlesLoosely() async {
        let (model, _, _) = makeModel()
        await model.load()

        model.searchText = "DEL"
        #expect(model.entries.map(\.item.title) == ["delta"])
    }

    @Test func scopesNarrowTheEntries() async {
        let (recents, _, _) = makeModel(scope: .recents, progress: InMemoryProgressRepository(lastPlayed: [charlie.id: now]))
        await recents.load()
        #expect(recents.entries.map(\.item.title) == ["Charlie"])
        #expect(recents.continueWatching.isEmpty)

        let (inFolder, _, _) = makeModel(scope: .folder(folder))
        await inFolder.load()
        #expect(inFolder.entries.map(\.item.title) == ["Charlie"])
    }

    @Test func emptyLibraryIsEmpty() async {
        let (model, _, _) = makeModel(library: InMemoryLibraryRepository(), progress: InMemoryProgressRepository())
        await model.load()

        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }

    @Test func importingReloads() async {
        let library = InMemoryLibraryRepository()
        let (model, _, _) = makeModel(library: library, progress: InMemoryProgressRepository())
        await model.load()

        await model.importMedia(at: [URL(filePath: "/Movies/Sintel.mkv")])

        #expect(model.entries.map(\.item.title) == ["Sintel"])
        #expect(!model.isEmpty)
    }

    @Test func aFailedPickerShowsAnAlert() async {
        let (model, _, _) = makeModel()
        await model.importResult(.failure(CocoaError(.fileReadNoPermission)))

        #expect(model.failure == .importFailed)
        model.isShowingFailure = false
        #expect(model.failure == nil)
    }

    @Test func markingWatchedLeavesContinueWatching() async throws {
        let (model, _, progress) = makeModel()
        await model.load()
        let bravoEntry = try #require(model.continueWatching.first)

        await model.markWatched(bravoEntry)

        #expect(model.continueWatching.map(\.item.title) == ["Alpha"])
        #expect(await progress.writes.contains(.markWatched(bravo.id)))
    }

    @Test func removingForgetsItemAndProgress() async throws {
        let (model, library, progress) = makeModel()
        await model.load()
        let alphaEntry = try #require(model.entries.first { $0.id == alpha.id })

        await model.remove(alphaEntry)

        #expect(try await library.item(withID: alpha.id) == nil)
        #expect(await progress.writes.contains(.reset(alpha.id)))
        #expect(!model.entries.contains { $0.id == alpha.id })
    }

    @Test func postersComeFromEarlyInTheVideoAndAreReused() async {
        let thumbnails = FakeThumbnailProvider()
        let (model, _, _) = makeModel(thumbnails: thumbnails)

        _ = await model.poster(for: alpha)
        _ = await model.poster(for: alpha)
        let long = MediaItem(title: "Long", source: .stream(URL(filePath: "/l.mkv")), duration: .seconds(7200))
        _ = await model.poster(for: long)

        #expect(await thumbnails.requests.map(\.position) == [.seconds(60), .seconds(120)])
    }
}
