import Domain
import Foundation

public actor FakeThumbnailProvider: ThumbnailProvider {
    public struct Request: Sendable, Hashable {
        public var source: MediaSource
        public var position: Duration
        public var maxPixelSize: Int
    }

    public private(set) var requests: [Request] = []
    private let directory: URL
    private let failure: PlaybackError?

    public init(directory: URL = URL(filePath: "/tmp/pane-fake-thumbnails"), failure: PlaybackError? = nil) {
        self.directory = directory
        self.failure = failure
    }

    public func thumbnail(for source: MediaSource, at position: Duration, maxPixelSize: Int) async throws(PlaybackError) -> URL {
        requests.append(Request(source: source, position: position, maxPixelSize: maxPixelSize))
        if let failure {
            throw failure
        }
        return directory.appending(path: "\(position.components.seconds).jpg")
    }
}
