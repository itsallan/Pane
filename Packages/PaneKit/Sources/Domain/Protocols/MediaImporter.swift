import Foundation

public protocol MediaImporter: Sendable {
    /// Adds files, and the playable files inside folders, to the library. Returns only the items that are new.
    /// The URLs may be security scoped; the importer keeps a bookmark so they stay reachable after relaunch.
    func importMedia(at urls: [URL]) async throws -> [MediaItem]
}
