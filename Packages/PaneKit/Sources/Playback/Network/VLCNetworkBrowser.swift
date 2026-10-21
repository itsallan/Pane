import Domain
import Foundation
@preconcurrency import VLCKit

public actor VLCNetworkBrowser: NetworkBrowser {
    // Parsing a share blocks on the network; keep it and the discoverers off main and off the playback queue.
    private let queue = DispatchSerialQueue(label: "io.pane.player.network", qos: .userInitiated)
    public nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let credentials: any CredentialStore
    private let responder = LoginResponder.shared
    // The header says milliseconds, but 4.0.0-a25 passes the value through as microseconds (15000 timed out in 15 ms).
    private let parser = VLCMediaParser(library: .shared(), timeout: 15_000_000)
    private let bridge = DiscoveryBridge()
    private var discoverers: [VLCMediaDiscoverer] = []
    private var found: [URL: DiscoveredServer] = [:]
    private var subscribers: [UUID: AsyncStream<[NetworkServer]>.Continuation] = [:]

    public init(credentials: any CredentialStore) {
        self.credentials = credentials
        let events = bridge.events
        Task { [weak self] in
            for await event in events {
                await self?.handle(event)
            }
        }
    }

    isolated deinit {
        stopDiscovery()
        bridge.finish()
    }

    public nonisolated func servers() -> AsyncStream<[NetworkServer]> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: [NetworkServer].self, bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { _ in
            Task { await self.unsubscribe(id) }
        }
        Task { await subscribe(id, continuation) }
        return stream
    }

    public func contents(of server: NetworkServer, path: String) async throws(PlaybackError) -> [NetworkEntry] {
        let credential = try? await credentials.credential(for: server.id)
        let address: ShareAddress
        if server.kind == .upnp, path == "/" {
            guard let root = found.values.first(where: { $0.server.id == server.id })?.root else {
                throw .serverUnreachable(server.id)
            }
            address = ShareAddress(url: root)
        } else {
            address = try ShareAddress(server: server, path: path, credential: credential)
        }
        guard let media = VLCMedia(url: address.url) else { throw .serverUnreachable(server.id) }
        media.addOptions(address.options)

        let observer = ParseObserver()
        media.delegate = observer
        let request = responder.begin(host: server.host, credential: credential)
        defer { responder.end(request) }
        // doInteract lets the access module ask for a login, which the responder answers or turns into a rejection.
        guard parser.queue(media, options: [.parse, .doInteract]) == 0 else { throw .serverUnreachable(server.id) }
        for await _ in observer.finished {}

        switch media.parsedStatus {
        case .done:
            return entries(in: media, server: server)
        case .cancelled:
            throw .networkFailed
        default:
            throw responder.wasRejected(request) ? .authenticationRequired(server: server.id) : .serverUnreachable(server.id)
        }
    }
}

private extension VLCNetworkBrowser {
    func subscribe(_ id: UUID, _ continuation: AsyncStream<[NetworkServer]>.Continuation) {
        subscribers[id] = continuation
        continuation.yield(currentServers)
        if discoverers.isEmpty {
            startDiscovery()
        }
    }

    func unsubscribe(_ id: UUID) {
        subscribers[id] = nil
        if subscribers.isEmpty {
            stopDiscovery()
        }
    }

    // Discoverer names differ between libvlc builds (bonjour, upnp, dsm...), so start every LAN one
    // and keep whatever turns up with a scheme Pane can browse.
    func startDiscovery() {
        let available = VLCMediaDiscoverer.availableMediaDiscoverer(for: .LAN)
        for case let description as [String: Any] in available {
            guard let name = description[VLCMediaDiscovererName] as? String else { continue }
            let discoverer = VLCMediaDiscoverer(name: name)
            discoverer.delegate = bridge
            guard discoverer.start() == 0 else { continue }
            discoverers.append(discoverer)
        }
    }

    func stopDiscovery() {
        for discoverer in discoverers {
            discoverer.stop()
        }
        discoverers.removeAll()
    }

    func handle(_ event: DiscoveryEvent) {
        switch event {
        case .added(let discovered):
            found[discovered.root] = discovered
        case .removed(let url):
            found[url] = nil
        }
        let servers = currentServers
        for continuation in subscribers.values {
            continuation.yield(servers)
        }
    }

    // Bonjour and NetBIOS can both announce the same SMB machine; the stable ID collapses them.
    var currentServers: [NetworkServer] {
        var seen = Set<NetworkServer.ID>()
        return found.values
            .map(\.server)
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            .filter { seen.insert($0.id).inserted }
    }

    func entries(in media: VLCMedia, server: NetworkServer) -> [NetworkEntry] {
        guard let list = media.subitems else { return [] }
        var entries: [NetworkEntry] = []
        for index in 0..<max(list.count, 0) {
            guard let item = list.media(at: UInt(index)), let url = item.url else { continue }
            let path = server.kind == .upnp ? url.absoluteString : url.path(percentEncoded: false)
            let name = item.metaData.title.flatMap { $0.isEmpty ? nil : $0 } ?? url.lastPathComponent
            // Dot files are metadata (.DS_Store, ._ resource forks), never something to play.
            guard !name.hasPrefix(".") else { continue }
            var size: UInt64 = 0
            let hasSize = item.fileStatValue(for: .size, value: &size) == .success
            entries.append(NetworkEntry(
                name: name,
                path: path,
                isDirectory: item.mediaType == .directory,
                size: hasSize ? Int64(size) : nil
            ))
        }
        return entries
    }
}
