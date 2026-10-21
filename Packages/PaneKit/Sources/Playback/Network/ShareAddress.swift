import Domain
import Foundation

/// Where a share lives and how to sign in to it. The credential goes into per-media options, never the MRL,
/// so it can't end up in a library record, a log line or VLC's own history.
struct ShareAddress: Sendable {
    let url: URL
    let options: [String: String]

    init(url: URL, options: [String: String] = [:]) {
        self.url = url
        self.options = options
    }

    init(server: NetworkServer, path: String, credential: NetworkCredential?) throws(PlaybackError) {
        guard let scheme = server.kind.scheme else {
            // UPnP items are addressed by the full URL the media server handed out, not by a path.
            guard let url = URL(string: path), url.scheme != nil else { throw .unknownServer(server.id) }
            self.init(url: url)
            return
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = server.host
        components.port = server.port
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = components.url else { throw .unknownServer(server.id) }
        self.init(url: url, options: credential.map { Self.options(for: $0, kind: server.kind) } ?? [:])
    }

    private static func options(for credential: NetworkCredential, kind: NetworkServer.Kind) -> [String: String] {
        switch kind {
        case .smb:
            // Windows-style DOMAIN\user logins carry the domain separately in libsmb2.
            let parts = credential.user.split(separator: "\\", maxSplits: 1)
            if parts.count == 2 {
                return ["smb-domain": String(parts[0]), "smb-user": String(parts[1]), "smb-pwd": credential.password]
            }
            return ["smb-user": credential.user, "smb-pwd": credential.password]
        case .sftp:
            return ["sftp-user": credential.user, "sftp-pwd": credential.password]
        case .upnp:
            return [:]
        }
    }
}

extension NetworkServer.Kind {
    var scheme: String? {
        switch self {
        case .smb: "smb"
        case .sftp: "sftp"
        case .upnp: nil
        }
    }
}
