import DesignSystem
import SwiftUI

/// Sits above the capsule while a loop runs, so it's obvious why playback keeps jumping back.
struct LoopBadge: View {
    let range: ClosedRange<Duration>
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Label("\(range.lowerBound.timecode)–\(range.upperBound.timecode)", systemImage: "repeat")
                .font(.indicatorValue)
                .padding(.leading, 14)
            Button("Clear A-B Loop", systemImage: "xmark", action: onClear)
                .labelStyle(.iconOnly)
                .frame(width: Metrics.minimumHitTarget, height: Metrics.minimumHitTarget)
                .contentShape(.circle)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A-B loop from \(range.lowerBound.timecode) to \(range.upperBound.timecode)")
    }
}
