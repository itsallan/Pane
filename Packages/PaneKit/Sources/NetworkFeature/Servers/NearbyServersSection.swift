import DesignSystem
import Domain
import SwiftUI

struct NearbyServersSection: View {
    let servers: [NetworkServer]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
            SectionHeader("Nearby") {
                // Discovery never finishes, so the spinner stays as a sign it's still listening.
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Looking for servers")
            }
            if servers.isEmpty {
                SearchingCard()
                    .padding(.horizontal, Metrics.edgeInset)
            } else {
                ServerGrid {
                    ForEach(servers) { server in
                        ServerTile(server: server)
                    }
                }
            }
            Text("Pane finds SMB and UPnP servers on your network. Add SFTP servers, or SMB servers that don't show up, by hand.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Metrics.edgeInset)
        }
    }
}
