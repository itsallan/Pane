#if DEBUG
import Domain
import Foundation
import PlaybackTesting
import SwiftUI

private let customized = InMemoryPreferencesRepository(
    preferences: TrackPreferences(
        audioLanguages: [Locale.Language(identifier: "ja"), Locale.Language(identifier: "en")],
        subtitleLanguages: [Locale.Language(identifier: "en")],
        subtitleMode: .always
    ),
    playback: PlaybackPreferences(defaultRate: 1.25, skipInterval: .seconds(15), resume: .ask),
    style: SubtitleStyle(size: .large, background: .translucent, position: .raised)
)

#Preview("Settings") {
    NavigationStack {
        SettingsScreen(model: SettingsModel(preferences: customized, launchStatus: .on))
    }
}

#Preview("Settings, dark") {
    NavigationStack {
        SettingsScreen(model: SettingsModel(preferences: customized, launchStatus: .on))
    }
    .preferredColorScheme(.dark)
}

#Preview("Sync off") {
    NavigationStack {
        SettingsScreen(model: SettingsModel(preferences: InMemoryPreferencesRepository(), launchStatus: .off))
    }
}

#Preview("Sync unavailable") {
    NavigationStack {
        SettingsScreen(model: SettingsModel(preferences: InMemoryPreferencesRepository(syncsWithCloud: true), launchStatus: .unavailable))
    }
}
#endif
