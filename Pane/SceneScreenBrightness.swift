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

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
    }
}
#endif
