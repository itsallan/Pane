import Domain

/// What the network stack can push. The app registers one destination for it and builds the screen.
public enum NetworkRoute: Hashable, Sendable {
    case openURL
    case folder(NetworkServer, path: String, name: String)
}
