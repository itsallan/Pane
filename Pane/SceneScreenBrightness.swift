#if os(iOS)
import PlayerFeature
import UIKit

/// Reads the screen through the foreground scene, since `UIScreen.main` is deprecated and there's one display per iPhone or iPad scene anyway.
@MainActor
final class SceneScreenBrightness: ScreenBrightness {
    var level: Double {
        get { screen.map { Double($0.brightness) } ?? 0.5 }
        set { screen?.brightness = CGFloat(newValue) }
    }

    // Restoring happens while the scene is resigning active or already backgrounded, so fall back to any window scene.
    private var screen: UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.screen
    }
}
#endif
