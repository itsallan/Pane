import Foundation
import SwiftData

@Model
final class RecentStreamRecord {
    @Attribute(.unique) var url: URL
    var lastOpened: Date

    init(url: URL, lastOpened: Date) {
        self.url = url
        self.lastOpened = lastOpened
    }
}
