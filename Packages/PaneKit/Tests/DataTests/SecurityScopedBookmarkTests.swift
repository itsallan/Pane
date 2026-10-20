import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

struct SecurityScopedBookmarkTests {
    private let directory: URL

    init() throws {
        directory = URL.temporaryDirectory.appending(path: "BookmarkTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func makeFile(_ name: String, in folder: URL? = nil) throws -> URL {
        let url = (folder ?? directory).appending(path: name)
        try Data("frames".utf8).write(to: url)
        return url
    }

    @Test func resolvesToTheBookmarkedFile() throws {
        let file = try makeFile("movie.mkv")
        let resolution = try SecurityScopedBookmark.resolve(try SecurityScopedBookmark.make(for: file))

        #expect(resolution.url.standardizedFileURL.resolvingSymlinksInPath() == file.standardizedFileURL.resolvingSymlinksInPath())
        #expect(resolution.refreshed == nil)
    }

    @Test func followsAFileThatMoved() throws {
        let file = try makeFile("before.mkv")
        let bookmark = try SecurityScopedBookmark.make(for: file)
        let moved = directory.appending(path: "after.mkv")
        try FileManager.default.moveItem(at: file, to: moved)

        let resolution = try SecurityScopedBookmark.resolve(bookmark)

        #expect(resolution.url.lastPathComponent == "after.mkv")
    }

    @Test func garbageIsUnresolvable() {
        #expect(throws: PlaybackError.unresolvableBookmark) {
            try SecurityScopedBookmark.resolve(Data("not a bookmark".utf8))
        }
    }

    @Test func importedFilesKeepAResolvableBookmark() async throws {
        let file = try makeFile("Big Buck Bunny.mp4")
        let library = SwiftDataLibraryRepository(modelContainer: try .library(inMemory: true))
        let importer = BookmarkImporter(library: library)

        let imported = try await importer.importMedia(at: [file])

        let item = try #require(imported.first)
        #expect(item.title == "Big Buck Bunny")
        guard case .file(let bookmark) = try await library.item(withID: item.id)?.source else {
            Issue.record("Imported file should be stored as a bookmark")
            return
        }
        #expect(try SecurityScopedBookmark.resolve(bookmark).url.lastPathComponent == "Big Buck Bunny.mp4")
    }

    @Test func importingTheSameFileTwiceAddsItOnce() async throws {
        let file = try makeFile("movie.mkv")
        let library = SwiftDataLibraryRepository(modelContainer: try .library(inMemory: true))
        let importer = BookmarkImporter(library: library)

        _ = try await importer.importMedia(at: [file])
        let second = try await importer.importMedia(at: [file])

        #expect(second.isEmpty)
        #expect(try await library.items().count == 1)
    }

    @Test func folderImportTakesOnlyPlayableFiles() async throws {
        let folder = directory.appending(path: "Season 1", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = try makeFile("E02.mkv", in: folder)
        _ = try makeFile("E01.mp4", in: folder)
        _ = try makeFile("notes.txt", in: folder)
        let library = SwiftDataLibraryRepository(modelContainer: try .library(inMemory: true))

        let imported = try await BookmarkImporter(library: library).importMedia(at: [folder])

        #expect(imported.map(\.title) == ["E01", "E02"])
        let folders = try await library.folders()
        #expect(folders.map(\.name) == ["Season 1"])
        #expect(imported.allSatisfy { $0.folderID == folders.first?.id })

        try await library.deleteFolder(withID: try #require(folders.first).id)
        #expect(try await library.items().isEmpty)
    }
}
