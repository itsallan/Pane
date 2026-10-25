#if os(iOS)
import DesignSystem
import Domain
import SwiftUI

/// The invisible layer over the video that turns touches into playback commands.
struct PlaybackGestureLayer: View {
    let model: PlayerModel

    private enum Pan {
        case scrub(fraction: Double, translation: CGFloat)
        case volume(start: Double)
        case brightness(start: Double)
    }

    @State private var pan: Pan?
    @State private var seekFeedback: SeekFeedback?
    @GestureState private var isBoostHeld = false

    // Dragging this share of the height covers the whole 0...1 range.
    private static let levelTravel = 0.7
    private static let precision = ScrubPrecision.standard

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(.rect)
                // Without double-tap seeking, a single tap shouldn't wait out the double-tap window.
                .gesture(taps(in: proxy.size), isEnabled: model.gestures.doubleTapSeeks)
                .gesture(singleTap, isEnabled: !model.gestures.doubleTapSeeks)
                .simultaneousGesture(panGesture(in: proxy.size))
                .simultaneousGesture(pinch)
                .simultaneousGesture(speedBoost, isEnabled: model.gestures.longPressSpeedsUp)
                .overlay {
                    if let seekFeedback {
                        SeekFeedbackView(feedback: seekFeedback)
                            .id(seekFeedback.id)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .trailing) {
                    if case .volume = pan {
                        LevelIndicator(title: "Volume", systemImage: "speaker.wave.2", level: model.volume, maximum: model.maximumVolume)
                            .padding(.trailing, Metrics.edgeInset * 2)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .leading) {
                    if case .brightness = pan, let brightness = model.brightness {
                        LevelIndicator(title: "Brightness", systemImage: "sun.max", level: brightness)
                            .padding(.leading, Metrics.edgeInset * 2)
                            .transition(.opacity)
                    }
                }
        }
        .animation(.easeOut(duration: 0.2), value: seekFeedback?.id)
        .animation(.easeOut(duration: 0.2), value: pan == nil)
        .onChange(of: isBoostHeld) { _, isHeld in
            isHeld ? model.beginSpeedBoost() : model.endSpeedBoost()
        }
        .task(id: seekFeedback?.id) {
            guard seekFeedback != nil else { return }
            try? await Task.sleep(for: .milliseconds(700))
            seekFeedback = nil
        }
        .accessibilityElement()
        .accessibilityLabel("Video")
        .accessibilityHint("Shows or hides the playback controls.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.toggleControls() }
        .accessibilityAction(named: "Skip Back \(skipSeconds) Seconds") { model.skip(by: .zero - model.skipInterval) }
        .accessibilityAction(named: "Skip Forward \(skipSeconds) Seconds") { model.skip(by: model.skipInterval) }
        .accessibilityAction(named: model.videoScaling == .fill ? "Fit Video to Screen" : "Fill Screen with Video") {
            model.toggleVideoScaling()
        }
    }

    private var skipSeconds: Int {
        Int(model.skipInterval.components.seconds)
    }

    private func taps(in size: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { tap in doubleTap(at: tap.location, in: size) }
            .exclusively(before: singleTap)
    }

    private var singleTap: some Gesture {
        SpatialTapGesture().onEnded { _ in model.toggleControls() }
    }

    private func doubleTap(at location: CGPoint, in size: CGSize) {
        guard model.isSeekable else { return }
        let side: SeekFeedback.Side = location.x < size.width / 2 ? .leading : .trailing
        model.skip(by: side == .leading ? .zero - model.skipInterval : model.skipInterval)
        var next = SeekFeedback(side: side, location: location, seconds: skipSeconds)
        if let seekFeedback, seekFeedback.side == side {
            next.seconds += seekFeedback.seconds
        }
        seekFeedback = next
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { drag in
                guard !model.isSpeedBoosted else { return }
                guard let pan else {
                    beginPan(drag, in: size)
                    return
                }
                switch pan {
                case .scrub(let fraction, let translation):
                    let delta = (drag.translation.width - translation) / size.width
                    let next = min(max(fraction + delta * Self.precision.scale(forSpeed: drag.velocity.width), 0), 1)
                    self.pan = .scrub(fraction: next, translation: drag.translation.width)
                    model.scrub(toFraction: next)
                case .volume(let start):
                    model.setVolume(start + level(for: drag, in: size))
                case .brightness(let start):
                    model.setBrightness(start + level(for: drag, in: size))
                }
            }
            .onEnded { _ in
                switch pan {
                case .scrub: model.endScrub()
                case .volume: model.endVolumeAdjustment()
                case .brightness, nil: break
                }
                pan = nil
            }
    }

    private func beginPan(_ drag: DragGesture.Value, in size: CGSize) {
        let isHorizontal = abs(drag.translation.width) > abs(drag.translation.height)
        if isHorizontal {
            guard model.canScrub else { return }
            model.beginScrub()
            pan = .scrub(fraction: model.fraction, translation: drag.translation.width)
        } else if !model.gestures.adjustsBrightnessAndVolume {
            return
        } else if drag.startLocation.x >= size.width / 2 {
            model.beginVolumeAdjustment()
            pan = .volume(start: model.volume)
        } else if let brightness = model.brightness {
            pan = .brightness(start: brightness)
        }
    }

    private func level(for drag: DragGesture.Value, in size: CGSize) -> Double {
        -drag.translation.height / (size.height * Self.levelTravel)
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onEnded { pinch in
                let wantsFill = pinch.magnification > 1.15
                let wantsFit = pinch.magnification < 0.87
                if wantsFill && model.videoScaling != .fill || wantsFit && model.videoScaling == .fill {
                    model.toggleVideoScaling()
                }
            }
    }

    private var speedBoost: some Gesture {
        LongPressGesture(minimumDuration: 0.4, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($isBoostHeld) { value, isHeld, _ in
                if case .second(true, _) = value {
                    isHeld = true
                }
            }
    }
}
#endif
