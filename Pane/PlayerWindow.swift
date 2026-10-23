#if os(macOS)
import DesignSystem
import Domain
import Playback
import PlayerFeature
import SwiftUI

struct PlayerWindow: View {
    static let id = "player"
    private static let sessionSpacing = Duration.milliseconds(500)
    private static var nextSessionStart = ContinuousClock.now

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
                .userActivity(PlaybackActivity.type, isActive: session.model.failure == nil) { activity in
                    PlaybackActivity.update(activity, for: session)
                }
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
        guard session == nil else { return }
        guard let itemID, let item = try? await dependencies.library.item(withID: itemID) else {
            // Nothing to play, for instance an item removed from the library while its window was closed.
            dismiss()
            return
        }
        await waitForTurn()
        guard session == nil, !Task.isCancelled else { return }
        let session = PlayerSession(item: item, dependencies: dependencies)
        self.session = session
        dependencies.playerDidOpen(session)
    }

    // VLCKit 4.0.0-a25 can abort in vout_display_opengl_Prepare when players set up video at the same moment,
    // which happens when Finder opens several files at once, so sessions start at least half a second apart.
    private func waitForTurn() async {
        let start = max(.now, Self.nextSessionStart)
        Self.nextSessionStart = start + Self.sessionSpacing
        try? await Task.sleep(until: start)
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
        Task { await dependencies.playerDidClose(session) }
    }
}
#endif
