import Domain
import Foundation
import SwiftData

@ModelActor
public actor SwiftDataProgressRepository: ProgressRepository {
    public func progress(for item: MediaItem.ID) async throws -> PlaybackProgress? {
        guard let record = try record(for: item), !record.isWatched else { return nil }
        return record.playbackProgress
    }

    public func allProgress() async throws -> [MediaItem.ID: PlaybackProgress] {
        try latestRecords().filter { !$0.value.isWatched }.mapValues(\.playbackProgress)
    }

    public func watchedItems() async throws -> Set<MediaItem.ID> {
        Set(try latestRecords().filter(\.value.isWatched).keys)
    }

    public func lastPlayedDates() async throws -> [MediaItem.ID: Date] {
        let records = try modelContext.fetch(FetchDescriptor<ProgressRecord>())
        return Dictionary(records.map { ($0.itemID, $0.updatedAt) }, uniquingKeysWith: max)
    }

    public func save(_ progress: PlaybackProgress, for item: MediaItem.ID) async throws {
        if let record = try record(for: item) {
            record.update(from: progress, at: .now)
        } else {
            modelContext.insert(ProgressRecord(
                itemID: item,
                positionMilliseconds: progress.position.milliseconds,
                durationMilliseconds: progress.duration?.milliseconds,
                isWatched: false,
                updatedAt: .now
            ))
        }
        try modelContext.save()
    }

    public func markWatched(_ item: MediaItem.ID) async throws {
        let record = try record(for: item) ?? {
            let record = ProgressRecord(itemID: item, positionMilliseconds: 0, durationMilliseconds: nil, isWatched: true, updatedAt: .now)
            modelContext.insert(record)
            return record
        }()
        record.positionMilliseconds = 0
        record.isWatched = true
        record.updatedAt = .now
        try modelContext.save()
    }

    public func resetProgress(for item: MediaItem.ID) async throws {
        try modelContext.delete(model: ProgressRecord.self, where: #Predicate { $0.itemID == item })
        try modelContext.save()
    }

    private func latestRecords() throws -> [MediaItem.ID: ProgressRecord] {
        let records = try modelContext.fetch(FetchDescriptor<ProgressRecord>())
        return Dictionary(records.map { ($0.itemID, $0) }, uniquingKeysWith: { $0.updatedAt >= $1.updatedAt ? $0 : $1 })
    }

    // Two devices can each save progress for an item before they sync; the most recent one wins.
    private func record(for item: MediaItem.ID) throws -> ProgressRecord? {
        var descriptor = FetchDescriptor<ProgressRecord>(
            predicate: #Predicate { $0.itemID == item },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
