import DesignSystem
import Domain
import SwiftUI

struct NearbyServersSection: View {
    let servers: [NetworkServer]

    var body: some View {
        Section {
            ForEach(servers) { server in
                NavigationLink(value: server.rootRoute) {
                    ServerRow(server: server)
                }
            }
            // Discovery never finishes, so an empty list always means it's still looking.
            if servers.isEmpty {
                HStack(spacing: Metrics.controlSpacing) {
                    ProgressView()
                    Text("Searching…")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Nearby")
        } footer: {
            Text("SMB and UPnP servers on this network show up here. Add SFTP servers by hand.")
        }
    }
}
