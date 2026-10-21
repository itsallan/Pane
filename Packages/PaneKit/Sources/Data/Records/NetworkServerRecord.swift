import Foundation
import SwiftData

@Model
final class NetworkServerRecord {
    enum Kind: String, Codable {
        case smb
        case sftp
        case upnp
    }

    @Attribute(.unique) var id: UUID
    var kind: Kind
    var host: String
    var port: Int?
    var displayName: String
    var requiresCredentials: Bool

    init(id: UUID, kind: Kind, host: String, port: Int?, displayName: String, requiresCredentials: Bool) {
        self.id = id
        self.kind = kind
        self.host = host
        self.port = port
        self.displayName = displayName
        self.requiresCredentials = requiresCredentials
    }
}
