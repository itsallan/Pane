import Domain
import Foundation

/// Turns each URL into a stream item and saves it, so tests and previews see imports land in the library.
public actor FakeMediaImporter: MediaImporter {
    public private(set) var importedURLs: [URL] = []
    private let library: any LibraryRepository

    public init(library: any LibraryRepository) {
        self.library = library
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
