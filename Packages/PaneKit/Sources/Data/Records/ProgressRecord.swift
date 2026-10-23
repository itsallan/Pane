import Foundation
import SwiftData

@Model
final class ProgressRecord {
    var itemID = UUID()
    var positionMilliseconds: Int64 = 0
    var durationMilliseconds: Int64?
    var isWatched = false
    var updatedAt = Date.distantPast

    init(itemID: UUID, positionMilliseconds: Int64, durationMilliseconds: Int64?, isWatched: Bool, updatedAt: Date) {
        self.itemID = itemID
        self.positionMilliseconds = positionMilliseconds
        self.durationMilliseconds = durationMilliseconds
        self.isWatched = isWatched
        self.updatedAt = updatedAt
    }
}
