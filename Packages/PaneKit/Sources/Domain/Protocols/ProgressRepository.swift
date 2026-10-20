public protocol ProgressRepository: Sendable {
    func progress(for item: MediaItem.ID) async throws -> PlaybackProgress?
    func allProgress() async throws -> [MediaItem.ID: PlaybackProgress]
    func watchedItems() async throws -> Set<MediaItem.ID>
    func save(_ progress: PlaybackProgress, for item: MediaItem.ID) async throws
    /// Marks the item watched and clears its resume point.
    func markWatched(_ item: MediaItem.ID) async throws
}
