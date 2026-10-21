import Foundation

public struct RecentStream: Sendable, Hashable, Identifiable {
    public var url: URL
    public var lastOpened: Date

    public var id: URL { url }

    public init(url: URL, lastOpened: Date) {
        self.url = url
        self.lastOpened = lastOpened
    }
}
