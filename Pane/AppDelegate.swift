#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let openedFiles = OpenedFiles()

    // SwiftUI gives only the first of several opened files to onOpenURL and forwards the rest here.
    func application(_ application: NSApplication, open urls: [URL]) {
        openedFiles.add(urls.filter(\.isFileURL))
    }
}
#else
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        SceneOrientation.supported
    }
}
#endif
