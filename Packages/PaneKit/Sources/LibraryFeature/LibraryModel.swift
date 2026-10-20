import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class LibraryModel {
    static let posterPixelSize = 640

    public let scope: LibraryScope

    public private(set) var entries: [LibraryEntry] = []
    public private(set) var continueWatching: [LibraryEntry] = []
    public private(set) var folders: [LibraryFolder] = []
    /// Nothing in this scope at all, as opposed to nothing matching the filter or search.
    public private(set) var isEmpty = true
    public private(set) var hasLoaded = false
    public private(set) var isImporting = false
    public var failure: LibraryFailure?

    public var sortOrder = LibrarySortOrder.dateAdded {
        didSet { refreshVisibleEntries() }
    }
    public var filter = LibraryFilter.all {
        didSet { refreshVisibleEntries() }
    }
    public var searchText = "" {
        didSet { refreshVisibleEntries() }
    }

    private let library: any LibraryRepository
    private let progress: any ProgressRepository
    private let importer: any MediaImporter
    private let thumbnails: any ThumbnailProvider
    private let loadLibrary: LoadLibrary
    private var scopedEntries: [LibraryEntry] = []
    @ObservationIgnored private var posters: [MediaItem.ID: URL] = [:]

    public init(
        scope: LibraryScope = .all,
        library: any LibraryRepository,
        progress: any ProgressRepository,
        importer: any MediaImporter,
        thumbnails: any ThumbnailProvider
    ) {
        self.scope = scope
        self.library = library
        self.progress = progress
        self.importer = importer
        self.thumbnails = thumbnails
        loadLibrary = LoadLibrary(library: library, progress: progress)
        if case .recents = scope {
            sortOrder = .recentlyPlayed
        }
    }

    public var title: String {
        switch scope {
        case .all: String(localized: "Library")
        case .recents: String(localized: "Recents")
        case .folder(let folder): folder.name
        }
    }

    public var canImport: Bool { scope == .all }
    public var canSort: Bool { scope != .recents }

    public var isShowingFailure: Bool {
        get { failure != nil }
        set {
            if !newValue {
                failure = nil
            }
        }
    }

    public func load() async {
        do {
            async let entries = loadLibrary()
            async let folders = library.folders()
            let (allEntries, allFolders) = try await (entries, folders)
            self.folders = allFolders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            scopedEntries = allEntries.filter(isInScope)
            isEmpty = scopedEntries.isEmpty
            continueWatching = scope == .all ? Self.continueWatching(from: allEntries) : []
            refreshVisibleEntries()
        } catch {
            failure = .loadFailed
        }
        hasLoaded = true
    }

    public func importMedia(at urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            _ = try await importer.importMedia(at: urls)
        } catch {
            failure = .importFailed
        }
        await load()
    }

    public func importResult(_ result: Result<[URL], any Error>) async {
        switch result {
        case .success(let urls):
            await importMedia(at: urls)
        case .failure:
            failure = .importFailed
        }
    }

    public func markWatched(_ entry: LibraryEntry) async {
        await update { [progress] in try await progress.markWatched(entry.id) }
    }

    public func markUnwatched(_ entry: LibraryEntry) async {
        await update { [progress] in try await progress.resetProgress(for: entry.id) }
    }

    public func remove(_ entry: LibraryEntry) async {
        await update { [library, progress] in
            try await library.deleteItem(withID: entry.id)
            try await progress.resetProgress(for: entry.id)
        }
    }

    public func removeFolder(_ folder: LibraryFolder) async {
        await update { [library] in try await library.deleteFolder(withID: folder.id) }
    }

    /// A frame from early in the video, generated once per item and kept for the life of the model.
    public func poster(for item: MediaItem) async -> URL? {
        if let cached = posters[item.id] {
            return cached
        }
        let position = item.duration.map { min($0 * 0.1, .seconds(120)) } ?? .seconds(20)
        guard let url = try? await thumbnails.thumbnail(for: item.source, at: position, maxPixelSize: Self.posterPixelSize) else {
            return nil
        }
        posters[item.id] = url
        return url
    }

    private func update(_ change: @Sendable () async throws -> Void) async {
        do {
            try await change()
        } catch {
            failure = .updateFailed
        }
        await load()
    }
}

extension LibraryModel {
    private func isInScope(_ entry: LibraryEntry) -> Bool {
        switch scope {
        case .all: true
        case .recents: entry.lastPlayed != nil
        case .folder(let folder): entry.item.folderID == folder.id
        }
    }

    private func refreshVisibleEntries() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        entries = scopedEntries
            .filter { filter.includes($0) && (query.isEmpty || $0.item.title.localizedStandardContains(query)) }
            .sorted(by: sortOrder.areInIncreasingOrder)
    }

    // The most recently played first, which is the one someone is most likely to go back to.
    private static func continueWatching(from entries: [LibraryEntry]) -> [LibraryEntry] {
        entries
            .filter { $0.resumePosition != nil }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }
}

extension LibraryFilter {
    func includes(_ entry: LibraryEntry) -> Bool {
        switch self {
        case .all: true
        case .unwatched: !entry.isWatched && entry.resumePosition == nil
        case .inProgress: entry.resumePosition != nil
        case .watched: entry.isWatched
        }
    }
}

extension LibrarySortOrder {
    func areInIncreasingOrder(_ lhs: LibraryEntry, _ rhs: LibraryEntry) -> Bool {
        switch self {
        case .dateAdded:
            lhs.item.dateAdded > rhs.item.dateAdded
        case .title:
            lhs.item.title.localizedStandardCompare(rhs.item.title) == .orderedAscending
        case .recentlyPlayed:
            (lhs.lastPlayed ?? .distantPast, lhs.item.dateAdded) > (rhs.lastPlayed ?? .distantPast, rhs.item.dateAdded)
        }
    }
}
