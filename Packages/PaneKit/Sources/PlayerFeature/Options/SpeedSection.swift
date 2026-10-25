import DesignSystem
import SwiftUI

struct SpeedSection: View {
    @Bindable var model: PlayerModel

    var body: some View {
        Section("Speed") {
            HStack {
                Slider(value: $model.speed, in: PlayerModel.rates) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text(PlayerModel.rates.lowerBound.rateLabel)
                } maximumValueLabel: {
                    Text(PlayerModel.rates.upperBound.rateLabel)
                }
                .accessibilityValue(model.speed.rateLabel)
                Text(model.speed.rateLabel)
                    .font(.indicatorValue)
                    .frame(minWidth: Metrics.valueLabelMinWidth, alignment: .trailing)
            }
            Button("Normal Speed", systemImage: "gauge.with.dots.needle.50percent", action: resetSpeed)
                .disabled(model.speed == 1)
        }
    }

    private func resetSpeed() {
        model.speed = 1
    }
}
