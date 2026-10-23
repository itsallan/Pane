import Foundation
import SwiftData

@Model
final class RecentStreamRecord {
    // Optional only because CloudKit needs a default and there's no sensible default URL.
    var url: URL?
    var lastOpened = Date.distantPast

    init(url: URL, lastOpened: Date) {
        self.url = url
        self.lastOpened = lastOpened
    }
}
