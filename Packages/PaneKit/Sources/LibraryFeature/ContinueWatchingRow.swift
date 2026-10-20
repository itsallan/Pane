import DesignSystem
import Domain
import SwiftUI

struct ContinueWatchingRow: View {
    let entries: [LibraryEntry]
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(entries) { entry in
                    ContinueWatchingCard(entry: entry, model: model, onOpen: onOpen)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, Metrics.edgeInset, for: .scrollContent)
    }
}
