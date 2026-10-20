import Domain
import Foundation

extension Duration {
    var milliseconds: Int64 {
        let (seconds, attoseconds) = components
        return seconds * 1000 + attoseconds / 1_000_000_000_000_000
    }

    init(milliseconds: Int64) {
        self = .milliseconds(milliseconds)
    }
}

extension MediaItemRecord {
    convenience init(_ item: MediaItem) {
        self.init(id: item.id, title: item.title, sourceKind: .stream, dateAdded: item.dateAdded)
        update(from: item)
    }

    func update(from item: MediaItem) {
        title = item.title
        dateAdded = item.dateAdded
        durationMilliseconds = item.duration?.milliseconds
        bookmark = nil
        streamURL = nil
        shareServerID = nil
        sharePath = nil
        switch item.source {
        case .file(let data):
            sourceKind = .file
            bookmark = data
        case .stream(let url):
            sourceKind = .stream
            streamURL = url
        case .networkShare(let server, let path):
            sourceKind = .networkShare
            shareServerID = server
            sharePath = path
        }
    }

    /// `nil` when the record is missing the field its kind needs, which only a damaged store produces.
    var mediaItem: MediaItem? {
        let source: MediaSource
        switch sourceKind {
        case .file:
            guard let bookmark else { return nil }
            source = .file(bookmark: bookmark)
        case .stream:
            guard let streamURL else { return nil }
            source = .stream(streamURL)
        case .networkShare:
            guard let shareServerID, let sharePath else { return nil }
            source = .networkShare(server: shareServerID, path: sharePath)
        }
        return MediaItem(
            id: id,
            title: title,
            source: source,
            duration: durationMilliseconds.map(Duration.init(milliseconds:)),
            dateAdded: dateAdded,
            folderID: folder?.id
        )
    }
}

extension FolderRecord {
    var libraryFolder: LibraryFolder {
        LibraryFolder(id: id, name: name, dateAdded: dateAdded)
    }
}

extension ProgressRecord {
    var playbackProgress: PlaybackProgress {
        PlaybackProgress(
            position: Duration(milliseconds: positionMilliseconds),
            duration: durationMilliseconds.map(Duration.init(milliseconds:))
        )
    }

    func update(from progress: PlaybackProgress, at date: Date) {
        positionMilliseconds = progress.position.milliseconds
        durationMilliseconds = progress.duration?.milliseconds
        isWatched = false
        updatedAt = date
    }
}
