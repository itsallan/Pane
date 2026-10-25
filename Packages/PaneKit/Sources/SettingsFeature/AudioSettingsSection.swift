import Domain
import SwiftUI

struct AudioSettingsSection: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Section {
            NavigationLink {
                LanguageListScreen(title: "Audio Languages", languages: $model.tracks.audioLanguages)
            } label: {
                LabeledContent("Preferred Languages", value: model.tracks.audioLanguages.summary)
            }
            Toggle("Volume Boost", isOn: $model.playback.allowsVolumeBoost)
        } header: {
            Text("Audio")
        } footer: {
            Text("Volume boost lets the player go up to 200% for quiet recordings. Loud scenes can distort past 100%.")
        }
    }
}
