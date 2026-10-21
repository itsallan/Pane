#if os(macOS)
import DesignSystem
import Domain
import Playback
import PlayerFeature
import SwiftUI

struct PlayerWindow: View {
    static let id = "player"

    let itemID: MediaItem.ID?
    let dependencies: AppDependencies

    @State private var session: PlayerSession?
    @State private var isFullScreen = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.mediaBackground
            if let session {
                PlayerScreen(model: session.model, onDismiss: close) {
                    VideoSurface(session.drawable)
                }
                .pointerVisibility(isFullScreen && !session.model.areControlsVisible ? .hidden : .automatic)
            }
        }
        .frame(minWidth: 480, minHeight: 270)
        .navigationTitle(session?.model.title ?? "")
        .focusedSceneValue(\.player, focusedPlayer)
        .task {
            await openSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { notification in
            fullScreenDidChange(notification, to: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
            fullScreenDidChange(notification, to: false)
        }
        // Closing the window any way at all (the close button, Command-W) ends playback and saves progress.
        .onDisappear(perform: closeSession)
    }

    private var focusedPlayer: FocusedPlayer? {
        session.map { FocusedPlayer(session: $0, isFullScreen: isFullScreen) }
    }

    private func openSession() async {
        guard session == nil, let itemID, let item = try? await dependencies.library.item(withID: itemID) else { return }
        session = PlayerSession(item: item, dependencies: dependencies)
    }

    // The drawable is the one view this window is sure to own, so its window is the one to watch.
    private func fullScreenDidChange(_ notification: Notification, to isFullScreen: Bool) {
        guard let window = session?.drawable.window, notification.object as? NSWindow === window else { return }
        self.isFullScreen = isFullScreen
    }

    private func close() {
        dismiss()
    }

    private func closeSession() {
        guard let session else { return }
        self.session = nil
        Task {
            await session.close()
            dependencies.libraryDidChange()
        }
    }
}
#endif
