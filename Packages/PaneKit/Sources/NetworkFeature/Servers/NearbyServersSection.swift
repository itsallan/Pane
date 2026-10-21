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
                Label {
                    Text("Looking for servers…")
                        .foregroundStyle(.secondary)
                } icon: {
                    ProgressView()
                }
            }
        } header: {
            Text("Nearby")
        } footer: {
            Text("Pane finds SMB and UPnP servers on your network. Add SFTP servers, or SMB servers that don't show up, by hand.")
        }
    }
}
