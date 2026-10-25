import DesignSystem
import Domain
import SwiftUI

struct SubtitleSettingsSection: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Section {
            SubtitleStyleSample(style: model.subtitleStyle)
            Picker("Size", selection: $model.subtitleStyle.size) {
                ForEach(SubtitleStyle.Size.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Picker("Background", selection: $model.subtitleStyle.background) {
                ForEach(SubtitleStyle.Background.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Picker("Position", selection: $model.subtitleStyle.position) {
                ForEach(SubtitleStyle.Position.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Picker("Show Subtitles", selection: $model.tracks.subtitleMode) {
                ForEach(TrackPreferences.SubtitleMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            NavigationLink {
                LanguageListScreen(title: "Subtitle Languages", languages: $model.tracks.subtitleLanguages)
            } label: {
                LabeledContent("Preferred Languages", value: model.tracks.subtitleLanguages.summary)
            }
        } header: {
            Text("Subtitles")
        } footer: {
            Text("Style applies from the next video you open, because VLC reads it when a player starts. Forced subtitles for foreign dialogue still show when subtitles are off.")
        }
    }
}
