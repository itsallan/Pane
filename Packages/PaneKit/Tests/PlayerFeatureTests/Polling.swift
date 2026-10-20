@MainActor
func eventually(_ condition: () async -> Bool) async {
    for _ in 0..<400 {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

/// Gives queued engine calls and state deliveries a chance to land before asserting that nothing changed.
@MainActor
func settle() async {
    try? await Task.sleep(for: .milliseconds(50))
}
