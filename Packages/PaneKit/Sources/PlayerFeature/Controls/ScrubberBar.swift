import DesignSystem
import Domain
import SwiftUI

/// The timeline in its own floating capsule, with the times on either side.
struct ScrubberBar: View {
    let model: PlayerModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // The timecodes would squeeze the scrubber to nothing at these sizes, so they get their own row.
                VStack(spacing: 0) {
                    HStack {
                        elapsed
                        Spacer()
                        remaining
                    }
                    .padding(.horizontal, Metrics.edgeInset)
                    .padding(.top, Metrics.controlSpacing)
                    scrubber
                        .padding(.horizontal, Metrics.controlSpacing)
                }
                .padding(Metrics.capsulePadding)
                .glassEffect(.regular, in: .rect(cornerRadius: Metrics.panelCornerRadius))
            } else {
                HStack(spacing: Metrics.controlSpacing) {
                    elapsed
                    scrubber
                    remaining
                }
                .padding(.horizontal, Metrics.edgeInset)
                .padding(.vertical, Metrics.capsulePadding)
                .glassEffect(.regular, in: .capsule)
            }
        }
        .frame(maxWidth: Metrics.capsuleMaxWidth)
    }

    private var elapsed: some View {
        Text(model.position.timecode)
            .font(.timecode)
            .accessibilityHidden(true)
    }

    private var remaining: some View {
        Text(remainingText)
            .font(.timecode)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    private var remainingText: String {
        guard let duration = model.duration else { return "--:--" }
        return "-" + max(duration - model.position, .zero).timecode
    }

    private var scrubber: some View {
        Scrubber(
            value: model.fraction,
            isEditing: model.isScrubbing,
            chapterMarks: chapterMarks,
            accessibilityStep: accessibilityStep,
            accessibilityValue: accessibilityPosition,
            onEditingChanged: { $0 ? model.beginScrub() : model.endScrub() },
            onChange: { model.scrub(toFraction: $0) }
        ) {
            ScrubPreview(thumbnail: model.scrubThumbnail, position: model.position, chapterTitle: model.currentChapter?.displayName)
        }
        .disabled(!model.canScrub)
        .accessibilityLabel("Playback Position")
    }

    private var chapterMarks: [Double] {
        guard let duration = model.duration, duration > .zero else { return [] }
        return model.chapters.map { $0.start / duration }
    }

    private var accessibilityStep: Double {
        guard let duration = model.duration, duration > .zero else { return 0.05 }
        return model.skipInterval / duration
    }

    private var accessibilityPosition: String {
        let position = model.position.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        guard let duration = model.duration else { return position }
        let total = duration.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return String(localized: "\(position) of \(total)")
    }
}
