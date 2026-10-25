import DesignSystem
import SwiftUI

/// Tiles in even rows: two on an iPhone, more as the width allows, one at the largest text sizes.
struct ServerGrid<Content: View>: View {
    @ViewBuilder let content: Content

    @ScaledMetric(relativeTo: .subheadline) private var minimum = Metrics.tileMinimumWidth

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: Metrics.gridSpacing)], spacing: Metrics.gridSpacing) {
            content
        }
        .padding(.horizontal, Metrics.edgeInset)
    }
}
