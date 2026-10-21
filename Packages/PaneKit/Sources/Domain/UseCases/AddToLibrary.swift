/// Streams and network files join the library when they're opened, so they resume, show in Recents
/// and open in their own window on the Mac. Opening the same source again returns the existing item.
public struct AddToLibrary: Sendable {
    private let library: any LibraryRepository

    public init(library: any LibraryRepository) {
        self.library = library
    }

    public func callAsFunction(_ source: MediaSource, title: String) async throws -> MediaItem {
        if let existing = try await library.items().first(where: { $0.source == source }) {
            return existing
        }
        let item = MediaItem(title: title, source: source)
        try await library.save(item)
        return item
    }
}
