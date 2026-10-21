import Domain
import Foundation
import Observation

/// Subtitle delay, nudged by hand or found by ear: the viewer taps when they hear a line, then picks that line.
@MainActor
@Observable
public final class SubtitleSync {
    public enum Phase: Equatable {
        case listening
        case picking(heardAt: Duration)
    }

    static let step = Duration.milliseconds(50)

    public private(set) var phase: Phase? {
        didSet {
            guard (phase == nil) != (oldValue == nil) else { return }
            onActiveChange?()
        }
    }
    public private(set) var delay = Duration.zero
    /// The lines of the selected subtitle track, when it came from a file we could read.
    public private(set) var cues: [SubtitleCue] = []

    @ObservationIgnored var currentPosition: () -> Duration = { .zero }
    @ObservationIgnored var onActiveChange: (() -> Void)?

    private let engine: any PlaybackEngine
    @ObservationIgnored private var cuesByTrack: [MediaTrack.ID: [SubtitleCue]] = [:]
    @ObservationIgnored private var pendingCues: (cues: [SubtitleCue], existingIDs: Set<MediaTrack.ID>)?

    init(engine: any PlaybackEngine) {
        self.engine = engine
    }

    public var isActive: Bool { phase != nil }
    public var canSyncByEar: Bool { !cues.isEmpty }

    public func nudge(by offset: Duration) {
        setDelay(delay + offset)
    }

    public func resetDelay() {
        setDelay(.zero)
    }

    public func begin() {
        guard canSyncByEar else { return }
        phase = .listening
        Task { [engine] in await engine.play() }
    }

    /// Pauses so the viewer can find the line without the next one going by.
    public func heardLine() {
        guard phase == .listening else { return }
        phase = .picking(heardAt: currentPosition())
        Task { [engine] in await engine.pause() }
    }

    public func pick(_ cue: SubtitleCue) {
        guard case .picking(let heardAt) = phase else { return }
        setDelay(heardAt - cue.start)
        phase = nil
        Task { [engine] in await engine.play() }
    }

    public func cancel() {
        guard phase != nil else { return }
        let wasPicking = phase != .listening
        phase = nil
        if wasPicking {
            Task { [engine] in await engine.play() }
        }
    }

    /// The line on screen at the moment the viewer heard one, with the current delay applied.
    public func nearestCue(toHeard heardAt: Duration) -> SubtitleCue? {
        let fileTime = heardAt - delay
        return cues.min { distance($0.start, fileTime) < distance($1.start, fileTime) }
    }

    func expect(_ cues: [SubtitleCue], besides existingIDs: Set<MediaTrack.ID>) {
        pendingCues = (cues, existingIDs)
    }

    func update(from state: PlaybackState) {
        if delay != state.subtitleDelay {
            delay = state.subtitleDelay
        }
        let subtitles = state.tracks.filter { $0.kind == .subtitle }
        // The engine assigns the added file's track ID, so the cues wait for a track that wasn't there before.
        if let pendingCues, let added = subtitles.first(where: { !pendingCues.existingIDs.contains($0.id) }) {
            cuesByTrack[added.id] = pendingCues.cues
            self.pendingCues = nil
        }
        let selected = subtitles.first { state.selectedTrackIDs.contains($0.id) }
        let current = selected.flatMap { cuesByTrack[$0.id] } ?? []
        if cues != current {
            cues = current
        }
        if current.isEmpty, phase != nil {
            phase = nil
        }
    }

    private func setDelay(_ delay: Duration) {
        self.delay = delay
        Task { [engine] in await engine.setSubtitleDelay(delay) }
    }

    private func distance(_ lhs: Duration, _ rhs: Duration) -> Duration {
        lhs > rhs ? lhs - rhs : rhs - lhs
    }
}
