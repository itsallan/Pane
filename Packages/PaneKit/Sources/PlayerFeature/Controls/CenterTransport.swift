import DesignSystem
import Domain
import SwiftUI

/// Play and pause between the skip buttons, which split out of it as the controls appear.
struct CenterTransport: View {
    let model: PlayerModel

    @State private var isSpread = false
    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: Metrics.glassMergeSpacing) {
            // Folded, the skip buttons sit behind play, so the glass reads as one drop that then splits in three.
            HStack(spacing: isSpread ? Metrics.centerSpacing : -Metrics.centerSkipSize) {
                TransportButton(
                    "Skip Back \(skipSeconds) Seconds",
                    systemImage: "gobackward.\(skipSeconds)",
                    diameter: Metrics.centerSkipSize,
                    symbolFont: .centerSkipSymbol,
                    action: skipBack
                )
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("back", in: glass)
                .disabled(!model.isSeekable)
                .opacity(isSpread ? 1 : 0)
                CenterPlayButton(model: model)
                    .glassEffectID("play", in: glass)
                    .zIndex(1)
                TransportButton(
                    "Skip Forward \(skipSeconds) Seconds",
                    systemImage: "goforward.\(skipSeconds)",
                    diameter: Metrics.centerSkipSize,
                    symbolFont: .centerSkipSymbol,
                    action: skipForward
                )
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("forward", in: glass)
                .disabled(!model.isSeekable)
                .opacity(isSpread ? 1 : 0)
            }
        }
        .onAppear(perform: spread)
    }

    private var skipSeconds: Int {
        Int(model.skipInterval.components.seconds)
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

    private func skipBack() {
        model.skip(by: .zero - model.skipInterval)
    }

    private func skipForward() {
        model.skip(by: model.skipInterval)
    }
}
