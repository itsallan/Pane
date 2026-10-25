import DesignSystem
import SwiftUI

/// The row of rates that grows out of the rail's speed button.
struct SpeedPicker: View {
    let current: Double
    let onChoose: (Double) -> Void

    static let rates = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        HStack(spacing: Metrics.railSpacing) {
            ForEach(Self.rates, id: \.self) { rate in
                RateChip(rate: rate, isCurrent: abs(current - rate) < 0.01, onChoose: onChoose)
            }
        }
        .padding(Metrics.railSpacing)
    }
}
