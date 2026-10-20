import Foundation

public struct MediaItem: Sendable, Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public var source: MediaSource
    public var duration: Duration?
    public var dateAdded: Date

    public init(id: UUID = UUID(), title: String, source: MediaSource, duration: Duration? = nil, dateAdded: Date = .now) {
        self.id = id
        self.title = title
        self.source = source
        self.duration = duration
        self.dateAdded = dateAdded
    }
}
