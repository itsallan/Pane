import CryptoKit
import Domain
import Foundation
@preconcurrency import VLCKit

struct DiscoveredServer: Sendable, Hashable {
    let server: NetworkServer
    /// The MRL VLC uses for the server's top level. For UPnP this is the only way back to it.
    let root: URL

    init?(_ media: VLCMedia) {
        guard let url = media.url, let scheme = url.scheme?.lowercased() else { return nil }
        let kind: NetworkServer.Kind
        let host: String
        let port: Int?
        switch scheme {
        case "smb":
            kind = .smb
            guard let smbHost = url.host(percentEncoded: false) else { return nil }
            host = smbHost
            port = url.port
        case "sftp":
            kind = .sftp
            guard let sftpHost = url.host(percentEncoded: false) else { return nil }
            host = sftpHost
            port = url.port
        case "upnp":
            // The UPnP module wraps the device's description URL: upnp://http://192.168.1.5:8200/rootDesc.xml?ObjectID=0
            let inner = URL(string: String(url.absoluteString.dropFirst("upnp://".count)))
            guard let upnpHost = inner?.host(percentEncoded: false) ?? url.host(percentEncoded: false) else { return nil }
            kind = .upnp
            host = upnpHost
            port = inner?.port
        default:
            return nil
        }
        let name = media.metaData.title.flatMap { $0.isEmpty ? nil : $0 } ?? host
        server = NetworkServer(
            id: Self.stableID(kind: kind, host: host, port: port),
            kind: kind,
            host: host,
            port: port,
            displayName: name,
            requiresCredentials: false
        )
        root = url
    }

    /// The same machine gets the same ID on every launch, so a share saved from discovery matches when it's found again.
    static func stableID(kind: NetworkServer.Kind, host: String, port: Int?) -> UUID {
        let key = "\(kind.scheme ?? "upnp")://\(host.lowercased()):\(port ?? 0)"
        var bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        // Mark it as a name-based (version 5 style) UUID so it can't collide with a random one.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
