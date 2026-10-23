import Foundation
import SwiftData

// CloudKit can't enforce uniqueness and needs every attribute optional or defaulted, so the repositories
// look records up by ID before inserting instead of relying on a unique constraint.
@Model
final class FolderRecord {
    var id = UUID()
    var name = ""
    var bookmark = Data()
    var importedPath = ""
    var dateAdded = Date.distantPast
    /// The device that imported the folder. Its bookmark only resolves there, so other devices hide it.
    var originDevice: String?
    @Relationship(deleteRule: .cascade, inverse: \MediaItemRecord.folder) var items: [MediaItemRecord]? = []

    init(id: UUID, name: String, bookmark: Data, importedPath: String, dateAdded: Date, originDevice: String?) {
        self.id = id
        self.name = name
        self.bookmark = bookmark
        self.importedPath = importedPath
        self.dateAdded = dateAdded
        self.originDevice = originDevice
    }
}
