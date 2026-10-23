import Foundation
import SwiftData

@Model
final class NetworkServerRecord {
    enum Kind: String, Codable {
        case smb
        case sftp
        case upnp
    }

    var id = UUID()
    var kind = Kind.smb
    var host = ""
    var port: Int?
    var displayName = ""
    var requiresCredentials = false

    init(id: UUID, kind: Kind, host: String, port: Int?, displayName: String, requiresCredentials: Bool) {
        self.id = id
        self.kind = kind
        self.host = host
        self.port = port
        self.displayName = displayName
        self.requiresCredentials = requiresCredentials
    }
}
