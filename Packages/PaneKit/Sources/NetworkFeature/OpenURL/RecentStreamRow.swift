import Domain
import SwiftUI

struct RecentStreamRow: View {
    let stream: RecentStream

    var body: some View {
        VStack(alignment: .leading) {
            Text(stream.url.host(percentEncoded: false) ?? stream.url.absoluteString)
            Text(stream.url.absoluteString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
