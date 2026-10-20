import Domain
import SwiftUI

struct EntryStatusText: View {
    let entry: LibraryEntry

    var body: some View {
        if let remaining = entry.remaining {
            Text("\(remaining.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))) left")
        } else if entry.isWatched {
            Label("Watched", systemImage: "checkmark.circle")
        } else if let duration = entry.item.duration {
            Text(duration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
        } else {
            Text("Not played yet")
        }
    }
}
