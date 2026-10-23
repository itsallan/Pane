#if os(iOS)
import Foundation
@preconcurrency import VLCKit

/// Holds the controller VLC hands over once its video output can do Picture in Picture.
/// There's none for audio-only media, or before the first frame.
@MainActor
final class PictureInPictureWindow {
    private var controller: (any VLCPictureInPictureWindowControlling)?
    private let onEvent: @Sendable (PictureInPictureEvent) -> Void

    nonisolated init(onEvent: @escaping @Sendable (PictureInPictureEvent) -> Void) {
        self.onEvent = onEvent
    }

    func attach(_ controller: any VLCPictureInPictureWindowControlling) {
        self.controller = controller
        let onEvent = onEvent
        controller.stateChangeEventHandler = { @Sendable isStarted in
            onEvent(.activeChanged(isStarted))
        }
        onEvent(.ready)
    }

    func start() {
        controller?.startPictureInPicture()
    }

    func stop() {
        controller?.stopPictureInPicture()
    }

    func invalidate() {
        controller?.invalidatePlaybackState()
    }
}
#endif
