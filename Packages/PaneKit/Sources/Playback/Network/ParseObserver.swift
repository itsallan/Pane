import Foundation
@preconcurrency import VLCKit

// VLCKit calls this on libvlc's parser thread; it only signals, and the browser reads the media afterwards.
final class ParseObserver: NSObject, Sendable {
    let finished: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    override init() {
        (finished, continuation) = AsyncStream.makeStream(of: Void.self)
        super.init()
    }
}

extension ParseObserver: VLCMediaDelegate {
    func mediaDidFinishParsing(_ aMedia: VLCMedia) {
        continuation.yield()
        continuation.finish()
    }
}
