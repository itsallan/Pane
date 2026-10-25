import DesignSystem
import Domain
import SwiftUI

struct AmbientWash: View {
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
