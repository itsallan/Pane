import DesignSystem
import SwiftUI

struct VolumeSection: View {
    @Bindable var model: PlayerModel

    var body: some View {
        Section {
            HStack {
                Slider(value: $model.volumeLevel, in: 0...model.maximumVolume) {
                    Text("Volume")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                } onEditingChanged: { isEditing in
                    adjustingChanged(isEditing)
                }
                .tint(isBoosted ? .levelBoost : nil)
                .accessibilityValue(percentage)
                Text(percentage)
                    .font(.indicatorValue)
                    .foregroundStyle(isBoosted ? AnyShapeStyle(Color.levelBoost) : AnyShapeStyle(.primary))
                    .frame(minWidth: Metrics.valueLabelMinWidth, alignment: .trailing)
            }
        } header: {
            Text("Volume")
        } footer: {
            if isBoosted {
                Text("Past 100% can distort loud scenes.")
            } else if !model.allowsVolumeBoost {
                Text("Turn on volume boost in Settings to go past 100%.")
            }
        }
    }

    private var isBoosted: Bool { model.volume > 1 }

    private var percentage: String {
        model.volume.formatted(.percent.precision(.fractionLength(0)))
    }

    private func adjustingChanged(_ isEditing: Bool) {
        isEditing ? model.beginVolumeAdjustment() : model.endVolumeAdjustment()
    }
}
