import DesignSystem
import Domain
import SwiftUI

/// The frame's colors spread across the window, so letterboxing and the glass over it carry the picture's light.
struct AmbientBackdrop: View {
    let palette: AmbientPalette?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.mediaBackground
            if !reduceTransparency, let palette {
                // Keyed by palette so each sample fades in over the last, rather than the mesh's points sliding.
                AmbientWash(palette: palette)
                    .id(palette)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .ambientFade, value: palette)
        .accessibilityHidden(true)
    }
}
