import DesignSystem
import Domain
import SwiftUI

struct SubtitleCueRow: View {
    let cue: SubtitleCue
    let isNearest: Bool
    let onPick: (SubtitleCue) -> Void

    var body: some View {
        Button(action: pick) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(cue.start.timecode)
                    .font(.timecode)
                    .foregroundStyle(.secondary)
                Text(cue.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: Metrics.minimumHitTarget)
            .background(isNearest ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cue.text)
        .accessibilityValue(cue.start.timecode)
    }

    private func pick() {
        onPick(cue)
    }
}
