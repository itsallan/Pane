import DesignSystem
import Domain
import SwiftUI

/// One scrolling page for every width: Continue Watching up top, then folders, then a poster grid.
struct LibraryContent: View {
    let model: LibraryModel
    let showsFolders: Bool
    let onOpen: (MediaItem) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .subheadline) private var compactMinimum = Metrics.posterMinimumWidth
    @ScaledMetric(relativeTo: .subheadline) private var regularMinimum = Metrics.posterRegularMinimumWidth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                if !model.continueWatching.isEmpty, model.searchText.isEmpty {
                    ContinueWatchingSection(model: model, onOpen: onOpen)
                }
                if showsFolders, !model.folders.isEmpty, model.searchText.isEmpty {
                    FolderSection(model: model)
                }
                VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
                    if model.scope == .all {
                        SectionHeader("All Videos") { countLabel }
                    }
                    LazyVGrid(columns: columns, alignment: .leading, spacing: Metrics.sectionSpacing) {
                        ForEach(model.entries) { entry in
                            PosterCard(entry: entry, model: model, onOpen: onOpen)
                        }
                    }
                    .padding(.horizontal, Metrics.edgeInset)
                }
            }
            .padding(.vertical, Metrics.controlSpacing)
        }
    }

    // Scaled with Dynamic Type, so the largest sizes fall back to one column instead of truncating titles.
    private var columns: [GridItem] {
        let minimum = horizontalSizeClass == .regular ? regularMinimum : compactMinimum
        return [GridItem(.adaptive(minimum: minimum), spacing: Metrics.gridSpacing, alignment: .top)]
    }

    private var countLabel: Text {
        Text("^[\(model.entries.count) video](inflect: true)")
    }
}
