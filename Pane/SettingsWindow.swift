#if os(macOS)
import SettingsFeature
import SwiftUI

/// The Settings window (Command-Comma), with its own model since it outlives any library window.
struct SettingsWindow: View {
    @State private var model: SettingsModel

    init(dependencies: AppDependencies) {
        _model = State(initialValue: SettingsModel(
            preferences: dependencies.preferences,
            launchStatus: dependencies.cloudSync,
            onSubtitleStyleChange: { [dependencies] in dependencies.subtitleStyleDidChange($0) }
        ))
    }

    var body: some View {
        // A stack so the language lists can push; the window is tall enough for the whole form to scroll.
        NavigationStack {
            SettingsScreen(model: model)
        }
        .frame(width: 480, height: 640)
    }
}
#endif
