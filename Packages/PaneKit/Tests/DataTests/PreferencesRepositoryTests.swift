import Data
import Domain
import Foundation
import Testing

struct PreferencesRepositoryTests {
    @Test func subtitleStyleRoundTrips() async throws {
        let suite = "io.pane.player.tests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsPreferencesRepository(suiteName: suite)
        #expect(try await repository.subtitleStyle() == SubtitleStyle())

        let style = SubtitleStyle(size: .extraLarge, background: .translucent, position: .high)
        try await repository.save(style)

        #expect(try await repository.subtitleStyle() == style)
    }
}
