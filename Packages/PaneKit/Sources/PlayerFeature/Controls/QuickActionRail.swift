import DesignSystem
import Domain
import SwiftUI

/// A slim column on the trailing edge for what people reach for mid-film. Speed opens a row of rates that grows out of it.
struct QuickActionRail: View {
    @Bindable var model: PlayerModel

    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: Metrics.glassMergeSpacing) {
            HStack(alignment: .center, spacing: Metrics.controlSpacing) {
                if model.isSpeedPickerPresented {
                    SpeedPicker(current: model.rate, onChoose: choose)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID("speeds", in: glass)
                        .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
                }
                VStack(spacing: Metrics.railSpacing) {
                    TransportButton("Audio and Subtitles", systemImage: "captions.bubble", action: showTracks)
                    Button(action: toggleSpeedPicker) {
                        Text(model.rate.rateLabel)
                            .font(.rateLabel)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(minWidth: Metrics.minimumHitTarget, minHeight: Metrics.minimumHitTarget)
                            .contentShape(.circle)
                            .contentTransition(.numericText(value: model.rate))
                    }
                    .buttonStyle(.transport)
                    .accessibilityLabel("Playback Speed")
                    .accessibilityValue(model.rate.rateLabel)
                    .accessibilityHint("Shows playback speeds.")
                    if model.canUsePictureInPicture {
                        TransportButton(
                            model.isPictureInPictureActive ? "Stop Picture in Picture" : "Start Picture in Picture",
                            systemImage: model.isPictureInPictureActive ? "pip.exit" : "pip.enter",
                            action: model.togglePictureInPicture
                        )
                    }
                    TransportButton("Playback Options", systemImage: "ellipsis", action: showOptions)
                        #if os(macOS)
                        .popover(isPresented: $model.isMenuPresented, arrowEdge: .leading) {
                            OptionsPanel(model: model)
                                .frame(width: Metrics.optionsPopoverWidth, height: Metrics.optionsPopoverHeight)
                        }
                        #endif
                }
                .padding(Metrics.railSpacing)
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID("rail", in: glass)
            }
        }
        .animation(reduceMotion ? .quickFade : .spring(duration: 0.4, bounce: 0.2), value: model.isSpeedPickerPresented)
    }

    private func showTracks() {
        model.isTrackSheetPresented = true
    }

    private func showOptions() {
        model.isMenuPresented = true
    }

    private func toggleSpeedPicker() {
        model.isSpeedPickerPresented.toggle()
    }

    private func choose(_ rate: Double) {
        model.setRate(rate)
        model.isSpeedPickerPresented = false
    }
}
