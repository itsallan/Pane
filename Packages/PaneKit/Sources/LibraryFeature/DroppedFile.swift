#if os(iOS)
import Foundation
import UniformTypeIdentifiers

enum DroppedFile {
    private static let acceptedTypes: [UTType] = UTType.playableMedia + [.folder]

    /// The original file when the source app allows opening it in place, otherwise a copy in Documents,
    /// because a copy handed to the drop only lives until the callback returns.
    // NSItemProvider isn't Sendable, so it stays on the main actor; only the resulting URL crosses back.
    @MainActor
    static func load(from provider: NSItemProvider) async -> URL? {
        guard let type = provider.registeredContentTypes.first(where: { type in acceptedTypes.contains { type.conforms(to: $0) } }) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            _ = provider.loadInPlaceFileRepresentation(forTypeIdentifier: type.identifier) { url, isInPlace, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: isInPlace ? url : keepCopy(of: url))
            }
        }
    }

    private static func keepCopy(of url: URL) -> URL? {
        let directory = URL.documentsDirectory.appending(path: "Imported", directoryHint: .isDirectory)
        let destination = directory.appending(path: "\(UUID().uuidString)-\(url.lastPathComponent)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
#endif
