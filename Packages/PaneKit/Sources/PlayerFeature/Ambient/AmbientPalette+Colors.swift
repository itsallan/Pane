import Domain
import SwiftUI

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
