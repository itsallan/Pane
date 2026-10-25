import DesignSystem
import Domain
import SwiftUI

struct PlaybackSettingsSection: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Section {
            Picker("Default Speed", selection: $model.playback.defaultRate) {
                ForEach(SettingsModel.defaultRates, id: \.self) { rate in
                    Text(rate.rateLabel).tag(rate)
                }
            }
            Picker("Skip Interval", selection: $model.playback.skipInterval) {
                ForEach(PlaybackPreferences.skipIntervals, id: \.self) { interval in
                    Text(interval, format: .units(allowed: [.seconds], width: .abbreviated)).tag(interval)
                }
            }
            Picker("Resume Where You Left Off", selection: $model.playback.resume) {
                ForEach(ResumeBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.label).tag(behavior)
                }
            }
            Toggle("Hardware Decoding", isOn: $model.playback.usesHardwareDecoding)
        } header: {
            Text("Playback")
        } footer: {
            Text("Ask starts from the beginning and offers to jump back for a few seconds. Turn off hardware decoding only if a video shows corrupted frames; it uses more battery. Changes apply to the next video you open.")
        }
    }
}
