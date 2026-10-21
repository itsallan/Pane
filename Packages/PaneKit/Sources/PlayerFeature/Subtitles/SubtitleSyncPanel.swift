import DesignSystem
import Domain
import SwiftUI

/// Takes the control capsule's place while syncing, so the video stays in view.
struct SubtitleSyncPanel: View {
    let sync: SubtitleSync

    var body: some View {
        VStack(spacing: 12) {
            switch sync.phase {
            case .picking(let heardAt):
                Text("Which line did you hear?")
                    .font(.headline)
                SubtitleCuePicker(cues: sync.cues, nearest: sync.nearestCue(toHeard: heardAt), onPick: sync.pick)
            case .listening, nil:
                Text("Tap the moment you hear someone speak.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("I Heard a Line", systemImage: "ear", action: sync.heardLine)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
            Button("Cancel", role: .cancel, action: sync.cancel)
                .frame(minHeight: Metrics.minimumHitTarget)
        }
        .padding(20)
        .frame(maxWidth: Metrics.capsuleMaxWidth)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}
