#if os(macOS)
import Foundation
import Observation

/// Files Finder hands over that no window has opened yet.
@Observable
final class OpenedFiles {
    private(set) var pending: [URL] = []

    func add(_ urls: [URL]) {
        pending += urls
    }

    func take() -> [URL] {
        defer { pending = [] }
        return pending
    }
}
#endif
