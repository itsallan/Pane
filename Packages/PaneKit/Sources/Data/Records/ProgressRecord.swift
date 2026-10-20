import Foundation
import SwiftData

@Model
final class ProgressRecord {
    @Attribute(.unique) var itemID: UUID
    var positionMilliseconds: Int64
    var durationMilliseconds: Int64?
    var isWatched: Bool
    var updatedAt: Date

    init(itemID: UUID, positionMilliseconds: Int64, durationMilliseconds: Int64?, isWatched: Bool, updatedAt: Date) {
        self.itemID = itemID
        self.positionMilliseconds = positionMilliseconds
        self.durationMilliseconds = durationMilliseconds
        self.isWatched = isWatched
        self.updatedAt = updatedAt
    }
}
