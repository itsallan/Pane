import CoreGraphics
import CryptoKit
import Domain
import Foundation
@preconcurrency import VLCKit

public actor VLCThumbnailProvider: ThumbnailProvider {
    fileprivate struct Key: Hashable {
        let source: String
        let second: Int64
        let maxPixelSize: Int

        var fileName: String {
            let digest = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
            return "\(digest)-\(second)-\(maxPixelSize)w.jpg"
        }
    }

    fileprivate struct Request {
        let id = UUID()
        let task: Task<Result<URL, PlaybackError>, Never>
        var waiters = 1
        var abandoned = 0
    }

    private static let bucketSeconds: Int64 = 5

    private let directory: URL
    private let servers: (any NetworkServerRepository)?
    private let credentials: (any CredentialStore)?
    private var index: [Key: URL] = [:]
    private var requests: [Key: Request] = [:]

    /// `servers` and `credentials` let it open `.networkShare` sources; without them, shares fail with `.unknownServer`.
    public init(
        directory: URL = .cachesDirectory.appending(path: "Thumbnails", directoryHint: .isDirectory),
        servers: (any NetworkServerRepository)? = nil,
        credentials: (any CredentialStore)? = nil
    ) {
        self.directory = directory
        self.servers = servers
        self.credentials = credentials
    }

    public func thumbnail(for source: MediaSource, at position: Duration, maxPixelSize: Int) async throws(PlaybackError) -> URL {
        let second = max(position.components.seconds, 0) / Self.bucketSeconds * Self.bucketSeconds
        let key = Key(source: Self.identity(of: source), second: second, maxPixelSize: maxPixelSize)
        if let url = cachedFile(for: key) {
            return url
        }

        let request: Request
        if var existing = requests[key] {
            existing.waiters += 1
            request = existing
        } else {
            request = Request(task: Task { await render(key, source: source) })
        }
        requests[key] = request

        let task = request.task
        let id = request.id
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { await self.abandon(key, id: id) }
        }
        return try result.get()
    }
}

private extension VLCThumbnailProvider {
    static func identity(of source: MediaSource) -> String {
        switch source {
        case .stream(let url): "stream:\(url.absoluteString)"
        case .file(let bookmark): "file:\(bookmark.base64EncodedString())"
        case .networkShare(let server, let path): "share:\(server.uuidString):\(path)"
        }
    }

    func cachedFile(for key: Key) -> URL? {
        let url = index[key] ?? directory.appending(path: key.fileName)
        // The system purges Caches whenever it likes, so the index is only a hint.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            index[key] = nil
            return nil
        }
        index[key] = url
        return url
    }

    // A shared request is only cancelled once every caller waiting on it has gone.
    func abandon(_ key: Key, id: UUID) {
        guard var request = requests[key], request.id == id else { return }
        request.abandoned += 1
        if request.abandoned >= request.waiters {
            request.task.cancel()
        }
        requests[key] = request
    }

    func render(_ key: Key, source: MediaSource) async -> Result<URL, PlaybackError> {
        defer { requests[key] = nil }
        let resolved: ResolvedShare?
        let location: MediaLocation
        do {
            resolved = try await ResolvedShare(source, servers: servers, credentials: credentials)
            location = try MediaLocation(source, share: resolved?.address)
        } catch {
            return .failure(error)
        }
        defer { location.relinquish() }
        // The thumbnailer runs on the shared libvlc instance, whose responder would otherwise hand this
        // share's login prompt to whichever playback request happens to be open.
        let login = resolved.map { LoginResponder.shared.begin(host: $0.server.host, credential: $0.credential) }
        defer { login.map(LoginResponder.shared.end) }
        guard let media = location.makeMedia(),
              (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil
        else {
            return .failure(.thumbnailFailed)
        }

        // avcodec shows corrupted frames by default. A seek in a file without a usable index (Matroska over HTTP)
        // lands mid-GOP, and the thumbnailer grabs the first picture out: grey, with smears where references are missing.
        media.addOption(":avcodec-corrupted=0")
        let job = ThumbnailJob(destination: directory.appending(path: key.fileName), maxPixelSize: key.maxPixelSize)
        let thumbnailer = VLCMediaThumbnailer(media: media, delegate: job, andVLCLibrary: nil)
        thumbnailer.snapshotTime = VLCTime(.seconds(key.second))
        // VLCKit stretches the frame to whatever box it's given, so crop to the 16:9 every caller draws into.
        thumbnailer.thumbnailWidth = CGFloat(key.maxPixelSize)
        thumbnailer.thumbnailHeight = CGFloat(key.maxPixelSize * 9 / 16)
        thumbnailer.cropsToFit = true
        thumbnailer.hardwareDecodingEnabled = true
        // A fast seek snaps to a keyframe, which is often the black first frame of the file.
        thumbnailer.preciseSeek = true

        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                job.start(continuation)
                thumbnailer.fetchThumbnail()
            }
        } onCancel: {
            job.cancel()
        }
        // The thumbnailer's delegate is weak and libvlc may still be decoding; keep both alive until it's told to stop.
        withExtendedLifetime(job) {
            thumbnailer.cancel()
        }
        if case .success(let url) = result {
            index[key] = url
        }
        return result
    }
}
