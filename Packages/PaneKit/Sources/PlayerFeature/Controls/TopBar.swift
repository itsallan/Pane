import DesignSystem
import SwiftUI

struct TopBar: View {
    let title: String?
    let onDismiss: (() -> Void)?

    @Namespace private var glass

    var body: some View {
        GlassEffectContainer(spacing: Metrics.glassMergeSpacing) {
            HStack(spacing: Metrics.controlSpacing) {
                if let onDismiss {
                    TransportButton("Close", systemImage: "xmark", action: onDismiss)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .glassEffectID("close", in: glass)
                }
                if let title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.horizontal, Metrics.edgeInset)
                        .frame(minHeight: Metrics.minimumHitTarget)
                        .glassEffect(.regular, in: .capsule)
                        .glassEffectID("title", in: glass)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
