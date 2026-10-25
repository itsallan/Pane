import DesignSystem
import Domain
import SwiftUI

/// A slim column on the trailing edge for what people reach for mid-film. Speed opens a row of rates that grows out of it.
struct QuickActionRail: View {
    @Bindable var model: PlayerModel

    static let rates = [0.5, 0.75, 1, 1.25, 1.5, 2]

    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: Metrics.glassMergeSpacing) {
            HStack(alignment: .center, spacing: Metrics.controlSpacing) {
                if model.isSpeedPickerPresented {
                    speedPicker
                }
                rail
            }
        }
        .animation(reduceMotion ? .quickFade : .spring(duration: 0.4, bounce: 0.2), value: model.isSpeedPickerPresented)
    }

    private var rail: some View {
        VStack(spacing: Metrics.railSpacing) {
            TransportButton("Audio and Subtitles", systemImage: "captions.bubble") {
                model.isTrackSheetPresented = true
            }
            speedButton
            if model.canUsePictureInPicture {
                TransportButton(
                    model.isPictureInPictureActive ? "Stop Picture in Picture" : "Start Picture in Picture",
                    systemImage: model.isPictureInPictureActive ? "pip.exit" : "pip.enter",
                    action: model.togglePictureInPicture
                )
            }
            more
        }
        .padding(Metrics.railSpacing)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("rail", in: glass)
    }

    private var speedButton: some View {
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
    }

    private var speedPicker: some View {
        HStack(spacing: Metrics.railSpacing) {
            ForEach(Self.rates, id: \.self) { rate in
                Button {
                    choose(rate)
                } label: {
                    Text(rate.rateLabel)
                        .font(.rateLabel)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, Metrics.controlSpacing)
                        .frame(minHeight: Metrics.minimumHitTarget)
                        .background(isCurrent(rate) ? Color.glassSelection : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.transport)
                .accessibilityAddTraits(isCurrent(rate) ? .isSelected : [])
            }
        }
        .padding(Metrics.railSpacing)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("speeds", in: glass)
        .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
    }

    @ViewBuilder
    private var more: some View {
        let button = TransportButton("Playback Options", systemImage: "ellipsis") {
            model.isMenuPresented = true
        }
        #if os(macOS)
        button
            .popover(isPresented: $model.isMenuPresented, arrowEdge: .leading) {
                OptionsPanel(model: model)
                    .frame(width: Metrics.optionsPopoverWidth, height: Metrics.optionsPopoverHeight)
            }
        #else
        button
        #endif
    }

    private func isCurrent(_ rate: Double) -> Bool {
        abs(model.rate - rate) < 0.01
    }

    private func toggleSpeedPicker() {
        model.isSpeedPickerPresented.toggle()
    }

    private func choose(_ rate: Double) {
        model.setRate(rate)
        model.isSpeedPickerPresented = false
    }
}
