import Domain
import SwiftUI

struct ServerRow: View {
    let server: NetworkServer

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(server.displayName)
                Text("\(Text(server.kindLabel)) · \(server.host)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: server.symbolName)
        }
    }
}
