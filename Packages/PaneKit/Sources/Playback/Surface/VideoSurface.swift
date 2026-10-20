import SwiftUI

// The representable is disposable; the drawable is not. If VLC's drawable is freed mid-playback it tears down
// its video output and the picture goes black, so each container only borrows the drawable.
#if canImport(UIKit)
public struct VideoSurface: UIViewRepresentable {
    private let drawable: VideoDrawable

    public init(_ drawable: VideoDrawable) {
        self.drawable = drawable
    }

    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true
        return container
    }

    public func updateUIView(_ container: UIView, context: Context) {
        guard drawable.superview !== container else { return }
        drawable.frame = container.bounds
        container.addSubview(drawable)
    }

    public static func dismantleUIView(_ container: UIView, coordinator: ()) {
        // A newer container may already have taken the drawable; only let go if it's still ours.
        for case let drawable as VideoDrawable in container.subviews {
            drawable.removeFromSuperview()
        }
    }
}
#else
public struct VideoSurface: NSViewRepresentable {
    private let drawable: VideoDrawable

    public init(_ drawable: VideoDrawable) {
        self.drawable = drawable
    }

    public func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = .black
        return container
    }

    public func updateNSView(_ container: NSView, context: Context) {
        guard drawable.superview !== container else { return }
        drawable.frame = container.bounds
        container.addSubview(drawable)
    }

    public static func dismantleNSView(_ container: NSView, coordinator: ()) {
        // A newer container may already have taken the drawable; only let go if it's still ours.
        for case let drawable as VideoDrawable in container.subviews {
            drawable.removeFromSuperview()
        }
    }
}
#endif
