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
                LabeledContent("Preferred Languages", value: summary(of: model.tracks.subtitleLanguages))
            }
        } header: {
            Text("Subtitles")
        } footer: {
            Text("Style applies from the next video you open, because VLC reads it when a player starts. Forced subtitles for foreign dialogue still show when subtitles are off.")
        }
    }
}

/// A frame-shaped stand-in for a video, with the sample line drawn the way libvlc will draw it.
private struct SubtitleStyleSample: View {
    let style: SubtitleStyle

    var body: some View {
        LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay { SubtitleStylePreview(style: style) }
            .clipShape(.rect(cornerRadius: Metrics.posterCornerRadius))
            .listRowInsets(EdgeInsets(
                top: Metrics.controlSpacing,
                leading: Metrics.controlSpacing,
                bottom: Metrics.controlSpacing,
                trailing: Metrics.controlSpacing
            ))
            .accessibilityHidden(true)
            .animation(.quickFade, value: style)
    }
}

func summary(of languages: [Locale.Language]) -> String {
    guard let first = languages.first else { return String(localized: "None") }
    guard languages.count > 1 else { return first.displayName }
    return String(localized: "\(first.displayName) +\(languages.count - 1)")
}
