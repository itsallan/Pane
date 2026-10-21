import Domain
import Foundation
import SwiftData

@ModelActor
public actor SwiftDataStreamHistoryRepository: StreamHistoryRepository {
    // Enough to find last week's stream again without the list turning into a log.
    private static let limit = 30

    public func recentStreams() async throws -> [RecentStream] {
        var descriptor = FetchDescriptor<RecentStreamRecord>(sortBy: [SortDescriptor(\.lastOpened, order: .reverse)])
        descriptor.fetchLimit = Self.limit
        return try modelContext.fetch(descriptor).map { RecentStream(url: $0.url, lastOpened: $0.lastOpened) }
    }

    public func record(_ url: URL, at date: Date) async throws {
        if let existing = try modelContext.fetch(FetchDescriptor<RecentStreamRecord>(predicate: #Predicate { $0.url == url })).first {
            existing.lastOpened = date
        } else {
            modelContext.insert(RecentStreamRecord(url: url, lastOpened: date))
        }
        try modelContext.save()
        try trim()
    }

    public func deleteStream(_ url: URL) async throws {
        try modelContext.delete(model: RecentStreamRecord.self, where: #Predicate { $0.url == url })
        try modelContext.save()
    }

    public func deleteAllStreams() async throws {
        try modelContext.delete(model: RecentStreamRecord.self)
        try modelContext.save()
    }

    // Runs after the insert is saved: fetchOffset doesn't apply to pending inserts, so trimming first would delete everything.
    private func trim() throws {
        var descriptor = FetchDescriptor<RecentStreamRecord>(sortBy: [SortDescriptor(\.lastOpened, order: .reverse)])
        descriptor.fetchOffset = Self.limit
        for record in try modelContext.fetch(descriptor) {
            modelContext.delete(record)
        }
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}
