import Domain
import Playback
import PlayerFeature

/// One open player: the engine, its drawable and the model. Built in an action, never in `body`,
/// so a redraw can't spawn a second engine.
@MainActor
final class PlayerSession: Identifiable {
    let model: PlayerModel
    let drawable: VideoDrawable
    private let engine: VLCPlaybackEngine

    init(source: MediaSource, title: String, thumbnails: VLCThumbnailProvider) {
        let session = VLCPlaybackEngine.makeWithSurface()
        engine = session.engine
        drawable = session.drawable
        #if os(iOS)
        let brightness: (any ScreenBrightness)? = SceneScreenBrightness()
        #else
        let brightness: (any ScreenBrightness)? = nil
        #endif
        model = PlayerModel(engine: engine, source: source, title: title, thumbnails: thumbnails, screenBrightness: brightness)
    }

    func close() async {
        await engine.close()
    }
}
