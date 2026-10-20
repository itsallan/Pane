import Domain
import SwiftUI

struct ContinueWatchingSection: View {
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Continue Watching")
            ContinueWatchingRow(entries: model.continueWatching, model: model, onOpen: onOpen)
        }
    }
}
