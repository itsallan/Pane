#if DEBUG
import Domain
import Foundation
import PlaybackTesting

/// Launch with `-PaneDemoNetwork YES` to browse made-up servers, for trying the network screens without a NAS.
/// Credentials still go through the real store, so signing in exercises the keychain. The password is "pane".
enum DemoNetwork {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "PaneDemoNetwork") }

    private static let nas = NetworkServer(
        id: UUID(uuidString: "D3E0D3E0-0000-4000-8000-000000000001") ?? UUID(),
        kind: .smb,
        host: "demo-nas.local",
        displayName: "Demo NAS",
        requiresCredentials: true
    )
    private static let offline = NetworkServer(
        id: UUID(uuidString: "D3E0D3E0-0000-4000-8000-000000000002") ?? UUID(),
        kind: .upnp,
        host: "192.168.1.250",
        displayName: "Unplugged Media Server",
        requiresCredentials: false
    )

    static func browser(credentials: any CredentialStore) -> any NetworkBrowser {
        FakeNetworkBrowser(
            servers: [nas, offline],
            listings: [nas.id: [
                "/": [
                    NetworkEntry(name: "Movies", path: "/Movies", isDirectory: true),
                    NetworkEntry(name: "TV Shows", path: "/TV Shows", isDirectory: true),
                    NetworkEntry(name: "Sintel.mkv", path: "/Sintel.mkv", isDirectory: false, size: 1_420_000_000),
                    NetworkEntry(name: "Tears of Steel.mp4", path: "/Tears of Steel.mp4", isDirectory: false, size: 734_003_200),
                    NetworkEntry(name: "README.txt", path: "/README.txt", isDirectory: false, size: 2_048),
                ],
                "/Movies": [
                    NetworkEntry(name: "Big Buck Bunny.mov", path: "/Movies/Big Buck Bunny.mov", isDirectory: false, size: 276_134_947),
                ],
            ]],
            passwords: [nas.id: "pane"],
            credentials: credentials
        )
    }
}
#endif
