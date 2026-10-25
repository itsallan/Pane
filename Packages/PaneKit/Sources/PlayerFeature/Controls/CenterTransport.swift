import DesignSystem
import Domain
import SwiftUI

/// Play and pause between the skip buttons, which split out of it as the controls appear.
struct CenterTransport: View {
    let model: PlayerModel

    @State private var isSpread = false
    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var playSize = Metrics.centerPlaySize

    var body: some View {
        GlassEffectContainer(spacing: Metrics.glassMergeSpacing) {
            // Folded, the skip buttons sit behind play, so the glass reads as one drop that then splits in three.
            HStack(spacing: isSpread ? Metrics.centerSpacing : -Metrics.centerSkipSize) {
                skip(forward: false)
                playPause
                    .zIndex(1)
                skip(forward: true)
            }
        }
        .onAppear(perform: spread)
    }

    private func spread() {
        guard !reduceMotion else {
            isSpread = true
            return
        }
        withAnimation(.spring(duration: 0.5, bounce: 0.3).delay(0.05)) {
            isSpread = true
        }
    }

    private var playPause: some View {
        Button(action: model.togglePlayback) {
            Group {
                if model.isBuffering && !model.isScrubbing {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: playPauseSymbol)
                        .font(.centerPlaySymbol)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: playSize, height: playSize)
            .contentShape(.circle)
        }
        .buttonStyle(.transport)
        .glassEffect(.regular.tint(model.ambient.palette?.accent).interactive(), in: .circle)
        .glassEffectID("play", in: glass)
        .accessibilityLabel(playPauseTitle)
    }

    private func skip(forward: Bool) -> some View {
        let seconds = Int(model.skipInterval.components.seconds)
        return TransportButton(
            forward ? "Skip Forward \(seconds) Seconds" : "Skip Back \(seconds) Seconds",
            systemImage: forward ? "goforward.\(seconds)" : "gobackward.\(seconds)",
            diameter: Metrics.centerSkipSize,
            symbolFont: .centerSkipSymbol
        ) {
            model.skip(by: forward ? model.skipInterval : .zero - model.skipInterval)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID(forward ? "forward" : "back", in: glass)
        .disabled(!model.isSeekable)
        .opacity(isSpread ? 1 : 0)
    }

    private var playPauseTitle: LocalizedStringKey {
        if model.isPlaybackActive { return "Pause" }
        return model.status == .ended ? "Play Again" : "Play"
    }

    private var playPauseSymbol: String {
        if model.isPlaybackActive { return "pause.fill" }
        return model.status == .ended ? "arrow.counterclockwise" : "play.fill"
    }
}
