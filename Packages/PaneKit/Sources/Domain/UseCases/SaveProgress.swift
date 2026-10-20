/// An actor rather than a struct because the throttle has to remember when it last wrote.
public actor SaveProgress<C: Clock> where C.Duration == Duration {
    public enum Trigger: Sendable, Hashable {
        case tick
        case pause
        case seekEnded
        case close
        case background
    }

    private let item: MediaItem.ID
    private let repository: any ProgressRepository
    private let clock: C
    private let interval: Duration
    private var lastWrite: C.Instant
    private var isMarkedWatched = false

    public init(item: MediaItem.ID, repository: any ProgressRepository, clock: C, interval: Duration = .seconds(10)) {
        self.item = item
        self.repository = repository
        self.clock = clock
        self.interval = interval
        // Starting the window now rather than writing on the first tick keeps the pre-resume ticks at 0:00
        // from overwriting the saved position before ResumePlayback's seek lands.
        lastWrite = clock.now
    }

    public func callAsFunction(_ progress: PlaybackProgress, trigger: Trigger = .tick) async throws {
        if progress.isWatched {
            guard !isMarkedWatched else { return }
            try await repository.markWatched(item)
            isMarkedWatched = true
            return
        }
        isMarkedWatched = false
        let now = clock.now
        guard trigger != .tick || lastWrite.duration(to: now) >= interval else { return }
        try await repository.save(progress, for: item)
        lastWrite = now
    }
}

extension SaveProgress where C == ContinuousClock {
    public init(item: MediaItem.ID, repository: any ProgressRepository) {
        self.init(item: item, repository: repository, clock: ContinuousClock())
    }
}
