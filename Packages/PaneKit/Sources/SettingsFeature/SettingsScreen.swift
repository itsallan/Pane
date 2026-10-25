import SwiftUI

/// Preferences that outlive a single video. What you change mid-film lives in the player's options instead.
public struct SettingsScreen: View {
    @Bindable private var model: SettingsModel

    public init(model: SettingsModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            AppearanceSection()
            PlaybackSettingsSection(model: model)
            SubtitleSettingsSection(model: model)
            AudioSettingsSection(model: model)
            #if os(iOS)
            GestureSettingsSection(model: model)
            #endif
            SyncSettingsSection(model: model)
            AboutSection()
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await model.load() }
    }
}
