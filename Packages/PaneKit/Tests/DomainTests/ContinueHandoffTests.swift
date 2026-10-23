import Domain
import Foundation
import PlaybackTesting
import Testing

struct ContinueHandoffTests {
    private let progress = PlaybackProgress(position: .seconds(754), duration: .seconds(5400))
    private let nas = NetworkServer(kind: .smb, host: "nas.local", displayName: "NAS", requiresCredentials: true)

    private struct Device {
        let library: InMemoryLibraryRepository
        let servers: InMemoryNetworkServerRepository
        let progress = InMemoryProgressRepository()
        let continueHandoff: ContinueHandoff

        init(items: [MediaItem] = [], servers: [NetworkServer] = [], openableBookmarks: Set<Data>? = nil) {
            library = InMemoryLibraryRepository(items: items)
            self.servers = InMemoryNetworkServerRepository(servers: servers)
            continueHandoff = ContinueHandoff(
                library: library,
                servers: self.servers,
                progress: progress,
                importer: FakeMediaImporter(library: library, openableBookmarks: openableBookmarks)
            )
        }
    }

    @Test func survivesEncoding() throws {
        let item = MediaItem(title: "Movie", source: .networkShare(server: nas.id, path: "/Movies/Movie.mkv"))
        let handoff = try #require(PlaybackHandoff(item: item, server: nas, progress: progress))
        let decoded = try JSONDecoder().decode(PlaybackHandoff.self, from: JSONEncoder().encode(handoff))
        #expect(decoded == handoff)
    }

    @Test func addsAStreamAndResumesWhereTheOtherDeviceWas() async throws {
        let url = try #require(URL(string: "https://example.com/live/master.m3u8"))
        let device = Device()

        let item = try await device.continueHandoff(PlaybackHandoff(title: "Live", source: .stream(url), progress: progress))

        #expect(item.source == .stream(url))
        #expect(try await device.library.items() == [item])
        #expect(try await device.progress.progress(for: item.id) == progress)
    }

    @Test func reusesAServerSavedUnderAnotherID() async throws {
        let saved = NetworkServer(kind: .smb, host: "nas.local", displayName: "Home NAS", requiresCredentials: true)
        let device = Device(servers: [saved])
        let handoff = PlaybackHandoff(title: "Movie", source: .share(server: .init(nas), path: "/Movie.mkv"), progress: progress)

        let item = try await device.continueHandoff(handoff)

        #expect(item.source == .networkShare(server: saved.id, path: "/Movie.mkv"))
        #expect(try await device.servers.servers() == [saved])
    }

    @Test func savesAnUnknownServerWithoutCredentials() async throws {
        let device = Device()
        let handoff = PlaybackHandoff(title: "Movie", source: .share(server: .init(nas), path: "/Movie.mkv"), progress: progress)

        let item = try await device.continueHandoff(handoff)

        #expect(item.source == .networkShare(server: nas.id, path: "/Movie.mkv"))
        #expect(try await device.servers.servers() == [nas])
    }

    @Test func opensAFileThisDeviceCanReach() async throws {
        let bookmark = Data([1, 2, 3])
        let local = MediaItem(title: "Holiday", source: .file(bookmark: bookmark))
        let device = Device(items: [local], openableBookmarks: [bookmark])
        let handoff = PlaybackHandoff(title: "Holiday", source: .file(itemID: UUID()), progress: progress)

        let item = try await device.continueHandoff(handoff)

        #expect(item == local)
        #expect(try await device.progress.progress(for: local.id) == progress)
    }

    @Test func refusesAFileOnlyTheOtherDeviceHas() async throws {
        let synced = MediaItem(title: "Holiday", source: .file(bookmark: Data([9])))
        let device = Device(items: [synced], openableBookmarks: [])
        let handoff = PlaybackHandoff(title: "Holiday", source: .file(itemID: synced.id), progress: progress)

        await #expect(throws: HandoffError.fileUnavailable(title: "Holiday")) {
            try await device.continueHandoff(handoff)
        }
        #expect(try await device.progress.allProgress().isEmpty)
    }

    @Test func needsTheServerToHandOffAShare() {
        let item = MediaItem(title: "Movie", source: .networkShare(server: nas.id, path: "/Movie.mkv"))
        #expect(PlaybackHandoff(item: item, server: nil, progress: progress) == nil)
    }
}
