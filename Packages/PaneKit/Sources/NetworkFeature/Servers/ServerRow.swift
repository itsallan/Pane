import DesignSystem
import Domain
import SwiftUI

struct ServerRow: View {
    let server: NetworkServer

    var body: some View {
        Label {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.displayName)
                    Text("\(Text(server.kindLabel)) · \(server.host)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                if server.requiresCredentials {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Needs a password")
                }
            }
        } icon: {
            IconTile(systemImage: server.symbolName, tint: server.tint)
        }
    }
}
