import DesignSystem
import SwiftUI

struct FolderSection: View {
    let model: LibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
            SectionHeader("Folders")
            ScrollView(.horizontal) {
                HStack(spacing: Metrics.controlSpacing) {
                    ForEach(model.folders) { folder in
                        FolderLink(folder: folder, model: model)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Metrics.edgeInset, for: .scrollContent)
        }
    }
}
