import Foundation

public struct LibraryEntry: Sendable, Hashable, Identifiable {
    public var item: MediaItem
    /// Set only when opening the item would actually resume, so a badge never promises a resume that won't happen.
    public var resumePosition: Duration?
    public var isWatched: Bool
    public var lastPlayed: Date?

    public var id: MediaItem.ID { item.id }

    public init(item: MediaItem, resumePosition: Duration?, isWatched: Bool, lastPlayed: Date? = nil) {
        self.item = item
        self.resumePosition = resumePosition
        self.isWatched = isWatched
        self.lastPlayed = lastPlayed
    }
}
