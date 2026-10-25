import SwiftUI

struct SyncSettingsSection: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Section {
            Toggle(isOn: $model.syncsWithCloud) {
                Label("Sync with iCloud", systemImage: "icloud")
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text(footnote)
        }
    }

    private var footnote: LocalizedStringKey {
        switch model.syncNote {
        case .invitation:
            "Keep your library and where you stopped watching the same on your iPhone, iPad and Mac. Videos imported from files stay on the device that has them, and server passwords never leave this device."
        case .active:
            "Your library and progress sync with your devices signed in to the same Apple Account. Server passwords stay on this device."
        case .startsNextLaunch:
            "Sync starts the next time you open Pane."
        case .stopsNextLaunch:
            "Sync stops the next time you open Pane. What’s already in iCloud stays there."
        case .noAccount:
            #if os(macOS)
            "Sign in to iCloud in System Settings to sync."
            #else
            "Sign in to iCloud in Settings to sync."
            #endif
        case .unavailable:
            "This copy of Pane can’t reach iCloud, so everything stays on this device."
        }
    }
}
