import DesignSystem
import Domain
import SwiftUI

struct ControlCapsule: View {
    @Bindable var model: PlayerModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

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
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    HStack(spacing: 4) {
                        playPause
                        scrubber
                        tracks
                        options
                    }
                }
                .padding(6)
                .glassEffect(.regular, in: .rect(cornerRadius: 32))
            } else {
                HStack(spacing: 4) {
                    playPause
                    if showsSkipButtons {
                        skip(by: .zero - PlayerModel.skipInterval)
                        skip(by: PlayerModel.skipInterval)
                    }
                    elapsed
                        .padding(.leading, 4)
                    scrubber
                        .padding(.horizontal, 6)
                    remaining
                    tracks
                    options
                }
                .padding(6)
                .glassEffect(.regular, in: .capsule)
            }
        }
        .frame(maxWidth: Metrics.capsuleMaxWidth)
    }

    private var showsSkipButtons: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    private var playPause: some View {
        TransportButton(playPauseTitle, systemImage: playPauseSymbol) {
            model.togglePlayback()
        }
    }

    private var playPauseTitle: LocalizedStringKey {
        if model.isPlaybackActive { return "Pause" }
        return model.status == .ended ? "Play Again" : "Play"
    }

    private var playPauseSymbol: String {
        if model.isPlaybackActive { return "pause.fill" }
        return model.status == .ended ? "arrow.counterclockwise" : "play.fill"
    }

    private func skip(by offset: Duration) -> some View {
        let isForward = offset > .zero
        return TransportButton(
            isForward ? "Skip Forward 10 Seconds" : "Skip Back 10 Seconds",
            systemImage: isForward ? "goforward.10" : "gobackward.10"
        ) {
            model.skip(by: offset)
        }
        .disabled(!model.isSeekable)
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
        return PlayerModel.skipInterval / duration
    }

    private var accessibilityPosition: String {
        let position = model.position.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        guard let duration = model.duration else { return position }
        let total = duration.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return String(localized: "\(position) of \(total)")
    }

    private var tracks: some View {
        TransportButton("Audio and Subtitles", systemImage: "captions.bubble") {
            model.isTrackSheetPresented = true
        }
    }

    private var options: some View {
        TransportButton("Playback Options", systemImage: "ellipsis") {
            model.isMenuPresented = true
        }
        .popover(isPresented: $model.isMenuPresented, arrowEdge: .bottom) {
            OptionsPanel(model: model)
                .presentationCompactAdaptation(.popover)
        }
    }
}
