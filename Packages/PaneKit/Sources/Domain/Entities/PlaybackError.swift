import Foundation

public enum PlaybackError: Error, Sendable, Hashable {
    case unresolvableBookmark
    case unknownServer(NetworkServer.ID)
    case authenticationRequired(server: NetworkServer.ID)
    case serverUnreachable(NetworkServer.ID)
    case unknownTrack(MediaTrack.ID)
    case unreadableSubtitle(URL)
    case captureFailed
    case thumbnailFailed
    case decodingFailed
    case networkFailed
}
