import DesignSystem
import Domain
import SwiftUI

struct ContinueWatchingSection: View {
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        // Read here rather than inside the layout closure, which Observation doesn't track.
        let isSingle = model.continueWatching.count == 1
        VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
            SectionHeader("Continue Watching")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Metrics.gridSpacing) {
                    ForEach(model.continueWatching) { entry in
                        ContinueWatchingCard(entry: entry, model: model, onOpen: onOpen)
                            .containerRelativeFrame(.horizontal) { length, _ in
                                cardWidth(in: length, isSingle: isSingle)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, Metrics.edgeInset, for: .scrollContent)
        }
    }

    // The next card peeks in to show the row scrolls; a lone card has nothing to hint at, so it takes the width.
    private func cardWidth(in length: CGFloat, isSingle: Bool) -> CGFloat {
        // The length already excludes the scroll view's content margins.
        let width = isSingle ? length : length * Metrics.heroWidthFraction
        return min(width, Metrics.heroMaximumWidth)
    }
}
