import Foundation

public protocol ThumbnailProvider: Sendable {
    /// Returns a 16:9 JPEG file URL, `maxPixelSize` wide and cropped to fill.
    func thumbnail(for source: MediaSource, at position: Duration, maxPixelSize: Int) async throws(PlaybackError) -> URL
}
