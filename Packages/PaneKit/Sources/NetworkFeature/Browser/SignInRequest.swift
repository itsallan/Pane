import Foundation

public struct SignInRequest: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let serverName: String
    /// Pre-filled from the saved login, if there is one.
    public let user: String
    /// The share turned down the saved login.
    public let isRetry: Bool
}
