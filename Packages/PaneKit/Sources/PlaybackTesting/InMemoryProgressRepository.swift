import Domain
import Foundation

public actor InMemoryProgressRepository: ProgressRepository {
    public enum Write: Sendable, Hashable {
        case save(PlaybackProgress, MediaItem.ID)
        case markWatched(MediaItem.ID)
        case reset(MediaItem.ID)
    }

    public private(set) var writes: [Write] = []
    private var saved: [MediaItem.ID: PlaybackProgress]
    private var watched: Set<MediaItem.ID>
    private var lastPlayed: [MediaItem.ID: Date]
    private var failsReads: Bool

    public init(
        progress: [MediaItem.ID: PlaybackProgress] = [:],
        watched: Set<MediaItem.ID> = [],
        lastPlayed: [MediaItem.ID: Date] = [:],
        failsReads: Bool = false
    ) {
        saved = progress
        self.watched = watched
        self.lastPlayed = lastPlayed
        self.failsReads = failsReads
    }

    public func progress(for item: MediaItem.ID) async throws -> PlaybackProgress? {
        try checkReadable()
        return saved[item]
    }

    public func allProgress() async throws -> [MediaItem.ID: PlaybackProgress] {
        try checkReadable()
        return saved
    }

    public func watchedItems() async throws -> Set<MediaItem.ID> {
        try checkReadable()
        return watched
    }

    public func lastPlayedDates() async throws -> [MediaItem.ID: Date] {
        try checkReadable()
        return lastPlayed
    }

    public func save(_ progress: PlaybackProgress, for item: MediaItem.ID) async throws {
        writes.append(.save(progress, item))
        saved[item] = progress
        watched.remove(item)
        lastPlayed[item] = .now
    }

    public func markWatched(_ item: MediaItem.ID) async throws {
        writes.append(.markWatched(item))
        saved[item] = nil
        watched.insert(item)
        lastPlayed[item] = .now
    }

    public func resetProgress(for item: MediaItem.ID) async throws {
        writes.append(.reset(item))
        saved[item] = nil
        watched.remove(item)
        lastPlayed[item] = nil
    }

    private func checkReadable() throws {
        guard !failsReads else { throw ReadFailure() }
    }

    private struct ReadFailure: Error {}
}
