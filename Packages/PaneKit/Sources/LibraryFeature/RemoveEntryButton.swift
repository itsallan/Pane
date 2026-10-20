import Domain
import SwiftUI

struct RemoveEntryButton: View {
    let entry: LibraryEntry
    let model: LibraryModel

    var body: some View {
        // Removing only forgets the bookmark; the file itself stays where it is, so no confirmation.
        Button("Remove from Library", systemImage: "trash", role: .destructive, action: remove)
    }

    private func remove() {
        Task { await model.remove(entry) }
    }
}
