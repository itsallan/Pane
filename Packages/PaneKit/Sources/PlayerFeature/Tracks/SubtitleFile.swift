import Foundation
import UniformTypeIdentifiers

enum SubtitleFile {
    static let contentTypes: [UTType] = ["srt", "ass", "ssa", "vtt", "sub"].compactMap { UTType(filenameExtension: $0) }

    private static let directory = URL.cachesDirectory.appending(path: "Subtitles", directoryHint: .isDirectory)

    /// Keeps the original name, which the engine uses as the track title.
    @concurrent
    static func copy(of url: URL) async throws -> URL {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let folder = directory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appending(path: url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }
}
