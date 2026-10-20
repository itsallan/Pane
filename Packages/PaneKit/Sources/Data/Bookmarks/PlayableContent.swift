import Foundation
import UniformTypeIdentifiers

enum PlayableContent {
    // VLC plays plenty that UTType doesn't classify as movies (Matroska, WebM, Ogg), so extensions back up the type check.
    private static let extraExtensions: Set<String> = [
        "mkv", "mka", "webm", "ogv", "ogg", "avi", "flv", "wmv", "ts", "m2ts", "mts", "vob", "rmvb", "divx", "3gp",
    ]

    static func isPlayable(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        if extraExtensions.contains(pathExtension) {
            return true
        }
        guard let type = UTType(filenameExtension: pathExtension) else { return false }
        return type.conforms(to: .audiovisualContent)
    }
}
