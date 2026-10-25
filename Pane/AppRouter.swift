import Domain
import Foundation
import LibraryFeature
import NetworkFeature
import Observation
import SettingsFeature

/// Per window: what's selected, the navigation paths and the presented player.
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case library
        case recents
        case network
    }

    enum SidebarItem: Hashable {
        case library(LibraryScope)
        case network
    }

    var selectedTab = Tab.library
    var sidebarSelection: SidebarItem? = .library(.all)
    var libraryPath: [LibraryScope] = []
    var networkPath: [NetworkRoute] = []
    var presentedSession: PlayerSession?
    var handoffFailure: HandoffFailure?
    var isShowingSettings = false

    var isShowingHandoffFailure: Bool {
        get { handoffFailure != nil }
        set {
            if !newValue {
                handoffFailure = nil
            }
        }
    }

    let dependencies: AppDependencies
    @ObservationIgnored private var models: [LibraryScope: LibraryModel] = [:]
    @ObservationIgnored private var browserModels: [NetworkRoute: ShareBrowserModel] = [:]
    @ObservationIgnored private(set) lazy var networkModel = NetworkModel(
        browser: dependencies.networkBrowser,
        servers: dependencies.servers,
        credentials: dependencies.credentials
    )
    @ObservationIgnored private(set) lazy var settingsModel = SettingsModel(
        preferences: dependencies.preferences,
        launchStatus: dependencies.cloudSync,
        onSubtitleStyleChange: { [dependencies] in dependencies.subtitleStyleDidChange($0) }
    )
    @ObservationIgnored private(set) lazy var openURLModel = OpenURLModel(history: dependencies.streamHistory)

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var folders: [LibraryFolder] { model(for: .all).folders }

    /// Models are made once per scope and kept, so switching back to a scope doesn't reload or lose its sort and filter.
    func model(for scope: LibraryScope) -> LibraryModel {
        if let model = models[scope] {
            return model
        }
        let model = LibraryModel(
            scope: scope,
            library: dependencies.library,
            progress: dependencies.progress,
            importer: dependencies.importer,
            thumbnails: dependencies.thumbnails
        )
        models[scope] = model
        return model
    }

    /// Kept per route like the library models, so going back to a folder shows its listing without asking the server again.
    func browserModel(for route: NetworkRoute) -> ShareBrowserModel? {
        guard case .folder(let server, let path, let name) = route else { return nil }
        if let model = browserModels[route] {
            return model
        }
        let model = ShareBrowserModel(
            server: server,
            path: path,
            title: name,
            browser: dependencies.networkBrowser,
            servers: dependencies.servers,
            credentials: dependencies.credentials
        )
        browserModels[route] = model
        return model
    }

    func networkPathDidChange() {
        browserModels = browserModels.filter { networkPath.contains($0.key) }
    }

    func itemForStream(_ url: URL) async -> MediaItem? {
        let item = await dependencies.itemForStream(url)
        await reloadLibraries()
        return item
    }

    func itemForNetworkFile(_ entry: NetworkEntry, on server: NetworkServer) async -> MediaItem? {
        // The engine finds the server by ID when it opens the file, so a server found by discovery has to be saved first.
        do {
            try await dependencies.servers.save(server)
        } catch {
            return nil
        }
        return await addToLibrary(.networkShare(server: server.id, path: entry.path), title: (entry.name as NSString).deletingPathExtension)
    }

    private func addToLibrary(_ source: MediaSource, title: String) async -> MediaItem? {
        let item = try? await AddToLibrary(library: dependencies.library)(source, title: title)
        await reloadLibraries()
        return item
    }

    func present(_ item: MediaItem) {
        guard presentedSession == nil else { return }
        presentReplacing(item)
    }

    /// Handoff can arrive while something else plays; the new item replaces it, and the old one closes on disappear.
    func presentReplacing(_ item: MediaItem) {
        let session = PlayerSession(item: item, dependencies: dependencies)
        presentedSession = session
        dependencies.playerDidOpen(session)
    }

    func dismissPlayer() {
        presentedSession = nil
    }

    func playerDidClose(_ session: PlayerSession) async {
        await dependencies.playerDidClose(session)
    }

    func reloadLibraries() async {
        for model in models.values {
            await model.load()
        }
    }

    /// Files opened from the Files app or Finder, added to the library in place.
    func importForOpening(_ urls: [URL]) async -> [MediaItem] {
        let items = await dependencies.importForOpening(urls)
        await reloadLibraries()
        return items
    }

    func removeFolder(_ folder: LibraryFolder) async {
        if sidebarSelection == .library(.folder(folder)) {
            sidebarSelection = .library(.all)
        }
        libraryPath.removeAll { $0 == .folder(folder) }
        await model(for: .all).removeFolder(folder)
        models[.folder(folder)] = nil
        await reloadLibraries()
    }
}
