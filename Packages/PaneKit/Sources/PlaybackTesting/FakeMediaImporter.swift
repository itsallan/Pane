import Domain
import Foundation

/// Turns each URL into a stream item and saves it, so tests and previews see imports land in the library.
public actor FakeMediaImporter: MediaImporter {
    public private(set) var importedURLs: [URL] = []
    private let library: any LibraryRepository
    private let openableBookmarks: Set<Data>?

    /// With `openableBookmarks`, only those bookmarks open; without, every one does.
    public init(library: any LibraryRepository, openableBookmarks: Set<Data>? = nil) {
        self.library = library
        self.openableBookmarks = openableBookmarks
    }

    public func canOpen(_ bookmark: Data) async -> Bool {
        openableBookmarks?.contains(bookmark) ?? true
    }

    public func importMedia(at urls: [URL]) async throws -> [MediaItem] {
        importedURLs += urls
        var imported: [MediaItem] = []
        for url in urls {
            let item = MediaItem(title: url.deletingPathExtension().lastPathComponent, source: .stream(url))
            try await library.save(item)
            imported.append(item)
        }
        return imported
    }
}
