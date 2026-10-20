import Domain
import Foundation
import LibraryFeature
import Observation

/// Per window: what's selected, the navigation paths and the presented player.
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case library
        case recents
    }

    var selectedTab = Tab.library
    var sidebarSelection: LibraryScope? = .all
    var libraryPath: [LibraryScope] = []
    var presentedSession: PlayerSession?

    let dependencies: AppDependencies
    @ObservationIgnored private var models: [LibraryScope: LibraryModel] = [:]

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

    func present(_ item: MediaItem) {
        guard presentedSession == nil else { return }
        presentedSession = PlayerSession(item: item, dependencies: dependencies)
    }

    func dismissPlayer() {
        presentedSession = nil
    }

    func playerDidClose(_ session: PlayerSession) async {
        await session.close()
        dependencies.libraryDidChange()
    }

    func reloadLibraries() async {
        for model in models.values {
            await model.load()
        }
    }

    /// Files opened from the Files app or Finder: added to the library in place, then the first one plays.
    func importForOpening(_ urls: [URL]) async -> MediaItem? {
        let items = try? await dependencies.importer.importMedia(at: urls)
        await reloadLibraries()
        return items?.first
    }

    func removeFolder(_ folder: LibraryFolder) async {
        if sidebarSelection == .folder(folder) {
            sidebarSelection = .all
        }
        libraryPath.removeAll { $0 == .folder(folder) }
        await model(for: .all).removeFolder(folder)
        models[.folder(folder)] = nil
        await reloadLibraries()
    }
}
