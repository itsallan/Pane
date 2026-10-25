import Domain
import Playback
import PlayerFeature
#if os(iOS)
import UIKit
#endif

/// One open player: the engine, its drawable and the model. Built in an action, never in `body`,
/// so a redraw can't spawn a second engine.
final class PlayerSession: Identifiable {
    let item: MediaItem
    let model: PlayerModel
    let drawable: VideoDrawable
    /// For system integration that follows the engine's state directly; the UI goes through `model`.
    let engine: any PlaybackEngine
    /// Handoff passes a share's server by address, and the activity has to be filled in synchronously.
    private(set) var server: NetworkServer?

    init(item: MediaItem, dependencies: AppDependencies) {
        let (engine, drawable) = VLCPlaybackEngine.makeWithSurface(
            subtitleStyle: dependencies.subtitleStyle,
            servers: dependencies.servers,
            credentials: dependencies.credentials
        )
        self.item = item
        self.engine = engine
        self.drawable = drawable
        #if os(iOS)
        let brightness: (any ScreenBrightness)? = SceneScreenBrightness()
        // An iPad shares its screen with other apps in multitasking, so it can't force an orientation.
        let orientation: (any ScreenOrientation)? = UIDevice.current.userInterfaceIdiom == .phone ? SceneOrientation() : nil
        #else
        let brightness: (any ScreenBrightness)? = nil
        let orientation: (any ScreenOrientation)? = nil
        #endif
        model = PlayerModel(
            engine: engine,
            item: item,
            resume: ResumePlayback(engine: engine, progress: dependencies.progress),
            saveProgress: SaveProgress(item: item.id, repository: dependencies.progress),
            pickTracks: PickPreferredTracks(engine: engine, preferences: dependencies.preferences),
            preferences: dependencies.preferences,
            thumbnails: dependencies.thumbnails,
            screenBrightness: brightness,
            screenOrientation: orientation,
            photoLibrary: SystemPhotoLibrary()
        )
        if case .networkShare(let serverID, _) = item.source {
            Task { [servers = dependencies.servers] in
                server = try? await servers.server(withID: serverID)
            }
        }
    }

    /// Saves progress, restores brightness and closes the engine.
    func close() async {
        await model.close()
    }
}
