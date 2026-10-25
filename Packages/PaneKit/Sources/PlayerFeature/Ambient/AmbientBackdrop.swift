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

private struct AmbientWash: View {
    let palette: AmbientPalette

    // A 3x3 mesh across the whole window is already softer than any blur would make it, and costs nothing per frame.
    private static let points: [SIMD2<Float>] = (0..<AmbientPalette.rows).flatMap { row in
        (0..<AmbientPalette.columns).map { column in
            SIMD2(Float(column) / Float(AmbientPalette.columns - 1), Float(row) / Float(AmbientPalette.rows - 1))
        }
    }

    var body: some View {
        MeshGradient(
            width: AmbientPalette.columns,
            height: AmbientPalette.rows,
            points: Self.points,
            colors: palette.swatches.map(\.washColor)
        )
        // Average colors come out muddy; a push in saturation brings back the hue people remember from the shot.
        .saturation(1.4)
        .overlay(Color.ambientScrim)
    }
}

extension AmbientPalette.Swatch {
    // Averaging a frame pulls every cell toward grey-brown, so lift each one toward a fixed brightness, keeping its hue.
    static let washBrightness = 0.7
    static let maximumLift = 3.0

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    var washColor: Color {
        let brightest = max(red, green, blue)
        guard brightest > 0.01 else { return color }
        let lift = min(max(Self.washBrightness / brightest, 1), Self.maximumLift)
        return Color(.sRGB, red: min(red * lift, 1), green: min(green * lift, 1), blue: min(blue * lift, 1))
    }
}

extension AmbientPalette {
    /// The most colorful swatch, faint enough to tint glass without hiding what's behind it.
    var accent: Color? {
        let vivid = swatches.max { $0.chroma < $1.chroma }
        guard let vivid, vivid.chroma > 0.08 else { return nil }
        return vivid.washColor.opacity(0.45)
    }
}

private extension AmbientPalette.Swatch {
    var chroma: Double {
        max(red, green, blue) - min(red, green, blue)
    }
}
