import Domain
import Foundation
import Observation

/// Subtitle size, background and position, edited over the paused frame.
@MainActor
@Observable
public final class SubtitleAppearance {
    public private(set) var style: SubtitleStyle
    public private(set) var isEditing = false {
        didSet {
            guard isEditing != oldValue else { return }
            onEditingChange?()
        }
    }

    @ObservationIgnored var isPlaying: () -> Bool = { false }
    @ObservationIgnored var onEditingChange: (() -> Void)?

    private let engine: any PlaybackEngine
    private let save: (@Sendable (SubtitleStyle) async -> Void)?
    // The engine was built with this style; see `waitsForNextVideo`.
    private let engineStyle: SubtitleStyle
    @ObservationIgnored private var resumesOnDone = false

    init(engine: any PlaybackEngine, style: SubtitleStyle, save: (@Sendable (SubtitleStyle) async -> Void)?) {
        self.engine = engine
        self.style = style
        self.save = save
        engineStyle = style
    }

    /// Background and position only change when the next video opens; size changes at once.
    public var waitsForNextVideo: Bool {
        style.background != engineStyle.background || style.position != engineStyle.position
    }

    public var size: SubtitleStyle.Size {
        get { style.size }
        set { update { $0.size = newValue } }
    }

    public var background: SubtitleStyle.Background {
        get { style.background }
        set { update { $0.background = newValue } }
    }

    public var position: SubtitleStyle.Position {
        get { style.position }
        set { update { $0.position = newValue } }
    }

    public func beginEditing() {
        guard !isEditing else { return }
        resumesOnDone = isPlaying()
        isEditing = true
        if resumesOnDone {
            Task { [engine] in await engine.pause() }
        }
    }

    public func endEditing() {
        guard isEditing else { return }
        isEditing = false
        if resumesOnDone {
            Task { [engine] in await engine.play() }
        }
    }

    private func update(_ change: (inout SubtitleStyle) -> Void) {
        var style = self.style
        change(&style)
        guard style != self.style else { return }
        self.style = style
        Task { [engine, save] in
            await engine.setSubtitleStyle(style)
            await save?(style)
        }
    }
}
