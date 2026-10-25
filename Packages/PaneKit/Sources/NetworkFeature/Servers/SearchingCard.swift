import DesignSystem
import SwiftUI

struct SearchingCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Metrics.edgeInset) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Looking for servers…")
                    .font(.subheadline.weight(.semibold))
                Text("Shared folders and media servers on this network appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.tilePadding)
        .background(.fill.quaternary, in: .rect(cornerRadius: Metrics.tileCornerRadius))
        .accessibilityElement(children: .combine)
    }
}
