import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

struct ProgressMappingTests {
    private let item = UUID()

    private func makeRepository() throws -> SwiftDataProgressRepository {
        SwiftDataProgressRepository(modelContainer: try .library(inMemory: true))
    }

    @Test func recordKeepsMillisecondPrecision() {
        let record = ProgressRecord(itemID: item, positionMilliseconds: 0, durationMilliseconds: nil, isWatched: false, updatedAt: .now)
        record.update(from: PlaybackProgress(position: .milliseconds(83_250), duration: .seconds(5400)), at: .now)

        #expect(record.positionMilliseconds == 83_250)
        #expect(record.durationMilliseconds == 5_400_000)
        #expect(record.playbackProgress == PlaybackProgress(position: .milliseconds(83_250), duration: .seconds(5400)))
    }

    @Test func unknownDurationStaysUnknown() {
        let record = ProgressRecord(itemID: item, positionMilliseconds: 45_000, durationMilliseconds: nil, isWatched: false, updatedAt: .now)

        #expect(record.playbackProgress == PlaybackProgress(position: .seconds(45), duration: nil))
    }

    @Test func savedProgressReadsBack() async throws {
        let repository = try makeRepository()
        let progress = PlaybackProgress(position: .seconds(90), duration: .seconds(600))

        try await repository.save(progress, for: item)
        try await repository.save(PlaybackProgress(position: .seconds(120), duration: .seconds(600)), for: item)

        #expect(try await repository.progress(for: item) == PlaybackProgress(position: .seconds(120), duration: .seconds(600)))
        #expect(try await repository.allProgress().count == 1)
        #expect(try await repository.lastPlayedDates()[item] != nil)
    }

    @Test func markingWatchedClearsTheResumePoint() async throws {
        let repository = try makeRepository()
        try await repository.save(PlaybackProgress(position: .seconds(90), duration: .seconds(600)), for: item)

        try await repository.markWatched(item)

        #expect(try await repository.progress(for: item) == nil)
        #expect(try await repository.allProgress().isEmpty)
        #expect(try await repository.watchedItems() == [item])
    }

    @Test func savingAfterWatchedStartsAgain() async throws {
        let repository = try makeRepository()
        try await repository.markWatched(item)

        try await repository.save(PlaybackProgress(position: .seconds(40), duration: .seconds(600)), for: item)

        #expect(try await repository.watchedItems().isEmpty)
        #expect(try await repository.progress(for: item)?.position == .seconds(40))
    }

    @Test func resetForgetsEverything() async throws {
        let repository = try makeRepository()
        try await repository.markWatched(item)

        try await repository.resetProgress(for: item)

        #expect(try await repository.watchedItems().isEmpty)
        #expect(try await repository.lastPlayedDates().isEmpty)
    }

    @Test func deletingAnItemDropsItsProgress() async throws {
        let container = try ModelContainer.library(inMemory: true)
        let library = SwiftDataLibraryRepository(modelContainer: container)
        let progress = SwiftDataProgressRepository(modelContainer: container)
        let movie = MediaItem(id: item, title: "Movie", source: .stream(URL(filePath: "/movie.mkv")), duration: .seconds(600))
        try await library.save(movie)
        try await progress.save(PlaybackProgress(position: .seconds(90), duration: .seconds(600)), for: item)

        try await library.deleteItem(withID: item)

        #expect(try await library.items().isEmpty)
        #expect(try await progress.allProgress().isEmpty)
    }

    @Test func itemRoundTripsEverySource() async throws {
        let library = SwiftDataLibraryRepository(modelContainer: try .library(inMemory: true))
        let items = [
            MediaItem(title: "File", source: .file(bookmark: Data([1, 2, 3])), duration: .milliseconds(1500)),
            MediaItem(title: "Stream", source: .stream(URL(string: "https://example.com/a.m3u8")!)),
            MediaItem(title: "Share", source: .networkShare(server: UUID(), path: "/Movies/a.mkv")),
        ]
        for item in items {
            try await library.save(item)
        }

        for item in items {
            #expect(try await library.item(withID: item.id) == item)
        }
    }
}
