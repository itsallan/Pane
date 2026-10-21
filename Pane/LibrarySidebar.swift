import Domain
import LibraryFeature
import SwiftUI

struct LibrarySidebar: View {
    @Bindable var router: AppRouter

    var body: some View {
        List(selection: $router.sidebarSelection) {
            Label("Library", systemImage: "film.stack")
                .tag(AppRouter.SidebarItem.library(.all))
            Label("Recents", systemImage: "clock")
                .tag(AppRouter.SidebarItem.library(.recents))
            Label("Network", systemImage: "network")
                .tag(AppRouter.SidebarItem.network)
            if !router.folders.isEmpty {
                Section("Folders") {
                    ForEach(router.folders) { folder in
                        Label(folder.name, systemImage: "folder")
                            .tag(AppRouter.SidebarItem.library(.folder(folder)))
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
