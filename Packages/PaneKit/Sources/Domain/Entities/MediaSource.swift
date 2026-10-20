import Foundation

public enum MediaSource: Sendable, Hashable {
    /// A security-scoped bookmark, resolved by the Data layer.
    case file(bookmark: Data)
    case stream(URL)
    /// Refers to its server by ID so credentials never travel with the source.
    case networkShare(server: NetworkServer.ID, path: String)
}
