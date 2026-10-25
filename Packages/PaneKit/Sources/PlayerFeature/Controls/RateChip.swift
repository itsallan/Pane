import DesignSystem
import SwiftUI

struct RateChip: View {
    let rate: Double
    let isCurrent: Bool
    let onChoose: (Double) -> Void

    var body: some View {
        Button(action: choose) {
            Text(rate.rateLabel)
                .font(.rateLabel)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, Metrics.controlSpacing)
                .frame(minHeight: Metrics.minimumHitTarget)
                .background(isCurrent ? Color.glassSelection : .clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.transport)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func choose() {
        onChoose(rate)
    }
}
