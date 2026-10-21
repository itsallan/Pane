import Domain
import Foundation
import PlaybackTesting
import Testing

struct AddToLibraryTests {
    @Test func savesANewSource() async throws {
        let library = InMemoryLibraryRepository()
        let source = MediaSource.stream(URL(string: "https://example.com/live.m3u8")!)

        let item = try await AddToLibrary(library: library)(source, title: "live.m3u8")

        #expect(item.source == source)
        #expect(try await library.item(withID: item.id) == item)
    }

    @Test func returnsTheExistingItemForAKnownSource() async throws {
        let server = UUID()
        let existing = MediaItem(title: "Sintel", source: .networkShare(server: server, path: "/Movies/Sintel.mkv"))
        let library = InMemoryLibraryRepository(items: [existing])

        let item = try await AddToLibrary(library: library)(.networkShare(server: server, path: "/Movies/Sintel.mkv"), title: "Other")

        #expect(item == existing)
        #expect(try await library.items().count == 1)
    }
}
