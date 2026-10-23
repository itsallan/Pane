#if os(iOS)
@preconcurrency import VLCKit

// VLC's sample buffer video output looks for this on the drawable and, where AVKit allows Picture in Picture,
// sets up a controller for it. It asks for both on the main queue. The iPhone simulator never allows it;
// the iPad simulator and devices do.
extension VideoDrawable: @preconcurrency VLCPictureInPictureDrawable {
    public func mediaController() -> (any VLCPictureInPictureMediaControlling)! {
        pictureInPicture?.media
    }

    public func pictureInPictureReady() -> (((any VLCPictureInPictureWindowControlling)?) -> Void)! {
        let window = pictureInPicture?.window
        return { controller in
            guard let controller else { return }
            MainActor.assumeIsolated {
                window?.attach(controller)
            }
        }
    }
}
#endif
