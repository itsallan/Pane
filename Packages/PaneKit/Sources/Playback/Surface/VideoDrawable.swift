#if canImport(UIKit)
import UIKit

/// The view VLC renders into. It lives as long as its engine, so SwiftUI can rebuild the surface around it.
public final class VideoDrawable: UIView {
    /// Set by the engine's factory; VLC reaches it through the conformance below.
    var pictureInPicture: (media: PictureInPictureMedia, window: PictureInPictureWindow)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}
#else
import AppKit

/// The view VLC renders into. It lives as long as its engine, so SwiftUI can rebuild the surface around it.
public final class VideoDrawable: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .black
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
#endif
