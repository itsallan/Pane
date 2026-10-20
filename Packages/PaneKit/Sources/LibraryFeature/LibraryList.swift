import DesignSystem
import Domain
import SwiftUI

struct LibraryList: View {
    let model: LibraryModel
    let showsFolders: Bool
    let onOpen: (MediaItem) -> Void

    var body: some View {
        List {
            if !model.continueWatching.isEmpty, model.searchText.isEmpty {
                Section("Continue Watching") {
                    ContinueWatchingRow(entries: model.continueWatching, model: model, onOpen: onOpen)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            if showsFolders, !model.folders.isEmpty, model.searchText.isEmpty {
                Section("Folders") {
                    ForEach(model.folders) { folder in
                        FolderLink(folder: folder, model: model)
                    }
                }
            }
            Section {
                ForEach(model.entries) { entry in
                    LibraryRow(entry: entry, model: model, onOpen: onOpen)
                }
            } header: {
                if model.scope == .all {
                    Text("All Videos")
                }
            }
        }
    }
}
