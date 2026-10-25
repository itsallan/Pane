import DesignSystem
import Domain
import SwiftUI

struct FolderLink: View {
    let folder: LibraryFolder
    let model: LibraryModel

    var body: some View {
        NavigationLink(value: LibraryScope.folder(folder)) {
            Label(folder.name, systemImage: "folder.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, Metrics.edgeInset)
                .frame(minHeight: Metrics.minimumHitTarget)
                .background(.fill.tertiary, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove Folder", systemImage: "trash", role: .destructive, action: remove)
        }
    }

    private func remove() {
        Task { await model.removeFolder(folder) }
    }
}
