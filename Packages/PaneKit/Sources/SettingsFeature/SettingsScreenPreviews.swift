#if DEBUG
import Domain
import PlaybackTesting
import SwiftUI

#Preview("Off") {
    NavigationStack {
        SettingsScreen(model: SettingsModel(preferences: InMemoryPreferencesRepository(), launchStatus: .off))
    }
}

#Preview("Unavailable") {
    NavigationStack {
        SettingsScreen(model: SettingsModel(preferences: InMemoryPreferencesRepository(syncsWithCloud: true), launchStatus: .unavailable))
    }
}
#endif
