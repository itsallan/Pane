import DesignSystem
import Domain
import SwiftUI

/// Everything drawn over the video: title up top, transport in the middle, the timeline along the bottom
/// and the quick actions on the trailing edge.
struct PlayerChrome: View {
    let model: PlayerModel
    let onDismiss: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height
            ZStack {
                if showsTransport {
                    CenterTransport(model: model)
                        .transition(clusterTransition)
                }
                VStack(spacing: Metrics.controlSpacing) {
                    top
                    Spacer(minLength: 0)
                    if isWide {
                        bottom
                    } else {
                        // Portrait has room under the picture, so the rail sits just above the timeline instead of over the video.
                        HStack {
                            Spacer(minLength: 0)
                            rail
                        }
                        bottom
                    }
                }
                if isWide {
                    HStack {
                        Spacer(minLength: 0)
                        rail
                    }
                }
            }
            .padding(.horizontal, edgeInset)
            .padding(.top, isCompactHeight ? Metrics.compactEdgeInset : Metrics.controlSpacing)
            .padding(.bottom, isCompactHeight ? 0 : Metrics.controlSpacing)
        }
    }

    private var isCompactHeight: Bool {
        #if os(iOS)
        verticalSizeClass == .compact
        #else
        false
        #endif
    }

    private var edgeInset: CGFloat {
        isCompactHeight ? Metrics.compactEdgeInset : Metrics.edgeInset
    }

    private var showsControls: Bool {
        model.areControlsVisible && !model.subtitleSync.isActive
    }

    private var showsTransport: Bool {
        showsControls && model.failure == nil
    }

    @ViewBuilder
    private var top: some View {
        if model.areControlsVisible {
            TopBar(title: model.title, onDismiss: onDismiss)
                .transition(edgeTransition(.top))
        }
        if let outcome = model.snapshot.outcome {
            SnapshotToast(outcome: outcome)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var rail: some View {
        if showsControls {
            QuickActionRail(model: model)
                .transition(edgeTransition(.trailing))
        }
    }

    @ViewBuilder
    private var bottom: some View {
        if model.isSpeedBoosted {
            Label("2× Speed", systemImage: "forward.fill")
                .font(.indicatorValue)
                .padding(.horizontal, Metrics.edgeInset)
                .frame(minHeight: Metrics.minimumHitTarget)
                .glassEffect(.regular, in: .capsule)
                .transition(.opacity)
        }
        if let offer = model.resumeOffer {
            ResumeOfferButton(position: offer, onResume: model.acceptResumeOffer, onDismiss: model.dismissResumeOffer)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
        if let range = model.loop.range, model.areControlsVisible {
            LoopBadge(range: range, onClear: model.loop.clear)
                .transition(.opacity)
        }
        if model.subtitleSync.isActive {
            SubtitleSyncPanel(sync: model.subtitleSync)
                .transition(edgeTransition(.bottom))
        } else if model.areControlsVisible {
            ScrubberBar(model: model)
                .transition(edgeTransition(.bottom))
        }
    }

    private func edgeTransition(_ edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }

    private var clusterTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity)
    }
}
