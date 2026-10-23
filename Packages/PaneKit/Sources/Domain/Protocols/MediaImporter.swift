import Foundation

public protocol MediaImporter: Sendable {
    /// Adds files, and the playable files inside folders, to the library. Returns the items for those files,
    /// including ones that were already in the library, so opening a file twice plays the same item.
    /// The URLs may be security scoped; the importer keeps a bookmark so they stay reachable after relaunch.
    func importMedia(at urls: [URL]) async throws -> [MediaItem]
    /// Whether a file bookmark points at a file this device can open. Bookmarks don't travel between devices.
    func canOpen(_ bookmark: Data) async -> Bool
}
