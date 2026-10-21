import SwiftUI

struct SpeedSection: View {
    @Bindable var model: PlayerModel

    private static let rates = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        OptionsSection(title: "Speed") {
            Picker("Speed", selection: $model.speed) {
                ForEach(Self.rates, id: \.self) { Text($0.rateLabel).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
