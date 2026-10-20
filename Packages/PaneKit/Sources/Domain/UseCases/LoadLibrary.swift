public struct LoadLibrary: Sendable {
    private let library: any LibraryRepository
    private let progress: any ProgressRepository

    public init(library: any LibraryRepository, progress: any ProgressRepository) {
        self.library = library
        self.progress = progress
    }

    /// Newest first.
    public func callAsFunction() async throws -> [LibraryEntry] {
        async let items = library.items()
        async let saved = progress.allProgress()
        async let watched = progress.watchedItems()
        async let played = progress.lastPlayedDates()
        let (allItems, savedProgress, watchedIDs, lastPlayed) = try await (items, saved, watched, played)

        return allItems
            .sorted { ($0.dateAdded, $1.title) > ($1.dateAdded, $0.title) }
            .map { item in
                var resume = savedProgress[item.id]
                if resume?.duration == nil {
                    resume?.duration = item.duration
                }
                return LibraryEntry(
                    item: item,
                    resumePosition: resume?.resumePosition,
                    isWatched: watchedIDs.contains(item.id),
                    lastPlayed: lastPlayed[item.id]
                )
            }
    }
}
