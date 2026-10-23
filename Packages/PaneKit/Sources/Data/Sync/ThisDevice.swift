import Foundation

/// A random identifier for this installation. It lives in UserDefaults, which never syncs,
/// so a record stamped with it can tell which device it came from.
enum ThisDevice {
    private static let key = "deviceIdentifier"

    static var identifier: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: key)
        return created
    }
}
