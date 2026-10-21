import DesignSystem
import Domain
import SwiftUI

struct SubtitleCuePicker: View {
    let cues: [SubtitleCue]
    let nearest: SubtitleCue?
    let onPick: (SubtitleCue) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(cues) { cue in
                        SubtitleCueRow(cue: cue, isNearest: cue == nearest, onPick: onPick)
                    }
                }
            }
            .frame(maxHeight: 260)
            .onAppear {
                guard let nearest else { return }
                proxy.scrollTo(nearest.id, anchor: .center)
            }
        }
    }
}
