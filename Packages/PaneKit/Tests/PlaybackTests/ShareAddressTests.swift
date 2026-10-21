import Domain
import Foundation
import Testing
@testable import Playback

struct ShareAddressTests {
    private let nas = NetworkServer(kind: .smb, host: "nas.local", displayName: "NAS", requiresCredentials: true)

    @Test func credentialsGoInOptionsNeverInTheURL() throws {
        let address = try ShareAddress(server: nas, path: "/Movies/Sintel (2010).mkv", credential: NetworkCredential(user: "pane", password: "p@ss:word"))

        #expect(address.url.absoluteString == "smb://nas.local/Movies/Sintel%20(2010).mkv")
        #expect(address.url.user == nil && address.url.password == nil)
        #expect(address.options == ["smb-user": "pane", "smb-pwd": "p@ss:word"])
    }

    @Test func splitsAWindowsDomainOut() throws {
        let address = try ShareAddress(server: nas, path: "/", credential: NetworkCredential(user: "WORKGROUP\\pane", password: "x"))
        #expect(address.options == ["smb-domain": "WORKGROUP", "smb-user": "pane", "smb-pwd": "x"])
    }

    @Test func sftpKeepsItsPort() throws {
        let seedbox = NetworkServer(kind: .sftp, host: "seedbox.example.com", port: 2222, displayName: "Seedbox", requiresCredentials: true)
        let address = try ShareAddress(server: seedbox, path: "downloads", credential: NetworkCredential(user: "me", password: "x"))

        #expect(address.url.absoluteString == "sftp://seedbox.example.com:2222/downloads")
        #expect(address.options == ["sftp-user": "me", "sftp-pwd": "x"])
    }

    @Test func upnpUsesTheItemURLAsIs() throws {
        let server = NetworkServer(kind: .upnp, host: "192.168.1.5", displayName: "MiniDLNA", requiresCredentials: false)
        let item = "http://192.168.1.5:8200/MediaItems/22.mkv"

        #expect(try ShareAddress(server: server, path: item, credential: nil).url.absoluteString == item)
        #expect(throws: PlaybackError.unknownServer(server.id)) { try ShareAddress(server: server, path: "/Movies", credential: nil) }
    }

    @Test func discoveredServersKeepTheirIDAcrossLaunches() {
        let first = DiscoveredServer.stableID(kind: .smb, host: "NAS.local", port: nil)
        #expect(first == DiscoveredServer.stableID(kind: .smb, host: "nas.local", port: nil))
        #expect(first != DiscoveredServer.stableID(kind: .sftp, host: "nas.local", port: nil))
    }
}
