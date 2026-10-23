#if os(iOS)
import SettingsFeature
import SwiftUI

struct SettingsSheet: View {
    let model: SettingsModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsScreen(model: model)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", role: .confirm) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

/// Opens Settings from the Library tab on iPhone and the sidebar on iPad.
struct SettingsButton: ToolbarContent {
    let router: AppRouter

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape") {
                router.isShowingSettings = true
            }
        }
    }
}
#endif
