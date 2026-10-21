import Domain
import SwiftUI

@main
struct PaneApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        #if os(macOS)
        libraryWindow
            .commands {
                PlaybackCommands(dependencies: dependencies)
            }

        // People play several files side by side, so each player is its own window that owns its session.
        WindowGroup("Player", id: PlayerWindow.id, for: MediaItem.ID.self) { $itemID in
            PlayerWindow(itemID: itemID, dependencies: dependencies)
        }
        .defaultSize(width: 960, height: 540)

        Window("Open URL", id: OpenURLWindow.id) {
            OpenURLWindow(dependencies: dependencies)
        }
        .defaultSize(width: 480, height: 360)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
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
