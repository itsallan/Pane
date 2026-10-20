import Domain
import Foundation

public struct BookmarkImporter: MediaImporter {
    private let library: SwiftDataLibraryRepository

    public init(library: SwiftDataLibraryRepository) {
        self.library = library
    }

    public func importMedia(at urls: [URL]) async throws -> [MediaItem] {
        var imported: [MediaItem] = []
        for url in urls {
            // URLs from the file importer, drops and Open In arrive scoped; reading or bookmarking them needs the scope open.
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            if url.hasDirectoryPath || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                imported += try await importFolder(at: url)
            } else if PlayableContent.isPlayable(url), let item = try await importFile(at: url, folder: nil) {
                imported.append(item)
            }
        }
        return imported
    }

    private func importFolder(at url: URL) async throws -> [MediaItem] {
        let bookmark = try SecurityScopedBookmark.make(for: url)
        let candidate = LibraryFolder(name: url.lastPathComponent)
        let folder = try await library.insertFolder(candidate, bookmark: bookmark, importedPath: url.standardizedFileURL.path(percentEncoded: false), scope: url)

        var imported: [MediaItem] = []
        for file in Self.playableFiles(in: url) {
            if let item = try await importFile(at: file, folder: folder.id) {
                imported.append(item)
            }
        }
        return imported
    }

    private func importFile(at url: URL, folder: LibraryFolder.ID?) async throws -> MediaItem? {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        guard try await !library.containsFile(atPath: path) else { return nil }
        let item = MediaItem(
            title: url.deletingPathExtension().lastPathComponent,
            source: .file(bookmark: try SecurityScopedBookmark.make(for: url)),
            folderID: folder
        )
        try await library.insertFile(item, importedPath: path)
        return item
    }

    private static func playableFiles(in folder: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        let files = (enumerator?.allObjects as? [URL]) ?? []
        return files
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true && PlayableContent.isPlayable($0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
