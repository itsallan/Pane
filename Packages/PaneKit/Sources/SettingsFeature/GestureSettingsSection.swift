#if os(iOS)
import Domain
import SwiftUI

struct GestureSettingsSection: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Section {
            Toggle("Swipe for Brightness and Volume", isOn: $model.playback.gestures.adjustsBrightnessAndVolume)
            Toggle("Double-Tap to Skip", isOn: $model.playback.gestures.doubleTapSeeks)
            Toggle("Hold for 2× Speed", isOn: $model.playback.gestures.longPressSpeedsUp)
        } header: {
            Text("Gestures")
        } footer: {
            Text("Swipe up or down on the left half for brightness and the right half for volume. Turning off double-tap makes a single tap show the controls a little sooner.")
        }
    }
}
#endif
