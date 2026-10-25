import Foundation

/// Light, dark or whatever the system uses. Kept in UserDefaults through `@AppStorage`, because it has to apply
/// on the first frame, before anything async could read a repository.
public enum AppAppearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    public static let storageKey = "appearance"
}
