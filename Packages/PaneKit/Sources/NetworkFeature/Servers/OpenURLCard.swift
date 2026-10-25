import DesignSystem
import SwiftUI

/// The quickest way to play something not on a server, so it leads the page.
struct OpenURLCard: View {
    var body: some View {
        NavigationLink(value: NetworkRoute.openURL) {
            HStack(spacing: Metrics.edgeInset) {
                Image(systemName: "link")
                    .font(.title2.weight(.semibold))
                    .frame(width: Metrics.badgeSize + 12, height: Metrics.badgeSize + 12)
                    .background(.white.opacity(0.2), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open a Stream")
                        .font(.headline)
                    Text("Paste an HLS, RTSP or web address.")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.7)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(Metrics.edgeInset + 2)
            .background(Color.accentColor.gradient, in: .rect(cornerRadius: Metrics.heroCornerRadius))
            .contentShape(.rect(cornerRadius: Metrics.heroCornerRadius))
        }
        .buttonStyle(.plain)
    }
}
