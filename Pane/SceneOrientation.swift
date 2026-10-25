#if os(iOS)
import PlayerFeature
import UIKit

/// Locks the interface to one orientation for the player's rotate button.
@MainActor
final class SceneOrientation: ScreenOrientation {
    // Read by the app delegate whenever UIKit asks which orientations it may use.
    static private(set) var supported = UIInterfaceOrientationMask.allButUpsideDown

    func rotate() {
        let isLandscape = scene?.effectiveGeometry.interfaceOrientation.isLandscape ?? false
        apply(isLandscape ? .portrait : .landscapeRight)
    }

    func unlock() {
        apply(.allButUpsideDown)
    }

    // Narrowing the mask is what makes the turn stick; the geometry request alone springs back on the next device motion.
    private func apply(_ mask: UIInterfaceOrientationMask) {
        Self.supported = mask
        guard let scene else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }

    private var scene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
#endif
