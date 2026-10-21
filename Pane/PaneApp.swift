import Domain
import SwiftUI

@main
struct PaneApp: App {
    @State private var dependencies = AppDependencies()
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        libraryWindow
            .environment(appDelegate.openedFiles)
            // Without this, every file opened from Finder or the Dock would open another library window.
            .handlesExternalEvents(matching: ["*"])
            .commands {
                PlaybackCommands(dependencies: dependencies)
            }

        // People play several files side by side, so each player is its own window that owns its session.
        WindowGroup("Player", id: PlayerWindow.id, for: MediaItem.ID.self) { $itemID in
            PlayerWindow(itemID: itemID, dependencies: dependencies)
        }
        .defaultSize(width: 960, height: 540)
        // Restored player windows come back without their item ID, as empty black windows.
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: [])

        Window("Open URL", id: OpenURLWindow.id) {
            OpenURLWindow(dependencies: dependencies)
        }
        .defaultSize(width: 480, height: 360)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: [])
        #else
        libraryWindow
        #endif
    }

    private var libraryWindow: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
