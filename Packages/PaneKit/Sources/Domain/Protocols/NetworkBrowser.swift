public protocol NetworkBrowser: Sendable {
    /// Servers found by discovery. SFTP has no discovery protocol, so those servers are only ever added by hand.
    func servers() -> AsyncStream<[NetworkServer]>
    /// Throws `.authenticationRequired` when the credential is missing or rejected.
    func contents(of server: NetworkServer, path: String) async throws(PlaybackError) -> [NetworkEntry]
}
