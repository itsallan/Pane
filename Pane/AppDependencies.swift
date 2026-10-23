import Data
import Domain
import Foundation
import Observation
import Playback
import SwiftData

/// The composition root: one store and one set of repositories for the whole app, shared by every window.
@Observable
final class AppDependencies {
    let library: any LibraryRepository
    let progress: any ProgressRepository
    let preferences: any PreferencesRepository
    let importer: any MediaImporter
    let thumbnails: any ThumbnailProvider
    let servers: any NetworkServerRepository
    let credentials: any CredentialStore
    let streamHistory: any StreamHistoryRepository
    let networkBrowser: any NetworkBrowser
    let openPlayers = OpenPlayers()
    private let nowPlaying: NowPlaying
    #if os(iOS)
    private let audioSession: PlaybackAudioSession
    #endif
    private let store: SwiftDataLibraryRepository
    /// Read when a player is built, because libvlc takes part of the style only at creation.
    private(set) var subtitleStyle = SubtitleStyle()
    /// Bumped whenever playback changes progress, so library windows know to reload.
    private(set) var libraryRevision = 0

    init() {
        let container: ModelContainer
        do {
            container = try .library()
        } catch {
            // A store that can't open (a failed migration, a full disk) shouldn't stop the app from playing files.
            do {
                container = try .library(inMemory: true)
            } catch {
                fatalError("Couldn't create even an in-memory library store: \(error)")
            }
        }
        store = SwiftDataLibraryRepository(modelContainer: container)
        library = store
        progress = SwiftDataProgressRepository(modelContainer: container)
        preferences = UserDefaultsPreferencesRepository()
        importer = BookmarkImporter(library: store)
        let serverStore = SwiftDataNetworkServerRepository(modelContainer: container)
        servers = serverStore
        let keychain = KeychainCredentialStore()
        credentials = keychain
        thumbnails = VLCThumbnailProvider(servers: serverStore, credentials: keychain)
        streamHistory = SwiftDataStreamHistoryRepository(modelContainer: container)
        nowPlaying = NowPlaying(thumbnails: thumbnails)
        #if DEBUG
        networkBrowser = DemoNetwork.isEnabled ? DemoNetwork.browser(credentials: keychain) : VLCNetworkBrowser(credentials: keychain)
        #else
        networkBrowser = VLCNetworkBrowser(credentials: keychain)
        #endif
        #if os(iOS)
        audioSession = PlaybackAudioSession(players: openPlayers)
        audioSession.activate()
        #endif
    }

    func playerDidOpen(_ session: PlayerSession) {
        openPlayers.add(session)
        nowPlaying.add(session)
    }

    /// Saves progress and closes the engine.
    func playerDidClose(_ session: PlayerSession) async {
        openPlayers.remove(session)
        nowPlaying.remove(session)
        await session.close()
        libraryDidChange()
    }

    /// Reopens imported folders and refreshes stale bookmarks; run once at launch.
    func restoreFileAccess() async {
        try? await store.restoreFileAccess()
    }

    func loadSubtitleStyle() async {
        subtitleStyle = (try? await preferences.subtitleStyle()) ?? SubtitleStyle()
    }

    func saveSubtitleStyle(_ style: SubtitleStyle) async {
        subtitleStyle = style
        try? await preferences.save(style)
    }

    /// Opening a stream adds it to the library, which is what gives it resume and a Mac player window.
    func itemForStream(_ url: URL) async -> MediaItem? {
        let name = url.lastPathComponent
        let title = name.isEmpty || name == "/" ? url.host(percentEncoded: false) ?? url.absoluteString : name
        return try? await AddToLibrary(library: library)(.stream(url), title: title)
    }

    /// Files opened from the Files app or Finder are added in place, or found if they're already there.
    func importForOpening(_ urls: [URL]) async -> [MediaItem] {
        (try? await importer.importMedia(at: urls)) ?? []
    }

    /// Adds what another device was playing to this library, with its position as the resume point.
    func continueHandoff(_ handoff: PlaybackHandoff) async throws(HandoffError) -> MediaItem {
        let item = try await ContinueHandoff(library: library, servers: servers, progress: progress, importer: importer)(handoff)
        libraryDidChange()
        return item
    }

    func libraryDidChange() {
        libraryRevision += 1
    }
}
