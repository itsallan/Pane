import SwiftUI

struct LibraryToolbar: ToolbarContent {
    @Bindable var model: LibraryModel
    let onImport: (ImportKind) -> Void

    var body: some ToolbarContent {
        if !model.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Menu("Sort and Filter", systemImage: "line.3.horizontal.decrease") {
                    if model.canSort {
                        Picker("Sort By", selection: $model.sortOrder) {
                            ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                                Text(order.label)
                            }
                        }
                    }
                    Picker("Show", selection: $model.filter) {
                        ForEach(LibraryFilter.allCases, id: \.self) { filter in
                            Text(filter.label)
                        }
                    }
                }
            }
        }
        if model.canImport {
            ToolbarItem(placement: .primaryAction) {
                Menu("Import", systemImage: "plus") {
                    Button("Import Files…", systemImage: "doc.badge.plus", action: importFiles)
                    Button("Import Folder…", systemImage: "folder.badge.plus", action: importFolder)
                }
            }
        }
    }

    private func importFiles() {
        onImport(.files)
    }

    private func importFolder() {
        onImport(.folder)
    }
}
