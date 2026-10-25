import SwiftUI

/// A gradient picked from the title, so a video without a frame yet still looks like part of the shelf
/// and keeps the same colors every launch.
struct PosterPlaceholder: View {
    let title: String

    var body: some View {
        LinearGradient(colors: [hue.opacity(0.85), hue.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.75))
            }
    }

    // String.hashValue changes per launch; a sum of scalars doesn't.
    private var hue: Color {
        let seed = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return Color(hue: Double(seed % 360) / 360, saturation: 0.45, brightness: 0.6)
    }
}
