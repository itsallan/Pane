import DesignSystem
import Domain
import SwiftUI

/// A frame-shaped stand-in for a video, with the sample line drawn the way libvlc will draw it.
struct SubtitleStyleSample: View {
    let style: SubtitleStyle

    var body: some View {
        LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay { SubtitleStylePreview(style: style) }
            .clipShape(.rect(cornerRadius: Metrics.posterCornerRadius))
            .listRowInsets(EdgeInsets(
                top: Metrics.controlSpacing,
                leading: Metrics.controlSpacing,
                bottom: Metrics.controlSpacing,
                trailing: Metrics.controlSpacing
            ))
            .accessibilityHidden(true)
            .animation(.quickFade, value: style)
    }
}
