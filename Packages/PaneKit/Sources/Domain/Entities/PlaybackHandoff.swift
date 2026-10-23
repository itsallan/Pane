import Foundation

/// What another device needs to carry on playing: the source as something it can find on its own, and where to resume.
/// Credentials never travel; the other device signs in to a share with its own.
public struct PlaybackHandoff: Sendable, Hashable, Codable {
    public enum Source: Sendable, Hashable, Codable {
        case stream(URL)
        case share(server: Server, path: String)
        /// A bookmark only resolves on the device that made it, so a file is matched by library item, then by name.
        case file(itemID: MediaItem.ID)
    }

    public struct Server: Sendable, Hashable, Codable {
        public var id: NetworkServer.ID
        public var kind: NetworkServer.Kind
        public var host: String
        public var port: Int?
        public var displayName: String
        public var requiresCredentials: Bool

        public init(_ server: NetworkServer) {
            id = server.id
            kind = server.kind
            host = server.host
            port = server.port
            displayName = server.displayName
            requiresCredentials = server.requiresCredentials
        }

        var networkServer: NetworkServer {
            NetworkServer(id: id, kind: kind, host: host, port: port, displayName: displayName, requiresCredentials: requiresCredentials)
        }
    }

    public var title: String
    public var source: Source
    public var progress: PlaybackProgress

    public init(title: String, source: Source, progress: PlaybackProgress) {
        self.title = title
        self.source = source
        self.progress = progress
    }

    /// `server` is required for a `.networkShare` item; without it there's nothing the other device could connect to.
    public init?(item: MediaItem, server: NetworkServer?, progress: PlaybackProgress) {
        let source: Source
        switch item.source {
        case .stream(let url):
            source = .stream(url)
        case .networkShare(let serverID, let path):
            guard let server, server.id == serverID else { return nil }
            source = .share(server: Server(server), path: path)
        case .file:
            source = .file(itemID: item.id)
        }
        self.init(title: item.title, source: source, progress: progress)
    }
}

extension PlaybackProgress: Codable {
    private enum CodingKeys: String, CodingKey {
        case position
        case duration
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            position: try container.decode(Duration.self, forKey: .position),
            duration: try container.decodeIfPresent(Duration.self, forKey: .duration)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encodeIfPresent(duration, forKey: .duration)
    }
}
