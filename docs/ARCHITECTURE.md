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
        ┌──────────────┬──────────────┼──────────────┬───────────────┐
        ▼              ▼              ▼              ▼               ▼
   PlayerFeature  LibraryFeature  SettingsFeature  Playback         Data
        │              │              │            (VLCKit)   (SwiftData, Keychain)
        ├──────────────┴──────┬───────┘              │               │
        ▼                     ▼                      │               │
   DesignSystem             Domain ◀─────────────────┴───────────────┘
                              ▲
                       PlaybackTesting  (tests and #Preview only)
```

Each module is a SwiftPM target. Feature targets carry a `Feature` suffix so module names never collide with type names.

**Domain** (Foundation only)
- Entities: `MediaItem`, `MediaSource`, `NetworkServer`, `PlaybackState`, `PlaybackProgress`, `MediaTrack`, `Chapter`, `TrackPreferences`, `PlaybackError`.
- Protocols: `PlaybackEngine`, `ThumbnailProvider`, `NetworkBrowser`, `CredentialStore`, `LibraryRepository`, `ProgressRepository`, `PreferencesRepository`.
- Use cases are small structs with one `callAsFunction`: `ResumePlayback`, `SaveProgress`, `PickPreferredTracks`, `LoadLibrary`. `SaveProgress` is an actor instead, because its throttle remembers the last write.

**Playback** (the only module that imports VLCKit, through `@preconcurrency import VLCKit`)
- Public: `VLCPlaybackEngine`, `VLCThumbnailProvider`, `VLCNetworkBrowser`, `VideoSurface: View`, and a `@MainActor` factory that returns the engine and its surface together.
- Network discovery lives here rather than in Data because it needs `VLCMediaDiscoverer`, and VLCKit stays in one module. Data still owns saved servers and their secrets.

**Data**
- SwiftData `@Model` records, internal, mapped to Domain entities at the repository edge. `@ModelActor` repositories keep `ModelContext` off main.
- `KeychainCredentialStore: CredentialStore`. `ModelContainer` factory (on disk, or in memory for tests). Security-scoped bookmarks.

**DesignSystem**
- Color and typography tokens, Liquid Glass styles, `Scrubber` (with chapter notches and a thumbnail slot), `TransportButton`, `TrackPicker`. No Domain types beyond plain values.

**PlayerFeature, LibraryFeature, SettingsFeature**
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
- **Thumbnails are a separate protocol, `ThumbnailProvider`.** `func thumbnail(for: MediaSource, at: Duration, maxPixelSize: Int) async throws(PlaybackError) -> URL`.
  - It is separate from the engine because it has a different lifecycle (Library uses it for posters too) and has to run on its own VLC media instance so it never disturbs playback.
  - `VLCThumbnailProvider` wraps VLC's thumbnailer, rounds requests down to 5-second buckets, and caches JPEGs on disk under Caches, keyed by source and bucket. An in-memory index sits in the actor.
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
2. **Callbacks copy values and never read player state.** An internal `NSObject` delegate bridge has `nonisolated` methods. Each callback turns its arguments into a Sendable `EngineEvent` (`.stateChanged`, `.timeChanged`, `.tracksChanged`, `.chaptersChanged`, `.frameCaptured(path)`) and yields it into an `AsyncStream<EngineEvent>.Continuation`. The continuation is Sendable, so no `@unchecked` is needed.
3. **The actor reacts on its own executor.** A task inside the actor iterates those events, reads player properties there, builds a `PlaybackState`, and yields it to subscribers. Reading state inside the callback would race with libvlc.
4. **The consumer makes the MainActor hop.** `PlayerModel` is `@MainActor` and iterates `engine.states()` from the view's `.task {}`. Each `await` resumes on main, and leaving the screen cancels the task. Nothing calls `DispatchQueue.main.async`, and only Sendable values cross isolation boundaries.

VLC quirks handled at the boundary:
- **Stale times after a seek.** VLC reports the old time briefly after a seek. While scrubbing and just after seeking, `PlayerModel` shows its target position and ignores incoming progress until a value lands near the target or a short timeout passes.
- **Frame capture finishes asynchronously.** The actor keeps a `CheckedContinuation` per pending capture, resumes it on `.frameCaptured`, and fails it with `.captureFailed` on timeout.
- **Delegate names change between VLCKit 4 pre-releases.** The bridge is the only file that has to match them. Pin a version and check the headers on upgrade.

## Video surface

VLC renders into a platform view assigned to `VLCMediaPlayer.drawable`: a `UIView` on iOS and iPadOS, and an `NSView` on macOS.

- **Created once, together with the player.** The `@MainActor` factory creates the drawable view and the `VLCMediaPlayer`, sets `drawable` on main, then hands the player to the actor as a `sending` parameter. After that, the engine never touches the view.
- **The drawable outlives SwiftUI views.** `VideoSurface` is a `UIViewRepresentable` (or `NSViewRepresentable`) that returns a plain container and adds the session's persistent drawable as a subview. Rotation, fullscreen, column changes and window moves can recreate the representable, but they never free the drawable. If the drawable is freed mid-playback, VLC tears down its video output and the picture goes black.
- **Features never see VLCKit.** The player screen is generic over its surface:

  ```swift
  PlayerScreen(model: model) { VideoSurface(session.surface) }   // app target
  PlayerScreen(model: .preview) { Color.black }                  // #Preview
  ```

  There's no `AnyView` and no environment key. The generic stays local because `LibraryFeature` never builds a player: it calls `onOpen(item)` and the app target builds it.
- **Session lifetime belongs to the router.** The engine, model and surface are created in the open action, not in `body`, so redraws can't spawn extra engines. They're stored in `AppRouter.presentedSession` and closed on dismiss. Each macOS player window owns its own session.
- Picture in Picture uses VLCKit 4's PiP-capable drawable. It stays inside Playback and will reach Domain as a capability flag on `PlaybackState`.

## Navigation

Routing is owned by `AppRouter`, an `@MainActor @Observable` type in the app target holding selection, paths and the presented session. Features only emit intents through closures, so the same `LibraryScreen` works under every root.

| Platform | Root | Player presentation |
|---|---|---|
| iPad | `NavigationSplitView`: sources sidebar (Library, Recents, Network), item list, detail | `fullScreenCover` |
| macOS | `NavigationSplitView`, same columns | `WindowGroup(for: MediaItem.ID.self)` via `openWindow`; transport in `.commands` |
| iPhone | `TabView`, one `NavigationStack` per tab | `fullScreenCover` |

- **iPhone vs iPad is chosen by idiom at launch, not by size class.** A large iPhone in landscape reports regular width, and swapping roots on rotation would throw away the stack path. On iPad, the split view already collapses into a stack in compact multitasking.
- **Mac players are windows** because people play several files side by side and expect to resize and close them like documents.

## Testing

- Feature models: Swift Testing against `PlaybackTesting` fakes, with scripted state sequences for scrubbing, stale-time suppression, A-B loop UI and credential prompts.
- Use cases: resume thresholds at 29 s, 30 s, 95% and unknown duration. The throttle uses an injected clock. Track picking covers each subtitle mode, forced tracks and language aliases.
- Repositories: an in-memory `ModelContainer`. `KeychainCredentialStore` runs on macOS against a test-only access group.
- `VLCPlaybackEngine` and `VLCThumbnailProvider`: thin macOS integration tests with a short bundled clip that has chapters and two audio tracks. These are the only tests that load VLCKit.

## Open risks

- VLCKit 4 is pre-release. A usable SwiftPM binary target, and native A-B loop support in the pinned build all need confirming before the Playback target is created.
- Delegate signatures may change between VLCKit 4 builds. The bridge contains that churn to one file.
