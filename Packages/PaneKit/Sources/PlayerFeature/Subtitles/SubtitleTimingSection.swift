import SwiftUI

struct SubtitleTimingSection: View {
    let sync: SubtitleSync
    let onSyncByEar: () -> Void

    var body: some View {
        Section {
            Stepper(onIncrement: later, onDecrement: earlier) {
                LabeledContent("Delay", value: sync.delay.delayDescription)
            }
            .accessibilityValue(sync.delay.delayDescription)
            if sync.delay != .zero {
                Button("Reset Delay", systemImage: "arrow.uturn.backward", action: sync.resetDelay)
            }
            Button("Sync by Ear…", systemImage: "ear", action: onSyncByEar)
                .disabled(!sync.canSyncByEar)
        } header: {
            Text("Timing")
        } footer: {
            Text(sync.canSyncByEar
                ? "Tap when you hear a line, then pick that line from the file."
                : "Sync by ear works with subtitle files you add.")
        }
    }

    private func later() {
        sync.nudge(by: SubtitleSync.step)
    }

    private func earlier() {
        sync.nudge(by: .zero - SubtitleSync.step)
    }
}
