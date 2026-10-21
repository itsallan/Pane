#if DEBUG
import Domain
import Foundation
import PlaybackTesting
import SwiftUI

private enum PreviewNetwork {
    static let nas = NetworkServer(kind: .smb, host: "nas.local", displayName: "Living Room NAS", requiresCredentials: true)
    static let seedbox = NetworkServer(kind: .sftp, host: "seedbox.example.com", port: 2222, displayName: "Seedbox", requiresCredentials: true)
    static let dlna = NetworkServer(kind: .upnp, host: "192.168.1.5", displayName: "MiniDLNA", requiresCredentials: false)

    static let browser = FakeNetworkBrowser(
        servers: [nas, dlna],
        listings: [nas.id: ["/": [
            NetworkEntry(name: "Movies", path: "/Movies", isDirectory: true),
            NetworkEntry(name: "TV", path: "/TV", isDirectory: true),
            NetworkEntry(name: "Sintel.mkv", path: "/Sintel.mkv", isDirectory: false, size: 1_420_000_000),
            NetworkEntry(name: "notes.txt", path: "/notes.txt", isDirectory: false, size: 2_048),
        ]]],
        credentials: credentials
    )
    static let credentials = InMemoryCredentialStore(credentials: [nas.id: NetworkCredential(user: "pane", password: "secret")])
}

#Preview("Servers") {
    NavigationStack {
        NetworkScreen(model: NetworkModel(
            browser: PreviewNetwork.browser,
            servers: InMemoryNetworkServerRepository(servers: [PreviewNetwork.seedbox]),
            credentials: PreviewNetwork.credentials
        ))
    }
}

#Preview("Folder") {
    NavigationStack {
        ShareBrowserScreen(
            model: ShareBrowserModel(
                server: PreviewNetwork.nas,
                path: "/",
                title: PreviewNetwork.nas.displayName,
                browser: PreviewNetwork.browser,
                servers: InMemoryNetworkServerRepository(),
                credentials: PreviewNetwork.credentials
            ),
            onOpen: { _, _ in }
        )
    }
}

#Preview("Sign In") {
    NavigationStack {
        ShareBrowserScreen(
            model: ShareBrowserModel(
                server: PreviewNetwork.nas,
                path: "/",
                title: PreviewNetwork.nas.displayName,
                browser: PreviewNetwork.browser,
                servers: InMemoryNetworkServerRepository(),
                credentials: InMemoryCredentialStore()
            ),
            onOpen: { _, _ in }
        )
    }
}

#Preview("Open URL") {
    NavigationStack {
        OpenURLScreen(
            model: OpenURLModel(history: InMemoryStreamHistoryRepository(streams: [
                RecentStream(url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!, lastOpened: .now),
                RecentStream(url: URL(string: "rtsp://camera.local:554/stream1")!, lastOpened: .now.addingTimeInterval(-3600)),
            ])),
            onOpen: { _ in }
        )
    }
}
#endif
