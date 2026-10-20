import Foundation

public protocol ThumbnailProvider: Sendable {
    /// Returns a JPEG file URL.
    func thumbnail(for source: MediaSource, at position: Duration, maxPixelSize: Int) async throws(PlaybackError) -> URL
}
