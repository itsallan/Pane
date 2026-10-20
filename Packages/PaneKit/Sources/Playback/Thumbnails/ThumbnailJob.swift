import CoreGraphics
import Domain
import Foundation
import ImageIO
import Synchronization
import UniformTypeIdentifiers
@preconcurrency import VLCKit

// Receives one thumbnailer's result on libvlc's parser thread and writes the JPEG there,
// so the CGImage never crosses into the actor.
final class ThumbnailJob: NSObject, Sendable {
    private enum Phase {
        case idle
        case waiting(CheckedContinuation<Result<URL, PlaybackError>, Never>)
        case done
    }

    private let destination: URL
    private let maxPixelSize: Int
    private let phase = Mutex(Phase.idle)

    init(destination: URL, maxPixelSize: Int) {
        self.destination = destination
        self.maxPixelSize = maxPixelSize
    }

    func start(_ continuation: CheckedContinuation<Result<URL, PlaybackError>, Never>) {
        let isDone = phase.withLock { phase in
            guard case .idle = phase else { return true }
            phase = .waiting(continuation)
            return false
        }
        if isDone {
            continuation.resume(returning: .failure(.thumbnailFailed))
        }
    }

    // VLCMediaThumbnailer.cancel drops the result without calling its delegate, so cancelling has to finish the job here.
    func cancel() {
        finish(.failure(.thumbnailFailed))
    }

    private func finish(_ result: Result<URL, PlaybackError>) {
        let continuation = phase.withLock { phase -> CheckedContinuation<Result<URL, PlaybackError>, Never>? in
            defer { phase = .done }
            guard case .waiting(let continuation) = phase else { return nil }
            return continuation
        }
        continuation?.resume(returning: result)
    }

    private func write(_ image: CGImage) -> Bool {
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            return false
        }
        let properties = [
            kCGImageDestinationLossyCompressionQuality: 0.75,
            kCGImageDestinationImageMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        CGImageDestinationAddImage(output, image, properties)
        return CGImageDestinationFinalize(output)
    }
}

extension ThumbnailJob: VLCMediaThumbnailerDelegate {
    func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer) {
        finish(.failure(.thumbnailFailed))
    }

    func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) {
        finish(write(thumbnail) ? .success(destination) : .failure(.thumbnailFailed))
    }
}
