import SwiftUI

/// Centers its content at an aspect ratio, or gives it all the space without one.
/// A layout rather than an `if`, so switching between fit and fill keeps the surface's identity and VLC's view with it.
struct VideoFrame: Layout {
    let aspectRatio: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = fittedSize(in: bounds.size)
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(size))
        }
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        guard let aspectRatio, aspectRatio > 0, container.height > 0 else { return container }
        if container.width / container.height > aspectRatio {
            return CGSize(width: container.height * aspectRatio, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / aspectRatio)
    }
}
