import Domain
import LibraryFeature
import SwiftUI

struct LibrarySidebar: View {
    @Bindable var router: AppRouter

    var body: some View {
        List(selection: $router.sidebarSelection) {
            Label("Library", systemImage: "film.stack")
                .tag(LibraryScope.all)
            Label("Recents", systemImage: "clock")
                .tag(LibraryScope.recents)
            if !router.folders.isEmpty {
                Section("Folders") {
                    ForEach(router.folders) { folder in
                        Label(folder.name, systemImage: "folder")
                            .tag(LibraryScope.folder(folder))
                            .contextMenu {
                                Button("Remove Folder", systemImage: "trash", role: .destructive) {
                                    remove(folder)
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Pane")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        #endif
    }

    private func remove(_ folder: LibraryFolder) {
        Task { await router.removeFolder(folder) }
    }
}
