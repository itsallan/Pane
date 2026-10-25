import DesignSystem
import Domain
import SwiftUI

struct SavedServersSection: View {
    let model: NetworkModel
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
            SectionHeader("Saved")
            ServerGrid {
                ForEach(model.savedServers) { server in
                    ServerTile(server: server)
                        .contextMenu {
                            Button("Remove Server", systemImage: "trash", role: .destructive) {
                                remove(server)
                            }
                        }
                }
                AddServerTile(action: onAdd)
            }
        }
    }

    private func remove(_ server: NetworkServer) {
        Task { await model.remove(server) }
    }
}
