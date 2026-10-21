import DesignSystem
import SwiftUI

struct SpeedSection: View {
    @Bindable var model: PlayerModel

    var body: some View {
        OptionsSection(title: "Speed") {
            HStack {
                Slider(value: $model.speed, in: PlayerModel.rates, step: 0.05) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text(PlayerModel.rates.lowerBound.rateLabel)
                } maximumValueLabel: {
                    Text(PlayerModel.rates.upperBound.rateLabel)
                }
                .accessibilityValue(model.speed.rateLabel)
                Text(model.speed.rateLabel)
                    .font(.indicatorValue)
                    .frame(minWidth: 52, alignment: .trailing)
            }
            Button("Normal Speed", action: resetSpeed)
                .disabled(model.speed == 1)
        }
    }

    private func resetSpeed() {
        model.speed = 1
    }
}
