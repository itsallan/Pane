import Domain
import Foundation
import PlayerFeature

/// The Handoff activity a player advertises: what's playing and where, as a `PlaybackHandoff`.
enum PlaybackActivity {
    static let type = "io.pane.player.playing"
    private static let handoffKey = "handoff"

    static func update(_ activity: NSUserActivity, for session: PlayerSession) {
        let progress = PlaybackProgress(position: session.model.position, duration: session.model.duration)
        guard let handoff = PlaybackHandoff(item: session.item, server: session.server, progress: progress),
              let data = try? JSONEncoder().encode(handoff)
        else { return }
        activity.title = session.item.title
        activity.isEligibleForHandoff = true
        // A dictionary of plain values would have to be versioned by hand; one encoded blob keeps old and new builds compatible.
        activity.addUserInfoEntries(from: [handoffKey: data])
    }

    static func handoff(from activity: NSUserActivity) -> PlaybackHandoff? {
        guard let data = activity.userInfo?[handoffKey] as? Data else { return nil }
        return try? JSONDecoder().decode(PlaybackHandoff.self, from: data)
    }
}
