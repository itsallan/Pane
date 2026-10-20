import Domain
import SwiftUI

struct WatchedToggleButton: View {
    let entry: LibraryEntry
    let model: LibraryModel

    var body: some View {
        if entry.isWatched {
            Button("Mark as Unwatched", systemImage: "eye.slash", action: markUnwatched)
        } else {
            Button("Mark as Watched", systemImage: "checkmark.circle", action: markWatched)
        }
    }

    private func markWatched() {
        Task { await model.markWatched(entry) }
    }

    private func markUnwatched() {
        Task { await model.markUnwatched(entry) }
    }
}
