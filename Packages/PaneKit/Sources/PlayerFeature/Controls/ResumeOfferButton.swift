import DesignSystem
import SwiftUI

/// Shown for a few seconds when the resume preference is Ask; ignoring it keeps playing from the start.
struct ResumeOfferButton: View {
    let position: Duration
    let onResume: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onResume) {
                Label("Resume from \(position.timecode)", systemImage: "arrow.uturn.forward")
                    .font(.subheadline.weight(.semibold))
                    .padding(.leading, Metrics.edgeInset)
                    .padding(.trailing, Metrics.controlSpacing)
                    .frame(minHeight: Metrics.minimumHitTarget)
                    .contentShape(.capsule)
            }
            .buttonStyle(.transport)
            TransportButton("Start from the Beginning", systemImage: "xmark", symbolFont: .footnote.weight(.bold), action: onDismiss)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .contain)
    }
}
