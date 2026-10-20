import DesignSystem
import SwiftUI

struct FolderSection: View {
    let model: LibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("Folders")
            ForEach(model.folders) { folder in
                FolderLink(folder: folder, model: model)
                    .frame(minHeight: Metrics.minimumHitTarget, alignment: .leading)
                    .padding(.horizontal, Metrics.edgeInset)
            }
        }
    }
}
