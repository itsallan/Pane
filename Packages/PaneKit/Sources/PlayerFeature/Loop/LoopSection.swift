import DesignSystem
import SwiftUI

struct LoopSection: View {
    let loop: ABLoop

    var body: some View {
        OptionsSection(title: "Repeat") {
            HStack {
                Button(markTitle, systemImage: markSymbol, action: loop.mark)
                    .buttonStyle(.bordered)
                Spacer()
                Text(status)
                    .font(.timecode)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var markTitle: LocalizedStringKey {
        if loop.range != nil { return "Clear A-B Loop" }
        return loop.start == nil ? "Set Loop Start" : "Set Loop End"
    }

    private var markSymbol: String {
        if loop.range != nil { return "xmark" }
        return loop.start == nil ? "a.circle" : "b.circle"
    }

    private var status: String {
        if let range = loop.range {
            return "\(range.lowerBound.timecode)–\(range.upperBound.timecode)"
        }
        return loop.start.map { String(localized: "A at \($0.timecode)") } ?? ""
    }
}
