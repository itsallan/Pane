import DesignSystem
import Domain
import SwiftUI

/// Errors, and the spinner while the controls (and the spinner in the play button) are hidden.
struct StatusOverlay: View {
    let model: PlayerModel

    var body: some View {
        Group {
            if let failure = model.failure {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    Text(failure.message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("Try Again", action: model.retry)
                        .buttonStyle(.glassProminent)
                }
                .padding(Metrics.panelPadding)
                .frame(maxWidth: Metrics.statusMaxWidth)
                .glassEffect(.regular, in: .rect(cornerRadius: Metrics.panelCornerRadius))
                .padding(Metrics.edgeInset)
                .accessibilityElement(children: .contain)
            } else if model.isBuffering && !model.isScrubbing && !model.areControlsVisible {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: Metrics.statusSpinnerSize, height: Metrics.statusSpinnerSize)
                    .glassEffect(.regular, in: .circle)
                    .accessibilityLabel("Loading")
            }
        }
        .transition(.opacity)
        .animation(.quickFade, value: model.isBuffering)
    }
}
