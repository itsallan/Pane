import Foundation
import SwiftData

@Model
final class MediaItemRecord {
    enum SourceKind: String, Codable {
        case file
        case stream
        case networkShare
    }

    var id = UUID()
    var title = ""
    var sourceKind = SourceKind.stream
    var bookmark: Data?
    var streamURL: URL?
    var shareServerID: UUID?
    var sharePath: String?
    /// Where the file was at import, so importing it again doesn't duplicate it. Never used to open the file.
    var importedPath: String?
    var durationMilliseconds: Int64?
    var dateAdded = Date.distantPast
    /// For files: the device that imported it, the only one its bookmark resolves on.
    var originDevice: String?
    var folder: FolderRecord?

    init(id: UUID, title: String, sourceKind: SourceKind, dateAdded: Date) {
        self.id = id
        self.title = title
        self.sourceKind = sourceKind
        self.dateAdded = dateAdded
    }
}
