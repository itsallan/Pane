import Domain
import Playback
import PlayerFeature

/// One open player: the engine, its drawable and the model. Built in an action, never in `body`,
/// so a redraw can't spawn a second engine.
final class PlayerSession: Identifiable {
    let model: PlayerModel
    let drawable: VideoDrawable

    init(item: MediaItem, dependencies: AppDependencies) {
        let (engine, drawable) = VLCPlaybackEngine.makeWithSurface(subtitleStyle: dependencies.subtitleStyle)
        self.drawable = drawable
        #if os(iOS)
        let brightness: (any ScreenBrightness)? = SceneScreenBrightness()
        #else
        let brightness: (any ScreenBrightness)? = nil
        #endif
        model = PlayerModel(
            engine: engine,
            item: item,
            resume: ResumePlayback(engine: engine, progress: dependencies.progress),
            saveProgress: SaveProgress(item: item.id, repository: dependencies.progress),
            pickTracks: PickPreferredTracks(engine: engine, preferences: dependencies.preferences),
            subtitleStyle: dependencies.subtitleStyle,
            saveSubtitleStyle: { await dependencies.saveSubtitleStyle($0) },
            thumbnails: dependencies.thumbnails,
            screenBrightness: brightness
        )
    }

    /// Saves progress, restores brightness and closes the engine.
    func close() async {
        await model.close()
    }
}
