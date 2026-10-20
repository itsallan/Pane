import Domain
import SwiftUI

struct EntryActions: View {
    let entry: LibraryEntry
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        Button(entry.resumePosition == nil ? "Play" : "Resume", systemImage: "play.fill", action: open)
        WatchedToggleButton(entry: entry, model: model)
        Divider()
        RemoveEntryButton(entry: entry, model: model)
    }

    private func open() {
        onOpen(entry.item)
    }
}
