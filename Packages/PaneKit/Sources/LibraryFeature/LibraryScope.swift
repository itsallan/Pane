import Domain

public enum LibraryScope: Hashable, Sendable {
    case all
    case recents
    case folder(LibraryFolder)
}
