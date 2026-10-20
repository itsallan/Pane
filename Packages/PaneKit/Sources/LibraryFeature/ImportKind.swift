import UniformTypeIdentifiers

/// The document picker can't offer files and folders at once on iOS, so they're separate commands.
enum ImportKind {
    case files
    case folder

    var contentTypes: [UTType] {
        switch self {
        case .files: UTType.playableMedia
        case .folder: [.folder]
        }
    }
}
