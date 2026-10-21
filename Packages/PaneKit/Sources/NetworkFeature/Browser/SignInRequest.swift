import Domain

/// Keyed by server, so a rejected password updates the open sheet in place instead of dismissing and re-presenting it.
public struct SignInRequest: Identifiable, Hashable, Sendable {
    public let id: NetworkServer.ID
    public let serverName: String
    /// Pre-filled from the saved login, if there is one.
    public let user: String
    /// The share turned down the saved login.
    public let isRetry: Bool
}
