import Foundation
import SwiftData

@Model
final class FolderRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var bookmark: Data
    var importedPath: String
    var dateAdded: Date
    @Relationship(deleteRule: .cascade, inverse: \MediaItemRecord.folder) var items: [MediaItemRecord] = []

    init(id: UUID, name: String, bookmark: Data, importedPath: String, dateAdded: Date) {
        self.id = id
        self.name = name
        self.bookmark = bookmark
        self.importedPath = importedPath
        self.dateAdded = dateAdded
    }
}
