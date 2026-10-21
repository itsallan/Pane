import Domain
import SwiftUI

extension NetworkServer {
    var symbolName: String {
        switch kind {
        case .smb: "server.rack"
        case .sftp: "lock.rectangle.stack"
        case .upnp: "tv.and.mediabox"
        }
    }

    var kindLabel: LocalizedStringKey {
        switch kind {
        case .smb: "SMB"
        case .sftp: "SFTP"
        case .upnp: "UPnP"
        }
    }

    var rootRoute: NetworkRoute {
        .folder(self, path: "/", name: displayName)
    }
}
