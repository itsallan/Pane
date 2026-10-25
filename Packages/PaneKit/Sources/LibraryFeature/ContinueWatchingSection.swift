import DesignSystem
import Domain
import SwiftUI

struct ContinueWatchingSection: View {
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
            SectionHeader("Continue Watching")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Metrics.gridSpacing) {
                    ForEach(model.continueWatching) { entry in
                        ContinueWatchingCard(entry: entry, model: model, onOpen: onOpen)
                            .containerRelativeFrame(.horizontal) { length, _ in
                                cardWidth(in: length)
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
    private func cardWidth(in length: CGFloat) -> CGFloat {
        let fraction = model.continueWatching.count > 1 ? Metrics.heroWidthFraction : 1
        return min(length * fraction, Metrics.heroMaximumWidth)
    }
}
