import Foundation
@preconcurrency import VLCKit

enum DiscoveryEvent: Sendable {
    case added(DiscoveredServer)
    case removed(URL)
}

// Discoverer callbacks arrive on libvlc's event thread. The media is only read here, to copy out Sendable values.
final class DiscoveryBridge: NSObject, Sendable {
    let events: AsyncStream<DiscoveryEvent>
    private let continuation: AsyncStream<DiscoveryEvent>.Continuation

    override init() {
        (events, continuation) = AsyncStream.makeStream(of: DiscoveryEvent.self)
        super.init()
    }

    func finish() {
        continuation.finish()
    }
}

extension DiscoveryBridge: VLCMediaDiscovererDelegate {
    func mediaAdded(_ media: VLCMedia, parent: VLCMedia?) {
        guard parent == nil, let server = DiscoveredServer(media) else { return }
        continuation.yield(.added(server))
    }

    func mediaRemoved(_ media: VLCMedia) {
        guard let url = media.url else { return }
        continuation.yield(.removed(url))
    }
}
