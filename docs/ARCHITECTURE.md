# Pane architecture

Decisions made before the first line of code, and why. When code disagrees with this file, fix one of them in the same commit.

## Constraints that shape everything

- Swift 6, strict concurrency complete. No `@unchecked Sendable` without a written justification.
- SwiftUI and Observation only. Deployment target 26 everywhere.
- Clean Architecture in `Packages/PaneKit`. Dependencies point inward. `Domain` imports Foundation only.
- Features depend on `Domain` and `DesignSystem`. They never import `Playback`, `Data` or VLCKit.
- Primary pattern: Clean Architecture (the engine must be swappable for a fake). Per screen: one view plus one `@Observable` model. Routing lives in the app target.

## Module graph

```
                              App targets (iOS/iPadOS, macOS)
        ┌──────────────┬──────────────┬──────┴───────┬──────────────┬───────────────┐
        ▼              ▼              ▼              ▼              ▼               ▼
   PlayerFeature  LibraryFeature  NetworkFeature  SettingsFeature  Playback        Data
        │              │              │              │          (VLCKit)     (SwiftData, Keychain)
        └──────────────┴──────┬───────┴──────────────┘              │               │
                ┌─────────────┴─────────────┐                       │               │
                ▼                           ▼                       │               │
          DesignSystem                   Domain ◀───────────────────┴───────────────┘
                                            ▲
                                     PlaybackTesting  (tests and #Preview only)
```

Each module is a SwiftPM target. Feature targets carry a `Feature` suffix so module names never collide with type names.

**Domain** (Foundation only)
- Entities: `MediaItem`, `LibraryFolder`, `LibraryEntry`, `MediaSource`, `NetworkServer`, `RecentStream`, `PlaybackState`, `PlaybackProgress`, `MediaTrack`, `Chapter`, `TrackPreferences`, `SubtitleCue`, `SubtitleStyle`, `PlaybackError`.
- Protocols: `PlaybackEngine`, `ThumbnailProvider`, `NetworkBrowser`, `CredentialStore`, `NetworkServerRepository`, `StreamHistoryRepository`, `LibraryRepository`, `ProgressRepository`, `PreferencesRepository`, `MediaImporter`.
- `MediaImporter` exists so LibraryFeature can add files and folders without seeing how bookmarks are made; Data implements it.
- Use cases are small structs with one `callAsFunction`: `ResumePlayback`, `SaveProgress`, `PickPreferredTracks`, `LoadLibrary`, `ParseSubtitleCues`, `ParseStreamURL`, `AddToLibrary`. `SaveProgress` is an actor instead, because its throttle remembers the last write.

**Playback** (the only module that imports VLCKit, through `@preconcurrency import VLCKit`)
- Public: `VLCPlaybackEngine`, `VLCThumbnailProvider`, `VLCNetworkBrowser`, `VideoSurface: View`, and a `@MainActor` factory that returns the engine and its surface together.
- Network discovery lives here rather than in Data because it needs `VLCMediaDiscoverer`, and VLCKit stays in one module. Data still owns saved servers and their secrets.

**Data**
- SwiftData `@Model` records, internal, mapped to Domain entities at the repository edge. `@ModelActor` repositories keep `ModelContext` off main.
- `KeychainCredentialStore: CredentialStore`. `ModelContainer` factory (on disk, or in memory for tests). Security-scoped bookmarks.
- `SwiftDataNetworkServerRepository` and `SwiftDataStreamHistoryRepository` share the library store. History keeps the 30 most recent URLs.
- The store can sync through CloudKit (see System integration), so the models follow CloudKit's rules.

**DesignSystem**
- Color and typography tokens, Liquid Glass styles, `Scrubber` (with chapter notches and a thumbnail slot), `TransportButton`, `TrackPicker`. No Domain types beyond plain values.

**PlayerFeature, LibraryFeature, NetworkFeature, SettingsFeature**
- Each is a screen view plus a `@MainActor @Observable final class` model, given Domain protocols and use cases through `init`. Navigation goes out through closures (`onOpen: (MediaItem) -> Void`). No feature imports another.

**PlaybackTesting**
- `FakePlaybackEngine`, `FakeThumbnailProvider`, `FakeNetworkBrowser`, plus in-memory repositories and an in-memory `CredentialStore`. It depends only on Domain, so the graph stays inward and release builds dead-strip it. All the fakes share one target so previews and tests have one import. The name is from the build plan, even though the target holds more than playback fakes.

**App targets**
- Composition root, `AppRouter`, root navigation per platform, Now Playing and remote-command glue, macOS menu commands.

## Media sources

```swift
public enum MediaSource: Sendable, Hashable {
    case file(bookmark: Data)                              // security-scoped, resolved by Data
    case stream(URL)                                       // http(s), hls, rtsp...
    case networkShare(server: NetworkServer.ID, path: String)
}

public struct NetworkServer: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable { case smb, sftp, upnp }
    public let id: UUID
    public var kind: Kind, host: String, port: Int?, displayName: String
    public var requiresCredentials: Bool
}
```

- `.networkShare` refers to its server by ID, never by a URL with userinfo. Credentials never appear in a `MediaSource`, a log line, SwiftData or `UserDefaults`.
- `CredentialStore` (Domain) gets, saves and deletes a `NetworkCredential` by `NetworkServer.ID`. `KeychainCredentialStore` (Data) stores it as `kSecClassInternetPassword`. SwiftData holds only the `NetworkServer` record.
- The engine and `VLCNetworkBrowser` receive the `CredentialStore` at construction. When they open a share, they look up the credential on their own executor and pass it as per-media VLC options (`:smb-user`, `:smb-pwd`, `:sftp-user`...), not in the MRL. VLC login dialogs (`VLCDialogProvider`) are answered from the same store.
- If a credential is missing or rejected, the result is `.authenticationRequired(server:)`: thrown from `NetworkBrowser`, and as `.failed` in the playback state. The feature asks the user, saves the credential through the store, and retries.
- `NetworkBrowser` covers discovery (`servers() -> AsyncStream<[NetworkServer]>`, from `VLCMediaDiscoverer` for SMB and UPnP) and listing (`contents(of:path:) async throws(PlaybackError) -> [NetworkEntry]`). SFTP servers are added by hand because there's no discovery protocol.
- `VLCNetworkBrowser` starts every LAN discoverer libvlc offers (`dsm`, `upnp`, `Bonjour`, `sap` in 4.0.0-a25) and keeps what has an `smb`, `sftp` or `upnp` MRL. A discovered server's ID is a hash of kind, host and port, so it's the same on every launch and matches a saved copy. Listing a folder is a parse of its MRL with `doInteract`; the parsed subitems are the entries. A failed parse is `.authenticationRequired` if the login was refused, otherwise `.serverUnreachable`.
- UPnP entries are addressed by the full item URL the media server hands out, not a path. A UPnP root can only be listed while discovery has it.
- libvlc takes one dialog handler per instance, so `LoginResponder` exists once per `VLCLibrary`: a shared one, plus one for each player built on a private instance (see subtitle style). Each open registers a request with the host and the credential already looked up; the first login prompt for it is answered, a second one means the share refused it.
- **The feature side.** `NetworkModel` lists saved servers and nearby ones that aren't saved. `ShareBrowserModel` lists one folder. On `.authenticationRequired` it raises a `SignInRequest`, keyed by server so a rejected password updates the open sheet instead of closing it. A successful sign-in saves the credential to the store and the server to `NetworkServerRepository`.
- **Opening is adding.** A stream or a share file joins the library through `AddToLibrary`, which returns the existing item for a source it already has. That gives streams and shares resume, Recents and a Mac player window (which loads its item by ID). Opening a share file also saves its server, because the engine finds servers by ID.
- `ParseStreamURL` accepts http(s), rtsp(s), rtmp(s), rtp, udp and mms, assumes https when there's no scheme, and refuses a link with a password in it, since the URL is stored in the library and history.
- Local network access: iOS needs `NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_smb._tcp`, `_sftp-ssh._tcp`). UPnP discovery uses SSDP multicast, which on a device needs the multicast networking entitlement that Apple grants on request; the simulator and the Mac don't. The Mac sandbox needs the outgoing connections entitlement.

## PlaybackEngine

```swift
public protocol PlaybackEngine: Sendable {
    func states() -> AsyncStream<PlaybackState>

    func load(_ source: MediaSource) async throws(PlaybackError)
    func play() async
    func pause() async
    func seek(to position: Duration, precision: SeekPrecision) async
    func seek(by offset: Duration) async
    func seek(toChapter id: Chapter.ID) async
    func stepFrame() async                                 // only while paused
    func setLoop(_ range: ClosedRange<Duration>?) async    // A-B loop
    func setRate(_ rate: Double) async
    func setVolume(_ level: Double) async                  // 0...2, above 1 is boost
    func setVideoScaling(_ scaling: VideoScaling) async    // .fit, .fill, .aspect(w, h)
    func selectTrack(_ id: MediaTrack.ID) async throws(PlaybackError)
    func deselectTrack(kind: MediaTrack.Kind) async
    func addSubtitle(from url: URL) async throws(PlaybackError)
    func setSubtitleDelay(_ delay: Duration) async
    func setSubtitleStyle(_ style: SubtitleStyle) async   // size at once; background and position from the next engine
    func captureFrame() async throws(PlaybackError) -> URL
    func close() async
}

public struct PlaybackState: Sendable, Equatable {
    public var status: Status          // idle, opening, buffering(Double), playing, paused, ended, failed(PlaybackError)
    public var progress: PlaybackProgress   // position, duration
    public var rate: Double, volume: Double, videoScaling: VideoScaling
    public var tracks: [MediaTrack]    // kind, language, title, isDefault, isForced
    public var selectedTrackIDs: Set<MediaTrack.ID>
    public var chapters: [Chapter]     // id, title, start
    public var loop: ClosedRange<Duration>?
    public var subtitleDelay: Duration
    public var isSeekable: Bool, videoSize: VideoSize?   // pixel dimensions
}
```

### What belongs on the engine and what doesn't

- **Chapters are on the engine.** Only the demuxer knows them. `seek(toChapter:)` uses VLC's chapter navigation instead of seeking to `start`, because DVD and Matroska-edition chapter times aren't always reliable offsets.
- **Volume is on the engine.** Boost above 100% has to be done in VLC's audio output. The system volume tops out at 100%, and nothing outside the decoder can amplify samples.
- **Frame step is on the engine.** It's a decoder operation (VLC's next-frame); nothing in the feature can emulate it. It steps forward only, as VLC does.
- **The A-B loop is on the engine, with state in the feature.** A loop in `PlayerModel` would watch position ticks (about 4 Hz) and overshoot B by up to 250 ms each pass. The engine uses libvlc's native A-B loop, or checks the time on its own executor if that isn't available. `PlayerModel` only owns the UI for setting A and B.
- **Video scaling is on the engine.** VLC crops and scales inside its video output, the same on every platform. A SwiftUI `scaleEffect` on the surface would stretch the layer and break subtitles, which VLC renders into the same frame. Pinch-to-fill is a gesture in `PlayerScreen` that calls `setVideoScaling(.fill)`.
- **Subtitle style is split by when libvlc reads it.** Text scale is a player property and changes live. Background and margin are freetype and subpicture options that libvlc reads once, when a video output starts, from the libvlc instance. So `makeWithSurface(subtitleStyle:)` builds the player on a private instance carrying those options, and a change waits for the next player. The feature previews all three over the paused frame and says which ones wait.
- **Thumbnails are a separate protocol, `ThumbnailProvider`.** `func thumbnail(for: MediaSource, at: Duration, maxPixelSize: Int) async throws(PlaybackError) -> URL`.
  - It is separate from the engine because it has a different lifecycle (Library uses it for posters too) and has to run on its own VLC media instance so it never disturbs playback.
  - `VLCThumbnailProvider` wraps VLC's thumbnailer, rounds requests down to 5-second buckets, and caches JPEGs on disk under Caches, keyed by source and bucket. An in-memory index sits in the actor. It resolves `.networkShare` sources against the same server repository and credential store as the engine, with the credential in per-media options.
  - While the user scrubs, `PlayerModel` cancels the previous request before starting the next. The provider also coalesces identical in-flight requests.

### State: AsyncStream at the boundary, `@Observable` in the feature

There were two candidates: a protocol that returns a stream of `PlaybackState`, or one that requires an `@Observable` state object. The stream wins.

- An `@Observable` requirement forces the engine to be a class and fixes its isolation in the protocol. In practice that means `@MainActor`, which puts VLC calls on main (see Threading).
- Not every consumer is a view. `SaveProgress` and Now Playing want every new state in a loop. `withObservationTracking` fires once per registration and has to be re-armed, so it's the wrong tool outside SwiftUI.
- Domain stays Foundation-only. Observation is a separate module.
- A fake is a continuation and a few `yield` calls, so tests script exact state sequences.

`PlayerModel` is what SwiftUI observes. It copies each field into its own stored property, and only when the value changed, so a progress tick doesn't invalidate the track menu.

Stream semantics:
- `states()` returns a new stream per call, and the engine fans out to every live subscriber.
- A new subscriber gets the current state immediately.
- Buffering is `.bufferingNewest(1)`. Every value is a full state, not a delta, so skipping values is safe.
- `onTermination` removes the subscriber, so cancelling the consuming task cleans up.

Errors: typed throws only where the caller can respond on the spot (an unresolvable bookmark, an unknown track, an unreadable subtitle file, a failed capture, missing credentials). Decoding and network failures happen after `load` returns and arrive as `.failed`. `captureFrame()` returns a file URL in Caches, not an image type, so Domain stays free of UIKit and AppKit.

## Use cases

- **ResumePlayback**: loads the source, then seeks to the saved `PlaybackProgress` unless it's under 30 s or over 95% of the duration. Under 30 s, the user barely started and the intro is cheap to rewatch. Over 95%, they're in the credits, so starting over is what they want. If the duration is unknown (a live stream), it resumes only when the saved position is at least 30 s.
- **SaveProgress**: writes at most once every 10 s while playing. It also writes immediately on pause, on the end of a seek, on `close()` and when the scene moves to the background, so a kill loses at most 10 s. Passing 95% marks the item watched and clears the resume point. Throttling lives in the use case (a `ContinuousClock` timestamp), not the repository, so the fake repository sees the same writes the real one does.
- **PickPreferredTracks**: runs once per `load`, when tracks first appear in the state. Language matching uses `Locale.Language`, so `en`, `eng` and `English` compare equal.
  - Audio: the first track matching `TrackPreferences.audioLanguages` in order. Otherwise the track the container marks as default. Otherwise the first track.
  - Subtitles, depending on `TrackPreferences.subtitleMode`:
    - `.off`: none, except forced tracks in the chosen audio language.
    - `.auto`: the same as `.off` when the audio already matches a preferred language. Otherwise the first track in `subtitleLanguages`, preferring a non-forced one, then the `.off` choice.
    - `.always`: the first match in `subtitleLanguages` (non-forced preferred), then the default track, then the `.off` choice.
  - A manual selection by the user is never overridden for the rest of that session.

## Threading: VLC callbacks to the MainActor

VLCKit is Objective-C. Its delegate callbacks and libvlc events arrive on threads we don't control. Some `VLCMediaPlayer` calls, such as `stop` and media replacement, block while libvlc tears down outputs.

1. **The engine is an actor with its own serial executor.** `VLCPlaybackEngine` is an `actor` whose `unownedExecutor` is a private `DispatchSerialQueue`. Every `VLCMediaPlayer` access happens on that queue, never on main, so a blocking `stop` can't drop UI frames. The non-Sendable player stays confined to the actor.
2. **Callbacks copy values and never read player state.** An internal `NSObject` delegate bridge has `nonisolated` methods. Each callback turns its arguments into a Sendable `EngineEvent` (`.stateChanged`, `.bufferingChanged`, `.lengthChanged`, `.timeChanged`, `.tracksChanged`, `.chaptersChanged`, `.capabilitiesChanged`, `.frameCaptured`) and yields it into an `AsyncStream<EngineEvent>.Continuation`. The continuation is Sendable, so no `@unchecked` is needed.
3. **The actor reacts on its own executor.** A task inside the actor iterates those events, reads player properties there, builds a `PlaybackState`, and yields it to subscribers. Reading state inside the callback would race with libvlc.
4. **The consumer makes the MainActor hop.** `PlayerModel` is `@MainActor` and iterates `engine.states()` from the view's `.task {}`. Each `await` resumes on main, and leaving the screen cancels the task. Nothing calls `DispatchQueue.main.async`, and only Sendable values cross isolation boundaries.

VLC quirks handled at the boundary:
- **Stale times after a seek.** VLC reports the old time briefly after a seek. While scrubbing and just after seeking, `PlayerModel` shows its target position and ignores incoming progress until a value lands near the target or a short timeout passes.
- **Frame capture finishes asynchronously.** The actor keeps a `CheckedContinuation` per pending capture, resumes it on `.frameCaptured`, and fails it with `.captureFailed` on timeout. The snapshot callback carries no path, so captures complete in request order. Capturing without a video output raises an Objective-C exception, so the engine checks `hasVideoOut` first.
- **No ended or buffering state.** VLCKit 4 reports the end of the media as a stop nobody asked for, and buffering as a separate 0...1 fill (the header says percent). The engine derives `.ended` and `.buffering` from those.
- **Swapping media sends no state change.** Loading over a playing media keeps the player in `playing` with no stop or opening events, so the engine seeds its state from the player's at `load`.
- **Seeks before the input is open are dropped.** `load` starts playback (libvlc has no prepare step); a seek before the input is open and seekable is held and applied once it is.
- **Seekability and time.** Seekability changes arrive only as a notification, and time ticks come from a main run loop timer (set to 4 Hz). Both just yield events into the bridge.
- **The parser timeout is in microseconds.** `VLCMediaParser(library:timeout:)` documents milliseconds, but a25 passes the value straight through as microseconds: 15000 timed out after 15 ms.
- **A share that never opens still reports itself open.** The capabilities notification arrives before libsmb2 gives up on an unresolvable host, so the engine treats an error on a share before any track appears as `.serverUnreachable`.
- **Delegate names change between VLCKit 4 pre-releases.** The bridge is the only file that has to match them. Pin a version and check the headers on upgrade.

## Video surface

VLC renders into a platform view assigned to `VLCMediaPlayer.drawable`: a `UIView` on iOS and iPadOS, and an `NSView` on macOS.

- **Created once, together with the player.** `VLCPlaybackEngine.makeWithSurface()` is `@MainActor`. It creates the drawable view (`VideoDrawable`) and passes it to the engine's synchronous init, which runs on main, creates the `VLCMediaPlayer` and sets `drawable` there. The player is never `sending`: assigning the main-actor view to `drawable` would merge their regions, so a player built outside the actor couldn't be sent in. After init, the engine never touches the view.
- **The drawable outlives SwiftUI views.** `VideoSurface` is a `UIViewRepresentable` (or `NSViewRepresentable`) that returns a plain container and adds the session's persistent drawable as a subview. Rotation, fullscreen, column changes and window moves can recreate the representable, but they never free the drawable. If the drawable is freed mid-playback, VLC tears down its video output and the picture goes black.
- **Features never see VLCKit.** The player screen is generic over its surface:

  ```swift
  PlayerScreen(model: model) { VideoSurface(session.drawable) }  // app target
  PlayerScreen(model: .preview) { Color.black }                  // #Preview
  ```

  There's no `AnyView` and no environment key. The generic stays local because `LibraryFeature` never builds a player: it calls `onOpen(item)` and the app target builds it.
- **Session lifetime belongs to the router.** The engine, model and surface are created in the open action, not in `body`, so redraws can't spawn extra engines. They're stored in `AppRouter.presentedSession` and closed on dismiss. Each macOS player window owns its own session.
- **Picture in Picture** (iOS and iPadOS). On iOS `VideoDrawable` conforms to `VLCPictureInPictureDrawable`. VLC's sample buffer video output finds that, and where AVKit allows PiP it hands back a window controller once video is up. Domain only sees `isPictureInPictureSupported` and `isPictureInPictureActive` on `PlaybackState`, plus `setPictureInPicture(_:)`.
  - AVKit asks the media controller for time, length and play state synchronously on main, so the engine keeps a `Mutex` copy (`PictureInPictureMedia`) and refreshes the window only when something AVKit can't extrapolate changes. PiP play, pause and skip go back into the engine as commands.
  - The capability survives `load`, because VLC can keep its video output across media and then never reports ready again. The button also needs a video track.
  - 4.0.0-a25's macOS slice has no PiP controller, so on the Mac the flag stays false. The iPhone simulator reports PiP unsupported; the iPad simulator and devices support it.
  - Backgrounding pauses video unless PiP is active. Audio-only media keeps playing.

## System integration

All of this is app-target glue except where noted. `OpenPlayers` and `NowPlaying` are told about every `PlayerSession` when it opens and closes, from `AppRouter` on iOS and `PlayerWindow` on the Mac.

**Audio session (iOS).** `PlaybackAudioSession` sets `.playback`, `.moviePlayback`, `.longFormVideo` at launch. libvlc's audio output sets the same values whenever it starts (`avaudiosession_common.m`), and each of those calls posts a `categoryChange` route change, which is where a debug assertion checks that nothing drifted. `UIBackgroundModes` has `audio`.
- Interruptions pause every playing session. When the interruption ends, they resume only if the system passes `.shouldResume` (a call that ends does; an alarm or another app's audio doesn't).
- `oldDeviceUnavailable` (headphones unplugged, AirPods out) pauses.
- When the scene backgrounds, `PlayerModel` pauses media with a video track unless Picture in Picture is active. Audio-only media keeps playing. The Mac keeps playing, as Mac apps do.

**Now Playing and remote commands.** `NowPlaying` subscribes to each engine's `states()` and publishes for whichever player last started playing. Another open player takes over when that one closes. It publishes only when something the system can't extrapolate changes: title, duration, rate, play state, or a position more than a second off the expected one. Commands (play, pause, toggle, skip ±10 s, change position, change rate) go through `PlayerModel`, the same as the on-screen controls. MediaPlayer calls handlers and the artwork closure on its own queues, so both are built so they aren't isolated to the main actor.

**Handoff.** A player advertises `io.pane.player.playing` (`NSUserActivityTypes`) with a JSON-encoded `PlaybackHandoff` (Domain). SwiftUI's `userActivity` modifier fills it in when the system asks, so the position is current.
- Streams travel as their URL. Shares travel as the server's kind, host and port plus the path, never a credential. The receiving device reuses a saved server with the same address, or saves this one, and signs in with its own keychain.
- A file travels as its library item ID. `ContinueHandoff` (Domain) plays it only if this device has an item with that ID or title whose bookmark `MediaImporter.canOpen(_:)`. Otherwise the user sees why it can't continue.
- `ContinueHandoff` saves the sender's position as the item's progress, so opening it resumes through `ResumePlayback`'s usual rules.

**iCloud sync.** Optional, off by default, in Settings (a sheet on iPhone and iPad, the Settings window on the Mac). The whole library store syncs through CloudKit's private database, because progress is keyed by library item and means nothing without its item. Keychain credentials are never in the store.
- `LibraryStore.open(syncsWithCloud:)` reads the setting once at launch. It opens with `.private("iCloud.io.pane.player")` when the setting is on and someone is signed in to iCloud. Otherwise, or when CloudKit refuses the store (no entitlement, a container the team doesn't own), it opens the same store locally. The result is `CloudSyncStatus`, which Settings explains. A change applies at the next launch, since every repository holds the container.
- The store is explicitly `.none` when sync is off. SwiftData's default, `.automatic`, would start syncing as soon as the build had an iCloud entitlement.
- CloudKit rules for the models: no unique attributes, every attribute optional or defaulted, to-many relationships optional. Removing `.unique` and adding defaults is a lightweight migration; `CloudKitStoreTests` opens a store written by the old schema (`Fixtures/LibraryBeforeCloudKit.store`). Without uniqueness, repositories still look up before inserting, and reads tolerate the duplicates sync can produce: the newest progress wins and history lists a URL once.
- Bookmarks only resolve on the device that made them, so file items and folders carry `originDevice`, a per-install ID kept in UserDefaults. Other devices' files and folders stay out of listings. Unstamped records are claimed at launch.
- Signing is opt-in. `Config/Pane.xcconfig` includes `Signing.local.xcconfig` if it exists (git-ignored; see the `.example`), which sets the team and the iCloud entitlements. A build without it has no entitlements, builds without a team and reports sync as unavailable.

## Navigation

Routing is owned by `AppRouter`, an `@MainActor @Observable` type in the app target holding selection, paths and the presented session. Features only emit intents through closures, so the same `LibraryScreen` works under every root.

| Platform | Root | Player presentation |
|---|---|---|
| iPad | `NavigationSplitView`: sources sidebar (Library, Recents, Network, imported folders), library grid or network stack as detail | `fullScreenCover` |
| macOS | `NavigationSplitView`, same columns | `WindowGroup(for: MediaItem.ID.self)` via `openWindow`; transport in the Playback menu |
| iPhone | `TabView` (Library, Recents, Network), one `NavigationStack` per tab; folders are listed inside Library | `fullScreenCover` |

- **iPhone vs iPad is chosen by idiom at launch, not by size class.** A large iPhone in landscape reports regular width, and swapping roots on rotation would throw away the stack path. On iPad, the split view already collapses into a stack in compact multitasking.
- **Mac players are windows** because people play several files side by side and expect to resize and close them like documents. Player windows aren't restored at launch: SwiftUI brings them back without their item ID.
- **The Playback menu is the Mac's keyboard handling.** Each player window publishes a `FocusedPlayer` with `focusedSceneValue`, and `PlaybackCommands` calls the same `PlayerModel` methods the on-screen controls use (J/K/L shuttle, `[` `]` speed, arrows for seeking and volume). Bare keys work as menu key equivalents and AppKit offers them to the menu before the window, so the items turn off while the options popover or the track sheet has the keyboard.
- **Files open in place.** The app declares video document types with `LSSupportsOpeningDocumentsInPlace`, so Files and Finder hand over the original URL. `AppRouter` imports it through `MediaImporter` (which returns the existing item for a file already in the library) and plays it. When Finder opens several files at once, SwiftUI gives only the first to `onOpenURL` and forwards the rest to the app delegate, which queues them in `OpenedFiles` for the library window to open.
- **The network stack is the same on every root.** `NetworkStack` (app target) holds a `NavigationStack` over `AppRouter.networkPath` and resolves `NetworkRoute` (`.openURL`, `.folder`). Folder models are kept per route while the route is on the path, so going back doesn't re-list the share.
- **Library models live in the router**, one per scope, so switching sidebar items or tabs keeps each scope's sort, filter and posters. Closing a player bumps `AppDependencies.libraryRevision` and every window reloads.

## Testing

- Feature models: Swift Testing against `PlaybackTesting` fakes, with scripted state sequences for scrubbing, stale-time suppression, A-B loop UI and credential prompts.
- Use cases: resume thresholds at 29 s, 30 s, 95% and unknown duration. The throttle uses an injected clock. Track picking covers each subtitle mode, forced tracks and language aliases.
- Repositories: an in-memory `ModelContainer`. `KeychainCredentialStore` tests skip themselves when the runner has no keychain entitlement, which is the case for unsigned package test runners on both macOS and the simulator; the store is exercised in the app.
- Network screens without a NAS: a Debug build launched with `-PaneDemoNetwork YES` browses fake servers from `PlaybackTesting` (password "pane") while still saving logins to the real keychain.
- `VLCPlaybackEngine` and `VLCThumbnailProvider`: thin macOS integration tests with a short bundled clip that has chapters and two audio tracks. These are the only tests that load VLCKit.

## Open risks

- VLCKit 4 is pre-release. 4.0.0-a25 ships a usable SwiftPM binary target and native A-B looping (`setABLoopFrom(_:to:)`); the engine falls back to checking time ticks if libvlc refuses a loop.
- Delegate signatures may change between VLCKit 4 builds. The bridge contains that churn to one file.
- 4.0.0-a25 can abort on an assertion in `vout_display_opengl_Prepare` when two players set up video at the same moment. Mac player windows start their sessions at least 0.5 s apart; recheck on each VLCKit upgrade.
