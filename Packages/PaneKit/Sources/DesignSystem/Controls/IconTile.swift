import SwiftUI

/// A symbol on a tinted rounded square, the way Settings marks each kind of row.
public struct IconTile: View {
    private let systemImage: String
    private let tint: Color

    @ScaledMetric(relativeTo: .body) private var size = Metrics.iconTileSize

    public init(systemImage: String, tint: Color) {
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: Metrics.iconTileCornerRadius))
            .accessibilityHidden(true)
    }
}
