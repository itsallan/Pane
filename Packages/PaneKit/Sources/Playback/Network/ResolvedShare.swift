import Domain

/// A `.networkShare` source looked up against the saved server and its credential.
struct ResolvedShare: Sendable {
    let server: NetworkServer
    let address: ShareAddress
    let credential: NetworkCredential?

    /// Returns nil for sources that aren't shares.
    init?(
        _ source: MediaSource,
        servers: (any NetworkServerRepository)?,
        credentials: (any CredentialStore)?
    ) async throws(PlaybackError) {
        guard case .networkShare(let id, let path) = source else { return nil }
        guard let server = try? await servers?.server(withID: id) else { throw .unknownServer(id) }
        let credential = try? await credentials?.credential(for: id)
        self.server = server
        self.credential = credential
        address = try ShareAddress(server: server, path: path, credential: credential)
    }
}
