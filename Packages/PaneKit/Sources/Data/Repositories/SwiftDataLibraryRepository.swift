import Domain
import Foundation
import SwiftData

@ModelActor
public actor SwiftDataLibraryRepository: LibraryRepository {
    // Security scopes for imported folders stay open for the whole run, so files inside them stay readable
    // even where a child bookmark alone wouldn't carry the folder's access.
    private var openFolderScopes: [UUID: URL] = [:]
    private let device = ThisDevice.identifier

    public func items() async throws -> [MediaItem] {
        try modelContext.fetch(FetchDescriptor<MediaItemRecord>()).filter(isReachable).compactMap(\.mediaItem)
    }

    public func item(withID id: MediaItem.ID) async throws -> MediaItem? {
        try record(withID: id)?.mediaItem
    }

    public func save(_ item: MediaItem) async throws {
        if let existing = try record(withID: item.id) {
            existing.update(from: item)
            existing.folder = try item.folderID.flatMap(folderRecord(withID:))
        } else {
            let record = MediaItemRecord(item)
            if record.sourceKind == .file {
                record.originDevice = device
            }
            modelContext.insert(record)
            record.folder = try item.folderID.flatMap(folderRecord(withID:))
        }
        try modelContext.save()
    }

    public func deleteItem(withID id: MediaItem.ID) async throws {
        try modelContext.delete(model: MediaItemRecord.self, where: #Predicate { $0.id == id })
        try modelContext.delete(model: ProgressRecord.self, where: #Predicate { $0.itemID == id })
        try modelContext.save()
    }

    public func folders() async throws -> [LibraryFolder] {
        try modelContext.fetch(FetchDescriptor<FolderRecord>()).filter(isReachable).map(\.libraryFolder)
    }

    public func save(_ folder: LibraryFolder) async throws {
        guard let record = try folderRecord(withID: folder.id) else { return }
        record.name = folder.name
        record.dateAdded = folder.dateAdded
        try modelContext.save()
    }

    public func deleteFolder(withID id: LibraryFolder.ID) async throws {
        guard let record = try folderRecord(withID: id) else { return }
        let itemIDs = (record.items ?? []).map(\.id)
        modelContext.delete(record)
        try modelContext.delete(model: ProgressRecord.self, where: #Predicate { itemIDs.contains($0.itemID) })
        try modelContext.save()
        openFolderScopes.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
    }

    /// Run once at launch: reopens imported folders and replaces stale bookmarks before anything plays.
    public func restoreFileAccess() throws {
        try claimUnstampedRecords()
        for folder in try modelContext.fetch(FetchDescriptor<FolderRecord>()).filter(isReachable) where openFolderScopes[folder.id] == nil {
            guard let resolution = try? SecurityScopedBookmark.resolve(folder.bookmark) else { continue }
            if let refreshed = resolution.refreshed {
                folder.bookmark = refreshed
            }
            if resolution.url.startAccessingSecurityScopedResource() {
                openFolderScopes[folder.id] = resolution.url
            }
        }
        // SwiftData predicates can't compare against an enum constant, so files are picked out after the fetch.
        let files = try modelContext.fetch(FetchDescriptor<MediaItemRecord>()).filter { $0.sourceKind == .file }
        for file in files where isReachable(file) {
            guard let bookmark = file.bookmark, let refreshed = try? SecurityScopedBookmark.resolve(bookmark).refreshed else { continue }
            file.bookmark = refreshed
        }
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}

extension SwiftDataLibraryRepository {
    func file(atPath path: String) throws -> MediaItem? {
        try modelContext.fetch(FetchDescriptor<MediaItemRecord>(predicate: #Predicate { $0.importedPath == path })).first?.mediaItem
    }

    func insertFile(_ item: MediaItem, importedPath: String) throws {
        let record = MediaItemRecord(item)
        record.importedPath = importedPath
        record.originDevice = device
        modelContext.insert(record)
        record.folder = try item.folderID.flatMap(folderRecord(withID:))
        try modelContext.save()
    }

    /// Returns the existing folder when the same directory was imported before.
    func insertFolder(_ folder: LibraryFolder, bookmark: Data, importedPath: String, scope: URL) throws -> LibraryFolder {
        let existing = try modelContext.fetch(FetchDescriptor<FolderRecord>(predicate: #Predicate { $0.importedPath == importedPath }))
        if let existing = existing.first {
            return existing.libraryFolder
        }
        modelContext.insert(FolderRecord(
            id: folder.id,
            name: folder.name,
            bookmark: bookmark,
            importedPath: importedPath,
            dateAdded: folder.dateAdded,
            originDevice: device
        ))
        try modelContext.save()
        if openFolderScopes[folder.id] == nil, scope.startAccessingSecurityScopedResource() {
            openFolderScopes[folder.id] = scope
        }
        return folder
    }

    // Bookmarks only resolve on the device that made them. With iCloud sync on, another device's files and folders
    // arrive here too, and listing them would only offer things that can't play.
    private func isReachable(_ record: MediaItemRecord) -> Bool {
        record.sourceKind != .file || record.originDevice.map { $0 == device } ?? true
    }

    private func isReachable(_ record: FolderRecord) -> Bool {
        record.originDevice.map { $0 == device } ?? true
    }

    // Records from before devices were stamped were all made here; claim them before sync can carry them elsewhere.
    private func claimUnstampedRecords() throws {
        let files = try modelContext.fetch(FetchDescriptor<MediaItemRecord>(predicate: #Predicate { $0.originDevice == nil }))
            .filter { $0.sourceKind == .file }
        let folders = try modelContext.fetch(FetchDescriptor<FolderRecord>(predicate: #Predicate { $0.originDevice == nil }))
        files.forEach { $0.originDevice = device }
        folders.forEach { $0.originDevice = device }
    }

    private func record(withID id: UUID) throws -> MediaItemRecord? {
        try modelContext.fetch(FetchDescriptor<MediaItemRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func folderRecord(withID id: UUID) throws -> FolderRecord? {
        try modelContext.fetch(FetchDescriptor<FolderRecord>(predicate: #Predicate { $0.id == id })).first
    }
}
