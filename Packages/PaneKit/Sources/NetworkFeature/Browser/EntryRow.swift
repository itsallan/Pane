import Domain
import SwiftUI

struct EntryRow: View {
    let entry: NetworkEntry

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(entry.name)
                    .lineLimit(2)
                if !entry.isDirectory, !entry.isPlayable {
                    Text("Unsupported format")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let sizeText = entry.sizeText {
                    Text(sizeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: entry.symbolName)
        }
    }
}
