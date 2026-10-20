import Foundation

public protocol ProgressRepository: Sendable {
    func progress(for item: MediaItem.ID) async throws -> PlaybackProgress?
    func allProgress() async throws -> [MediaItem.ID: PlaybackProgress]
    func watchedItems() async throws -> Set<MediaItem.ID>
    /// When each item last had its progress saved or was marked watched.
    func lastPlayedDates() async throws -> [MediaItem.ID: Date]
    func save(_ progress: PlaybackProgress, for item: MediaItem.ID) async throws
    /// Marks the item watched and clears its resume point.
    func markWatched(_ item: MediaItem.ID) async throws
    /// Forgets the resume point and the watched mark.
    func resetProgress(for item: MediaItem.ID) async throws
}
