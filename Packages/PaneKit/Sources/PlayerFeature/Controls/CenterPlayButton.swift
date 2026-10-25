import DesignSystem
import Domain
import SwiftUI

/// The big play and pause button, tinted with the frame's most vivid color. Shows the spinner while buffering.
struct CenterPlayButton: View {
    let model: PlayerModel

    @ScaledMetric(relativeTo: .largeTitle) private var size = Metrics.centerPlaySize

    var body: some View {
        Button(action: model.togglePlayback) {
            ZStack {
                ProgressView()
                    .controlSize(.large)
                    .opacity(showsSpinner ? 1 : 0)
                Image(systemName: symbol)
                    .font(.centerPlaySymbol)
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(showsSpinner ? 0 : 1)
            }
            .frame(width: size, height: size)
            .contentShape(.circle)
        }
        .buttonStyle(.transport)
        .glassEffect(.regular.tint(model.ambient.palette?.accent).interactive(), in: .circle)
        .accessibilityLabel(title)
    }

    private var showsSpinner: Bool {
        model.isBuffering && !model.isScrubbing
    }

    private var title: LocalizedStringKey {
        if model.isPlaybackActive { return "Pause" }
        return model.status == .ended ? "Play Again" : "Play"
    }

    private var symbol: String {
        if model.isPlaybackActive { return "pause.fill" }
        return model.status == .ended ? "arrow.counterclockwise" : "play.fill"
    }
}
