import Data
import Domain
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
    private let store: SwiftDataLibraryRepository
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
        thumbnails = VLCThumbnailProvider()
    }

    /// Reopens imported folders and refreshes stale bookmarks; run once at launch.
    func restoreFileAccess() async {
        try? await store.restoreFileAccess()
    }

    func libraryDidChange() {
        libraryRevision += 1
    }
}
