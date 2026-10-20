#if DEBUG
import Domain
import Foundation
import PlaybackTesting
import SwiftUI

private extension LibraryModel {
    static func preview(empty: Bool = false) -> LibraryModel {
        let now = Date.now
        let items = empty ? [] : [
            MediaItem(title: "Big Buck Bunny", source: .stream(URL(filePath: "/bbb.mkv")), duration: .seconds(596), dateAdded: now),
            MediaItem(title: "Sintel", source: .stream(URL(filePath: "/sintel.mkv")), duration: .seconds(888), dateAdded: now - 60),
            MediaItem(title: "Tears of Steel", source: .stream(URL(filePath: "/tos.mkv")), duration: .seconds(734), dateAdded: now - 120),
            MediaItem(title: "Elephants Dream", source: .stream(URL(filePath: "/ed.mkv")), duration: .seconds(654), dateAdded: now - 180),
        ]
        let library = InMemoryLibraryRepository(items: items, folders: [LibraryFolder(name: "Blender Open Movies")])
        let progress = InMemoryProgressRepository(
            progress: empty ? [:] : [items[1].id: PlaybackProgress(position: .seconds(400), duration: .seconds(888))],
            watched: empty ? [] : [items[2].id],
            lastPlayed: empty ? [:] : [items[1].id: now]
        )
        return LibraryModel(library: library, progress: progress, importer: FakeMediaImporter(library: library), thumbnails: FakeThumbnailProvider())
    }
}

#Preview("Library") {
    NavigationStack {
        LibraryScreen(model: .preview(), showsFolders: true) { _ in }
    }
}

#Preview("Empty") {
    NavigationStack {
        LibraryScreen(model: .preview(empty: true)) { _ in }
    }
}
#endif
