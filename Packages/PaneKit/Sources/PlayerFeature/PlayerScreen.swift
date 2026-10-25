import DesignSystem
import Domain
import SwiftUI

/// Generic over its surface so the feature never sees how video is drawn: the app passes VLC's view, previews pass a color.
public struct PlayerScreen<Surface: View>: View {
    @Bindable private var model: PlayerModel
    private let onDismiss: (() -> Void)?
    private let surface: Surface

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    public init(model: PlayerModel, onDismiss: (() -> Void)? = nil, @ViewBuilder surface: () -> Surface) {
        self.model = model
        self.onDismiss = onDismiss
        self.surface = surface()
    }

    public var body: some View {
        ZStack {
            AmbientBackdrop(palette: model.ambient.palette)
                .ignoresSafeArea()
            VideoFrame(aspectRatio: videoAspectRatio) { surface }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            interactionLayer
                .ignoresSafeArea()
            StatusOverlay(model: model)
            PlayerChrome(model: model, onDismiss: onDismiss)
        }
        .animation(.chrome(reduceMotion: reduceMotion), value: model.areControlsVisible)
        .animation(.quickFade, value: model.isSpeedBoosted)
        .animation(.chrome, value: model.subtitleSync.phase)
        .animation(.quickFade, value: model.snapshot.outcome)
        .animation(.quickFade, value: model.resumeOffer)
        .sheet(isPresented: $model.isTrackSheetPresented) {
            TrackSheet(model: model)
                .preferredColorScheme(.dark)
        }
        #if os(iOS)
        .sheet(isPresented: $model.isMenuPresented) {
            OptionsSheet(model: model)
                .preferredColorScheme(.dark)
        }
        #endif
        // Video is watched in the dark whatever the system appearance; light glass over a black letterbox reads as grey plastic.
        .environment(\.colorScheme, .dark)
        .task { await model.run() }
        .task(id: samplesAmbientLight) {
            guard samplesAmbientLight else { return }
            await model.ambient.run(once: reduceMotion)
        }
        .onChange(of: scenePhase) { _, phase in
            sceneDidChange(to: phase)
        }
        .persistentSystemOverlays(model.areControlsVisible ? .automatic : .hidden)
        #if os(iOS)
        .statusBarHidden(!model.areControlsVisible)
        #else
        // On the whole screen rather than the layer under the chrome, so pointing at the controls doesn't count as leaving.
        .onContinuousHover { phase in
            switch phase {
            case .active: model.revealControls()
            case .ended: model.pointerDidLeave()
            }
        }
        #endif
    }

    // Sampling stops whenever nobody would see the wash change: paused, in the background, or with Reduce Transparency.
    private var samplesAmbientLight: Bool {
        model.isPlaying && model.hasVideo && scenePhase == .active && !reduceTransparency
    }

    // Fit mode sizes the surface to the picture, so letterboxing shows the ambient wash instead of VLC's black.
    // Fill and custom aspects crop inside VLC, which needs the whole window.
    private var videoAspectRatio: CGFloat? {
        guard model.videoScaling == .fit, let size = model.videoSize, size.width > 0, size.height > 0 else { return nil }
        return CGFloat(size.width) / CGFloat(size.height)
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
}

/// Centers the surface at the video's aspect ratio, or lets it fill the space when there isn't one.
private struct VideoFrame<Content: View>: View {
    let aspectRatio: CGFloat?
    @ViewBuilder let content: Content

    var body: some View {
        if let aspectRatio {
            content
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content
        }
    }
}
