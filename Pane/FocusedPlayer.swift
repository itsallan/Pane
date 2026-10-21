#if os(macOS)
import PlayerFeature
import SwiftUI

/// The player in the key window, which the Playback menu and its shortcuts act on.
struct FocusedPlayer: Equatable {
    let session: PlayerSession
    let isFullScreen: Bool

    var model: PlayerModel { session.model }

    // The drawable is the one view this window is sure to own, so its window is the one to toggle.
    func toggleFullScreen() {
        session.drawable.window?.toggleFullScreen(nil)
    }

    static func == (lhs: FocusedPlayer, rhs: FocusedPlayer) -> Bool {
        lhs.session === rhs.session && lhs.isFullScreen == rhs.isFullScreen
    }
}

extension FocusedValues {
    @Entry var player: FocusedPlayer?
}
#endif
