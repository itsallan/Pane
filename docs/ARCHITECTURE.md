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
                 App targets (iOS/iPadOS, macOS, tvOS, visionOS)
        ┌──────────────┬──────────────┼──────────────┬───────────────┐
        ▼              ▼              ▼              ▼               ▼
   PlayerFeature  LibraryFeature  SettingsFeature  Playback         Data
        │              │              │            (VLCKit)      (SwiftData)
        ├──────────────┴──────┬───────┘              │               │
        ▼                     ▼                      │               │
   DesignSystem             Domain ◀─────────────────┴───────────────┘
                              ▲
                         DomainFakes  (tests and #Preview only)

   watchOS app ──▶ Domain
```

Each module is a SwiftPM target. Feature targets carry a `Feature` suffix so module names never collide with type names (`PlayerFeature.PlayerModel`, not `Player.Player`).

**Domain** (Foundation only)
- Entities: `MediaItem`, `MediaSource` (`.file(URL)`, `.bookmark(Data)`, `.network(URL)`), `MediaTrack`, `PlaybackSnapshot`, `PlaybackStatus`, `PlaybackError`, `ResumePosition`.
- Protocols: `PlaybackEngine`, `LibraryRepository`, `ResumePositionRepository`.
- Use cases are small structs with one `callAsFunction`: `StartPlayback` (load, then seek to the stored resume position), `RecordProgress`, `LoadLibrary`.

**Playback** (the only module that imports VLCKit, through `@preconcurrency import VLCKit`)
- Public: `VLCPlaybackEngine: PlaybackEngine`, `VideoSurface: View`, and a `@MainActor` factory that returns both.
- Everything else is internal, so no `VLCMedia`, `VLCMediaPlayer` or VLC enum crosses the module boundary.

**Data**
- SwiftData `@Model` records, internal. They are mapped to Domain entities at the repository edge.
- `@ModelActor` repositories, so `ModelContext` never runs on the main actor during imports or scans.
- A `ModelContainer` factory (on disk, or in memory for tests), security-scoped bookmark resolution, and later network sources and the watch transport.

**DesignSystem**
- Color and typography tokens, Liquid Glass styles, and the reusable controls `Scrubber`, `TransportButton` and `TrackPicker`. No Domain knowledge beyond plain values.

**PlayerFeature, LibraryFeature, SettingsFeature**
- Each one is a screen view plus a `@MainActor @Observable final class` model. Inputs are Domain protocols and use cases, passed in through `init`.
- Navigation goes out through closures (`onOpen: (MediaItem) -> Void`). No feature imports another feature.

**DomainFakes**
- `FakePlaybackEngine`, plus in-memory repositories. This is the one target beyond the CLAUDE.md list. It depends only on Domain, so the graph stays inward, and release builds dead-strip it. Without it, every feature would carry its own preview fake.

**App targets**
- Composition root, `AppRouter`, root navigation per platform, Now Playing and remote command glue (MediaPlayer framework), and macOS menu commands.
- The watchOS target links Domain only. VLCKit has no watchOS slice, and the watch never decodes video.

## PlaybackEngine

```swift
public protocol PlaybackEngine: Sendable {
    func snapshots() -> AsyncStream<PlaybackSnapshot>

    func load(_ source: MediaSource) async throws(PlaybackError)
    func play() async
    func pause() async
    func seek(to position: Duration, precision: SeekPrecision) async
    func seek(by offset: Duration) async
    func setRate(_ rate: Double) async
    func selectTrack(_ id: MediaTrack.ID) async throws(PlaybackError)
    func deselectTrack(kind: MediaTrack.Kind) async
    func addSubtitle(from url: URL) async throws(PlaybackError)
    func setSubtitleDelay(_ delay: Duration) async
    func snapshot() async throws(PlaybackError) -> URL
    func close() async
}

public struct PlaybackSnapshot: Sendable, Equatable {
    public var status: PlaybackStatus          // idle, opening, buffering(Double), playing, paused, ended, failed(PlaybackError)
    public var position: Duration
    public var duration: Duration?
    public var rate: Double
    public var tracks: [MediaTrack]            // audio, video, subtitle; `MediaTrack.Kind` tells them apart
    public var selectedTrackIDs: Set<MediaTrack.ID>
    public var subtitleDelay: Duration
    public var isSeekable: Bool
    public var videoSize: CGSize?
}
```

### State: AsyncStream at the boundary, `@Observable` in the feature

There were two candidates: a protocol that returns a stream of snapshots, or a protocol that requires an `@Observable` snapshot object. The stream wins.

- An `@Observable` requirement forces the engine to be a class and fixes its isolation in the protocol. In practice that means `@MainActor`, which puts VLC calls on main (see Threading). A stream says nothing about where the engine runs.
- Not every consumer is a view. `RecordProgress`, Now Playing info and the watch bridge all want "every new state" in a loop. `withObservationTracking` fires once per registration and has to be re-armed by hand, so it's the wrong tool outside SwiftUI.
- Domain stays Foundation-only. Observation is a separate module, and CLAUDE.md keeps Domain to Foundation.
- A fake is a continuation and a few `yield` calls. Tests can script exact state sequences.

`PlayerModel` is the observable snapshot that SwiftUI reads. It copies each snapshot field into its own stored property, and only when the value changed. Observation therefore invalidates the time label four times a second without touching the track menu.

### Stream semantics

- `snapshots()` returns a new stream per call, and the engine fans out to every live subscriber.
- A new subscriber gets the current snapshot immediately, so late subscribers don't render an empty player.
- Buffering is `.bufferingNewest(1)`. Every value is a full snapshot, not a delta, so a slow consumer can skip values without ending up wrong.
- `onTermination` removes the subscriber, so cancelling the consuming task is enough to clean up.

### Errors

Typed throws only where the caller can respond on the spot: an unresolvable bookmark, an unknown track ID, an unreadable subtitle file, a failed snapshot. Decoding and network failures happen after `load` returns and arrive as `.failed(PlaybackError)` in the stream, because VLC only discovers them while opening.

Snapshots return a file URL in the caches directory, not an image type, which keeps Domain free of UIKit and AppKit. The feature decides whether to share it, save it or show it.

## Threading: VLC callbacks to the MainActor

VLCKit is Objective-C. Its delegate callbacks and libvlc events arrive on threads we don't control. Some `VLCMediaPlayer` calls, such as `stop` and media replacement, block while libvlc tears down outputs.

1. **The engine is an actor with its own serial executor.** `VLCPlaybackEngine` is an `actor` whose `unownedExecutor` is a private `DispatchSerialQueue`. Every `VLCMediaPlayer` access happens on that queue, never on main, so a blocking `stop` can't drop frames in the UI. The player is non-Sendable and stays confined to the actor.
2. **Callbacks copy values and never read player state.** The delegate is a small internal `NSObject` bridge whose methods are `nonisolated`. Each callback turns its arguments into an internal Sendable `EngineEvent` enum (`.stateChanged(VLCState)`, `.timeChanged`, `.tracksChanged`, `.snapshotTaken(path)`) and yields it into an internal `AsyncStream<EngineEvent>.Continuation`. The continuation is Sendable, so this compiles under complete checking without `@unchecked`.
3. **The actor reacts on its own executor.** One task inside the actor iterates that event stream, reads `VLCMediaPlayer` properties there, builds a `PlaybackSnapshot` and yields it to subscribers. Reading state off-queue inside the callback would race with libvlc.
4. **The consumer makes the MainActor hop.** `PlayerModel` is `@MainActor` and iterates `engine.snapshots()` from the view's `.task {}`. Each `await` resumes on main, and leaving the screen cancels the task. Nothing calls `DispatchQueue.main.async`, and only `Sendable` value types cross isolation boundaries.

Two VLC quirks are handled at the boundary:

- **Stale times after a seek.** VLC keeps reporting the old time for a short while after a seek. While scrubbing and right after seeking, `PlayerModel` shows its local target position and ignores incoming positions until one lands near the target or a short timeout passes. Without this, the scrubber snaps back.
- **Snapshots finish asynchronously.** VLC writes the snapshot file and confirms through the delegate. The actor keeps a `CheckedContinuation` per pending request and resumes it on `.snapshotTaken`, or with `.snapshotFailed` on timeout.

Delegate method names have changed between VLCKit 4 pre-releases. The bridge is the only file that has to match them, so pin a version and check the headers when upgrading.

## Video surface

VLC renders into a platform view assigned to `VLCMediaPlayer.drawable`: a `UIView` on iOS, iPadOS, tvOS and visionOS, and an `NSView` on macOS.

- **Created once, together with the player.** The `@MainActor` factory in Playback creates the drawable view and the `VLCMediaPlayer`, sets `drawable` on main, and then hands the player to the actor as a `sending` parameter. After construction, the engine never touches the view.
- **The drawable outlives SwiftUI views.** `VideoSurface` is a `UIViewRepresentable` (or `NSViewRepresentable`) whose `makeUIView` returns a plain container and adds the session's persistent drawable as a subview. Rotation, fullscreen transitions, split-view column changes and window moves can recreate the representable, but they never destroy the drawable. If VLC's drawable is freed mid-playback, the video output is torn down and the picture goes black.
- **Features never see VLCKit.** The player screen is generic over its surface:

  ```swift
  PlayerScreen(model: model) { VideoSurface(session.surface) }   // app target
  PlayerScreen(model: .preview) { Color.black }                  // #Preview
  ```

  `PlayerScreen<Surface: View>` has no `AnyView` and no environment key. The generic stays local because `LibraryFeature` never builds a player. It calls `onOpen(item)`, and the app target constructs the player.
- **Session lifetime belongs to the router.** The engine, model and surface are created inside the open action, not in `body`, so redraws can't spawn extra engines. They are stored in `AppRouter.presentedSession` and closed (`await engine.close()`) on dismiss. Each macOS or visionOS player window owns its own session.
- Picture in Picture uses VLCKit 4's PiP-capable drawable. It stays inside Playback and will reach Domain as a capability flag on the snapshot when it's built.

## Navigation

Routing is owned by `AppRouter`, an `@MainActor @Observable` type in the app target that holds the selection, paths and presented session. Features only emit intents through closures, so the same `LibraryScreen` works under every root.

| Platform | Root | Player presentation |
|---|---|---|
| iPad | `NavigationSplitView`: sources sidebar (Library, Recents, Network), item list, detail | `fullScreenCover` |
| macOS | `NavigationSplitView`, same columns | `WindowGroup(for: MediaItem.ID.self)` via `openWindow`; transport in `.commands` |
| iPhone | `TabView`, one `NavigationStack` per tab | `fullScreenCover` |
| tvOS | Top `TabView`, `NavigationStack` per tab | `fullScreenCover` |
| visionOS | `NavigationSplitView` in the main window | Separate `WindowGroup`, resizable |

- **iPhone vs iPad is chosen by idiom at launch, not by size class.** A large iPhone in landscape reports regular width. Swapping roots on rotation would throw away the stack path. On iPad, `NavigationSplitView` already collapses into a stack in compact multitasking, so no second layout is needed.
- **Mac and visionOS players are windows** because people play several files side by side and expect to resize, full-screen and close them like documents. iPhone, iPad and tvOS present the player full screen over the root.
- **tvOS focus:**
  - Library shelves are `.focusSection()`s so moving up or down jumps between rows, and `defaultFocus` puts focus on the primary item.
  - In the player, transport is an overlay with `@FocusState`. `.onPlayPauseCommand` toggles playback and `.onMoveCommand` scrubs while the overlay is visible.
  - `.onExitCommand` hides the overlay first and closes the player second, matching the system player.
- **watchOS** is a remote. It sends commands and receives `PlaybackSnapshot`s over WatchConnectivity. The transport lives in `Data` on the phone side, and the watch app shares only Domain types.

## Testing

- Feature models: Swift Testing against `FakePlaybackEngine`. The fake records commands and the test scripts snapshot sequences, which covers scrubbing, stale-time suppression and error display without VLC.
- Use cases: run against fakes from `DomainFakes`.
- Repositories: an in-memory `ModelContainer`, including the record-to-entity mapping.
- `VLCPlaybackEngine`: a thin integration test on macOS that plays a short bundled clip and checks the status sequence, seeking and track listing. This is the only test that loads VLCKit.

## Open risks

- VLCKit 4 is pre-release. visionOS slice availability and a usable SwiftPM binary target need confirming before the Playback target is created.
- Delegate signatures may change between VLCKit 4 builds. The bridge contains that churn to one file.
- Project settings still differ from CLAUDE.md: the bundle ID is `io.Pane`, tvOS isn't added as a destination, the Swift language mode is 5, and deployment targets are 26.4 and 26.5. Fix these before the package lands, or strict concurrency won't be enforced.
