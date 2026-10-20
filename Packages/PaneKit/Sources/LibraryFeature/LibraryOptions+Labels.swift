import Foundation

extension LibrarySortOrder {
    var label: LocalizedStringResource {
        switch self {
        case .dateAdded: "Date Added"
        case .title: "Title"
        case .recentlyPlayed: "Recently Played"
        }
    }
}

extension LibraryFilter {
    var label: LocalizedStringResource {
        switch self {
        case .all: "All Videos"
        case .unwatched: "Unwatched"
        case .inProgress: "In Progress"
        case .watched: "Watched"
        }
    }
}
