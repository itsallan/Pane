import Domain
import Foundation

extension PlayerModel {
    public var canSlowDown: Bool { rate > Self.rates.lowerBound }
    public var canSpeedUp: Bool { rate < Self.rates.upperBound }

    /// Moves to the next quarter step, so an odd rate from the slider lands back on the grid.
    public func slowDown() {
        setRate(((rate - Self.rateStep) / Self.rateStep).rounded(.up) * Self.rateStep)
    }

    public func speedUp() {
        setRate(((rate + Self.rateStep) / Self.rateStep).rounded(.down) * Self.rateStep)
    }

    public func raiseVolume() {
        revealControls()
        setVolume(((volume + Self.volumeStep) * 10).rounded() / 10)
    }

    public func lowerVolume() {
        revealControls()
        setVolume(((volume - Self.volumeStep) * 10).rounded() / 10)
    }

    /// L: plays, and each further press while playing goes faster.
    public func shuttleForward() {
        lastShuttleBack = nil
        guard isPlaybackActive, status != .ended else {
            togglePlayback()
            return
        }
        revealControls()
        guard let next = Self.shuttleRates.first(where: { $0 > rate }) else { return }
        let before = rateBeforeShuttle ?? rate
        setRate(next)
        rateBeforeShuttle = before
    }

    /// K: pauses and drops any shuttle speed.
    public func shuttleStop() {
        lastShuttleBack = nil
        endShuttle()
        pause()
    }

    // libvlc can't play in reverse, so J jumps back instead, doubling the jump on each press that follows quickly.
    public func shuttleBackward() {
        endShuttle()
        let now = elapsed()
        var step = 0
        if let lastShuttleBack, now - lastShuttleBack.at <= Self.shuttleRepeatWindow {
            step = min(lastShuttleBack.step + 1, Self.maxShuttleBackStep)
        }
        lastShuttleBack = (step, now)
        skip(by: .zero - skipInterval * (1 << step))
    }

    private func endShuttle() {
        guard let rateBeforeShuttle else { return }
        self.rateBeforeShuttle = nil
        setRate(rateBeforeShuttle)
    }
}
