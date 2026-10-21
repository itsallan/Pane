import Domain
import Foundation
import UniformTypeIdentifiers

extension NetworkEntry {
    // VLC plays plenty that UTType doesn't classify as movies (Matroska, WebM, Ogg), so extensions back up the type check.
    private static let extraExtensions: Set<String> = [
        "mkv", "mka", "webm", "ogv", "ogg", "avi", "flv", "wmv", "ts", "m2ts", "mts", "vob", "rmvb", "divx", "3gp",
    ]

    var isPlayable: Bool {
        guard !isDirectory else { return false }
        let pathExtension = (name as NSString).pathExtension.lowercased()
        if Self.extraExtensions.contains(pathExtension) {
            return true
        }
        return UTType(filenameExtension: pathExtension)?.conforms(to: .audiovisualContent) == true
    }

    var symbolName: String {
        if isDirectory {
            return "folder"
        }
        return isPlayable ? "film" : "doc"
    }

    var sizeText: String? {
        size.map { $0.formatted(.byteCount(style: .file)) }
    }
}
