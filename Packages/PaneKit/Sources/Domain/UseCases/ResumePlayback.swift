public struct ResumePlayback: Sendable {
    private let engine: any PlaybackEngine
    private let progress: any ProgressRepository

    public init(engine: any PlaybackEngine, progress: any ProgressRepository) {
        self.engine = engine
        self.progress = progress
    }

    /// Returns the position playback resumed from, or `nil` when it starts from the beginning.
    /// With `.ask` or `.never` it always starts from the beginning; `.ask` callers offer `savedPosition(for:)` themselves.
    @discardableResult
    public func callAsFunction(_ item: MediaItem, behavior: ResumeBehavior = .always) async throws(PlaybackError) -> Duration? {
        try await engine.load(item.source)
        guard behavior == .always, let position = await savedPosition(for: item) else { return nil }
        await engine.seek(to: position, precision: .exact)
        return position
    }

    /// Where the item would resume, or `nil` when it should start over.
    public func savedPosition(for item: MediaItem) async -> Duration? {
        // A failed read only costs the resume point, so it shouldn't stop playback.
        guard var saved = try? await progress.progress(for: item.id) else { return nil }
        if saved.duration == nil {
            saved.duration = item.duration
        }
        return saved.resumePosition
    }
}
