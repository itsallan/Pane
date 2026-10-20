import Foundation

/// A folder the user imported. Its files are library items that point back at it.
public struct LibraryFolder: Sendable, Hashable, Identifiable {
    public let id: UUID
    public var name: String
    public var dateAdded: Date

    public init(id: UUID = UUID(), name: String, dateAdded: Date = .now) {
        self.id = id
        self.name = name
        self.dateAdded = dateAdded
    }
}
