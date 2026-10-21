import Domain
import SwiftUI

struct ShareListing: View {
    let model: ShareBrowserModel
    let onOpen: (NetworkServer, NetworkEntry) -> Void

    var body: some View {
        List {
            ForEach(model.folders) { folder in
                NavigationLink(value: NetworkRoute.folder(model.server, path: folder.path, name: folder.name)) {
                    EntryRow(entry: folder)
                }
            }
            ForEach(model.files) { file in
                Button {
                    open(file)
                } label: {
                    EntryRow(entry: file)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!file.isPlayable)
            }
        }
        .refreshable {
            await model.load()
        }
    }

    private func open(_ file: NetworkEntry) {
        onOpen(model.server, file)
    }
}
