import UniformTypeIdentifiers

extension UTType {
    // Neither is a system type; the app declares both as imported types so the pickers can offer them.
    static let matroska = UTType(importedAs: "org.matroska.mkv", conformingTo: .movie)
    static let webM = UTType(importedAs: "org.webmproject.webm", conformingTo: .movie)

    static let playableMedia: [UTType] = [.audiovisualContent, .matroska, .webM]
}
