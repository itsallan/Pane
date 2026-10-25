import DesignSystem
import Domain
import SwiftUI

struct ServerTile: View {
    let server: NetworkServer

    @ScaledMetric(relativeTo: .subheadline) private var minimumHeight = Metrics.tileMinimumHeight - Metrics.tilePadding * 2

    var body: some View {
        NavigationLink(value: server.rootRoute) {
            VStack(alignment: .leading, spacing: Metrics.controlSpacing + 4) {
                HStack(alignment: .top) {
                    IconTile(systemImage: server.symbolName, tint: server.tint)
                    Spacer(minLength: 0)
                    if server.requiresCredentials {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Needs a password")
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text("\(Text(server.kindLabel)) · \(server.host)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
            .padding(Metrics.tilePadding)
            .background(.fill.quaternary, in: .rect(cornerRadius: Metrics.tileCornerRadius))
            .contentShape(.rect(cornerRadius: Metrics.tileCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
