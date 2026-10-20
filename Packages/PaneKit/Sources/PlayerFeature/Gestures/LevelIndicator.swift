import DesignSystem
import SwiftUI

/// A vertical glass gauge for volume and brightness. Volume can pass 100%, and the boost shows in its own color.
struct LevelIndicator: View {
    let title: LocalizedStringKey
    let systemImage: String
    let level: Double
    var maximum = 1.0

    @ScaledMetric(relativeTo: .headline) private var height = 160.0
    @ScaledMetric(relativeTo: .headline) private var width = 44.0

    var body: some View {
        VStack(spacing: 10) {
            Text(level, format: .percent.precision(.fractionLength(0)))
                .font(.indicatorValue)
            gauge
            Image(systemName: systemImage)
                .font(.headline)
                .symbolVariant(.fill)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(Text(level, format: .percent.precision(.fractionLength(0))))
    }

    private var gauge: some View {
        Capsule()
            .fill(Color.scrubberTrack)
            .overlay(alignment: .bottom) {
                GeometryReader { proxy in
                    let normal = min(level, 1) / maximum
                    let boost = max(level - 1, 0) / maximum
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle().fill(Color.levelBoost).frame(height: proxy.size.height * boost)
                        Rectangle().fill(Color.scrubberFill).frame(height: proxy.size.height * normal)
                    }
                }
                .clipShape(.capsule)
            }
            .frame(width: width / 3, height: height)
    }
}
