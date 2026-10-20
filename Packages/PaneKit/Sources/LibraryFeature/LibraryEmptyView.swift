import SwiftUI

struct LibraryEmptyView: View {
    let scope: LibraryScope
    let onImport: (ImportKind) -> Void

    var body: some View {
        switch scope {
        case .all:
            ContentUnavailableView {
                Label("No Videos Yet", systemImage: "film.stack")
            } description: {
                Text("Add videos from Files, or drop them here. Pane plays them where they are, without copying.")
            } actions: {
                Button("Import Files", systemImage: "doc.badge.plus", action: importFiles)
                    .buttonStyle(.glassProminent)
                Button("Import Folder", systemImage: "folder.badge.plus", action: importFolder)
                    .buttonStyle(.glass)
            }
        case .recents:
            ContentUnavailableView(
                "Nothing Played Yet",
                systemImage: "clock",
                description: Text("Videos you watch show up here.")
            )
        case .folder:
            ContentUnavailableView(
                "No Videos in This Folder",
                systemImage: "folder",
                description: Text("Pane didn't find anything it can play in this folder.")
            )
        }
    }

    private func importFiles() {
        onImport(.files)
    }

    private func importFolder() {
        onImport(.folder)
    }
}
