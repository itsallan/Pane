#if os(macOS)
import SettingsFeature
import SwiftUI

/// The Settings window (Command-Comma), with its own model since it outlives any library window.
struct SettingsWindow: View {
    @State private var model: SettingsModel

    init(dependencies: AppDependencies) {
        _model = State(initialValue: SettingsModel(preferences: dependencies.preferences, launchStatus: dependencies.cloudSync))
    }

    var body: some View {
        SettingsScreen(model: model)
            .frame(width: 460)
            .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
