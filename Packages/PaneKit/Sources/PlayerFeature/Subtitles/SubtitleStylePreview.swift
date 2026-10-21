import Domain
import SwiftUI

/// A sample line drawn the way libvlc will render the chosen style: across the whole surface, near its bottom edge.
struct SubtitleStylePreview: View {
    let style: SubtitleStyle

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            // libvlc sizes text from the shorter side of the output; this ratio matches its default on iPhone and Mac.
            let fontSize = min(proxy.size.width, proxy.size.height) * 0.065 * style.size.previewScale
            Text("Subtitles will look like this.")
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: style.background == .none ? 2 : 0)
                .multilineTextAlignment(.center)
                .padding(.horizontal, fontSize * 0.3)
                .background(.black.opacity(backgroundOpacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, proxy.size.height * 0.03 + style.position.marginPixels / displayScale)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var backgroundOpacity: Double {
        switch style.background {
        case .none: 0
        case .translucent: 0.5
        case .solid: 1
        }
    }
}
