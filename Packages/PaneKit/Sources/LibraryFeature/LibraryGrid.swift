import DesignSystem
import Domain
import SwiftUI

struct LibraryGrid: View {
    let model: LibraryModel
    let showsFolders: Bool
    let onOpen: (MediaItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: Metrics.posterMinimumWidth), spacing: 16, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !model.continueWatching.isEmpty, model.searchText.isEmpty {
                    ContinueWatchingSection(model: model, onOpen: onOpen)
                }
                if showsFolders, !model.folders.isEmpty, model.searchText.isEmpty {
                    FolderSection(model: model)
                }
                VStack(alignment: .leading, spacing: 12) {
                    if model.scope == .all {
                        SectionHeader("All Videos")
                    }
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(model.entries) { entry in
                            PosterCard(entry: entry, model: model, onOpen: onOpen)
                        }
                    }
                    .padding(.horizontal, Metrics.edgeInset)
                }
            }
            .padding(.vertical)
        }
    }
}
