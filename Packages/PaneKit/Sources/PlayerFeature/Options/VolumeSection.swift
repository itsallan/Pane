import DesignSystem
import SwiftUI

struct VolumeSection: View {
    @Bindable var model: PlayerModel

    var body: some View {
        OptionsSection(title: "Volume") {
            HStack {
                Slider(value: $model.volumeLevel, in: 0...2, step: 0.05) {
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
                    .frame(minWidth: 52, alignment: .trailing)
            }
            if isBoosted {
                Label("Boosted past 100% can distort loud scenes.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
