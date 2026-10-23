import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

struct CloudKitStoreTests {
    private let fileID = UUID(uuidString: "A0A0A0A0-0000-4000-8000-000000000001")!
    private let streamID = UUID(uuidString: "A0A0A0A0-0000-4000-8000-000000000002")!
    private let serverID = UUID(uuidString: "B0B0B0B0-0000-4000-8000-000000000001")!

    // The fixture was written by the schema that still had unique attributes and non-optional properties without defaults.
    private func copyOfStoreFromBeforeCloudKit() throws -> URL {
        let fixture = try #require(Bundle.module.url(forResource: "LibraryBeforeCloudKit", withExtension: "store", subdirectory: "Fixtures"))
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let copy = directory.appending(path: "Library.store")
        try FileManager.default.copyItem(at: fixture, to: copy)
        return copy
    }

    @Test func opensAStoreFromBeforeTheSchemaChange() async throws {
        let container = try ModelContainer.library(at: try copyOfStoreFromBeforeCloudKit())
        let library = SwiftDataLibraryRepository(modelContainer: container)
        let progress = SwiftDataProgressRepository(modelContainer: container)
        let servers = SwiftDataNetworkServerRepository(modelContainer: container)
        let history = SwiftDataStreamHistoryRepository(modelContainer: container)

        try await library.restoreFileAccess()

        #expect(Set(try await library.items().map(\.id)) == [fileID, streamID])
        #expect(try await library.folders().map(\.name) == ["Movies"])
        #expect(try await library.item(withID: fileID)?.folderID != nil)
        #expect(try await progress.progress(for: fileID) == PlaybackProgress(position: .seconds(120), duration: .seconds(600)))
        #expect(try await servers.server(withID: serverID)?.host == "nas.local")
        #expect(try await history.recentStreams().map(\.url) == [URL(string: "https://example.com/live.m3u8")!])
    }

    @Test func hidesFilesAndFoldersImportedOnAnotherDevice() async throws {
        let container = try ModelContainer.library(inMemory: true)
        let context = ModelContext(container)
        let folder = FolderRecord(id: UUID(), name: "Elsewhere", bookmark: Data([1]), importedPath: "/x", dateAdded: .now, originDevice: "other-device")
        let file = MediaItemRecord(id: UUID(), title: "Elsewhere", sourceKind: .file, dateAdded: .now)
        file.bookmark = Data([2])
        file.originDevice = "other-device"
        let stream = MediaItemRecord(id: UUID(), title: "Synced Stream", sourceKind: .stream, dateAdded: .now)
        stream.streamURL = URL(string: "https://example.com/a.m3u8")
        stream.originDevice = "other-device"
        [folder].forEach(context.insert)
        [file, stream].forEach(context.insert)
        try context.save()

        let library = SwiftDataLibraryRepository(modelContainer: container)

        #expect(try await library.items().map(\.title) == ["Synced Stream"])
        #expect(try await library.folders().isEmpty)
        #expect(try await library.item(withID: file.id) != nil)
    }

    @Test func theLatestOfDuplicateProgressWins() async throws {
        let container = try ModelContainer.library(inMemory: true)
        let context = ModelContext(container)
        let item = UUID()
        context.insert(ProgressRecord(itemID: item, positionMilliseconds: 60_000, durationMilliseconds: 600_000, isWatched: false, updatedAt: .distantPast))
        context.insert(ProgressRecord(itemID: item, positionMilliseconds: 300_000, durationMilliseconds: 600_000, isWatched: false, updatedAt: .now))
        try context.save()

        let progress = SwiftDataProgressRepository(modelContainer: container)

        let expected = PlaybackProgress(position: .seconds(300), duration: .seconds(600))
        #expect(try await progress.progress(for: item) == expected)
        #expect(try await progress.allProgress() == [item: expected])
    }

    @Test func historyListsAURLRecordedOnTwoDevicesOnce() async throws {
        let container = try ModelContainer.library(inMemory: true)
        let context = ModelContext(container)
        let url = URL(string: "https://example.com/a.m3u8")!
        context.insert(RecentStreamRecord(url: url, lastOpened: .distantPast))
        context.insert(RecentStreamRecord(url: url, lastOpened: .now))
        try context.save()

        #expect(try await SwiftDataStreamHistoryRepository(modelContainer: container).recentStreams().map(\.url) == [url])
    }
}
