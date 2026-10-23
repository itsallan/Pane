import DesignSystem
import Domain
import SwiftUI

/// Generic over its surface so the feature never sees how video is drawn: the app passes VLC's view, previews pass a color.
public struct PlayerScreen<Surface: View>: View {
    @Bindable private var model: PlayerModel
    private let onDismiss: (() -> Void)?
    private let surface: Surface

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    public init(model: PlayerModel, onDismiss: (() -> Void)? = nil, @ViewBuilder surface: () -> Surface) {
        self.model = model
        self.onDismiss = onDismiss
        self.surface = surface()
    }

    public var body: some View {
        ZStack {
            Color.mediaBackground
                .ignoresSafeArea()
            surface
                .ignoresSafeArea()
                .accessibilityHidden(true)
            interactionLayer
                .ignoresSafeArea()
            if model.subtitleAppearance.isEditing {
                SubtitleStylePreview(style: model.subtitleAppearance.style)
                    .ignoresSafeArea()
            }
            StatusOverlay(model: model)
            chrome
        }
        .animation(reduceMotion ? .linear(duration: 0.15) : .smooth(duration: 0.3), value: model.areControlsVisible)
        .animation(.smooth(duration: 0.2), value: model.isSpeedBoosted)
        .animation(.smooth(duration: 0.3), value: model.subtitleSync.phase)
        .animation(.smooth(duration: 0.3), value: model.subtitleAppearance.isEditing)
        .animation(.smooth(duration: 0.2), value: model.snapshot.outcome)
        .sheet(isPresented: $model.isTrackSheetPresented) {
            TrackSheet(model: model)
        }
        .task { await model.run() }
        .onChange(of: scenePhase) { _, phase in
            sceneDidChange(to: phase)
        }
        .persistentSystemOverlays(model.areControlsVisible ? .automatic : .hidden)
        #if os(iOS)
        .statusBarHidden(!model.areControlsVisible)
        #else
        // On the whole screen rather than the layer under the chrome, so pointing at the capsule doesn't count as leaving.
        .onContinuousHover { phase in
            switch phase {
            case .active: model.revealControls()
            case .ended: model.pointerDidLeave()
            }
        }
        #endif
    }

    @ViewBuilder
    private var interactionLayer: some View {
        #if os(iOS)
        PlaybackGestureLayer(model: model)
        #else
        Color.clear
            .contentShape(.rect)
            .onTapGesture(count: 2) { model.toggleVideoScaling() }
            .onTapGesture { model.toggleControls() }
            .accessibilityHidden(true)
        #endif
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            if model.areControlsVisible {
                TopBar(title: model.title, onDismiss: onDismiss, snapshot: model.snapshot)
                    .transition(chromeTransition(edge: .top))
            }
            if let outcome = model.snapshot.outcome {
                SnapshotToast(outcome: outcome)
                    .padding(.top, Metrics.controlSpacing)
                    .transition(.opacity)
            }
            // Up top, because libvlc draws subtitles along the bottom of the whole surface and the preview has to stay clear.
            if model.subtitleAppearance.isEditing {
                SubtitleStylePanel(appearance: model.subtitleAppearance)
                    .padding(.top, Metrics.controlSpacing)
                    .transition(chromeTransition(edge: .top))
            }
            Spacer(minLength: 0)
            if model.isSpeedBoosted {
                Label("2× Speed", systemImage: "forward.fill")
                    .font(.indicatorValue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
            if let range = model.loop.range, model.areControlsVisible, !model.subtitleAppearance.isEditing {
                LoopBadge(range: range, onClear: model.loop.clear)
                    .padding(.bottom, Metrics.controlSpacing)
                    .transition(.opacity)
            }
            if model.subtitleSync.isActive {
                SubtitleSyncPanel(sync: model.subtitleSync)
                    .transition(chromeTransition(edge: .bottom))
            } else if model.areControlsVisible, !model.subtitleAppearance.isEditing {
                ControlCapsule(model: model)
                    .transition(chromeTransition(edge: .bottom))
            }
        }
        .padding(.horizontal, Metrics.edgeInset)
        .padding(.bottom, 8)
    }

    private func sceneDidChange(to phase: ScenePhase) {
        switch phase {
        case .active: model.sceneDidBecomeActive()
        case .inactive: model.sceneDidResignActive()
        #if os(iOS)
        case .background: model.sceneDidEnterBackground(pausesVideo: true)
        #else
        case .background: model.sceneDidEnterBackground()
        #endif
        @unknown default: break
        }
    }

    private func chromeTransition(edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}

private struct TopBar: View {
    let title: String?
    let onDismiss: (() -> Void)?
    let snapshot: FrameSnapshot

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: Metrics.controlSpacing) {
                if let onDismiss {
                    TransportButton("Close", systemImage: "xmark", action: onDismiss)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                if let title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .frame(minHeight: Metrics.minimumHitTarget)
                        .glassEffect(.regular, in: .capsule)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 0)
                if snapshot.isAvailable {
                    TransportButton("Save Frame to Photos", systemImage: "camera", action: saveFrame)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .disabled(snapshot.isSaving)
                }
            }
        }
        .padding(.top, 8)
    }

    private func saveFrame() {
        Task { await snapshot.capture() }
    }
}

private struct StatusOverlay: View {
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
                .padding(24)
                .frame(maxWidth: 340)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .padding(Metrics.edgeInset)
                .accessibilityElement(children: .contain)
            } else if model.isBuffering && !model.isScrubbing {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 72, height: 72)
                    .glassEffect(.regular, in: .circle)
                    .accessibilityLabel("Loading")
            }
        }
        .transition(.opacity)
        .animation(.smooth(duration: 0.2), value: model.isBuffering)
    }
}
