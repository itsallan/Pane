/// Every player open in any window, for the parts of the system that are app-wide rather than per window.
final class OpenPlayers {
    private(set) var sessions: [PlayerSession] = []

    func add(_ session: PlayerSession) {
        guard !sessions.contains(where: { $0 === session }) else { return }
        sessions.append(session)
    }

    func remove(_ session: PlayerSession) {
        sessions.removeAll { $0 === session }
    }
}
