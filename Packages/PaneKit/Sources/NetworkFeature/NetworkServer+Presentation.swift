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

    /// One color per protocol, so a glance at the grid says what kind of server each one is.
    var tint: Color {
        switch kind {
        case .smb: .blue
        case .sftp: .indigo
        case .upnp: .orange
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
