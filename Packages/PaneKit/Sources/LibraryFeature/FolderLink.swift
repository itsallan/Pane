import Domain
import SwiftUI

struct FolderLink: View {
    let folder: LibraryFolder
    let model: LibraryModel

    var body: some View {
        NavigationLink(value: LibraryScope.folder(folder)) {
            Label(folder.name, systemImage: "folder")
        }
        .contextMenu {
            Button("Remove Folder", systemImage: "trash", role: .destructive, action: remove)
        }
    }

    private func remove() {
        Task { await model.removeFolder(folder) }
    }
}
