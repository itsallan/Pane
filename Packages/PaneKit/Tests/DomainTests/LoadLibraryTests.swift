import Domain
import Foundation
import PlaybackTesting
import Testing

struct LoadLibraryTests {
    @Test func combinesItemsWithResumeAndWatchedState() async throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let old = MediaItem(title: "Old", source: .stream(URL(filePath: "/old.mkv")), duration: .seconds(600), dateAdded: base)
        let new = MediaItem(title: "New", source: .stream(URL(filePath: "/new.mkv")), duration: .seconds(600), dateAdded: base.addingTimeInterval(60))
        let barely = MediaItem(title: "Barely", source: .stream(URL(filePath: "/barely.mkv")), duration: .seconds(600), dateAdded: base)
        let progress = InMemoryProgressRepository(
            progress: [
                old.id: PlaybackProgress(position: .seconds(120), duration: nil),
                barely.id: PlaybackProgress(position: .seconds(10), duration: .seconds(600)),
            ],
            watched: [new.id]
        )

        let entries = try await LoadLibrary(library: InMemoryLibraryRepository(items: [old, barely, new]), progress: progress)()

        #expect(entries.map(\.item.title) == ["New", "Barely", "Old"])
        #expect(entries.map(\.resumePosition) == [nil, nil, .seconds(120)])
        #expect(entries.map(\.isWatched) == [true, false, false])
    }
}
