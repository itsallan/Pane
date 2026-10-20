import DesignSystem
import SwiftUI

struct EntryProgressBar: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.35))
            .overlay {
                Capsule()
                    .fill(.white)
                    .scaleEffect(x: fraction, anchor: .leading)
            }
            .clipShape(.capsule)
            .frame(height: Metrics.progressBarHeight)
            .shadow(color: .black.opacity(0.3), radius: 2)
            .accessibilityHidden(true)
    }
}
