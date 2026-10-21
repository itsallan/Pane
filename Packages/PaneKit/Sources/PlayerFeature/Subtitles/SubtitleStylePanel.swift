import DesignSystem
import Domain
import SwiftUI

/// Takes the control capsule's place while styling, so the paused frame and the preview line stay in view.
struct SubtitleStylePanel: View {
    @Bindable var appearance: SubtitleAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Size") {
                Picker("Size", selection: $appearance.size) {
                    ForEach(SubtitleStyle.Size.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
            }
            LabeledContent("Background") {
                Picker("Background", selection: $appearance.background) {
                    ForEach(SubtitleStyle.Background.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
            }
            LabeledContent("Position") {
                Picker("Position", selection: $appearance.position) {
                    ForEach(SubtitleStyle.Position.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
            }
            if appearance.waitsForNextVideo {
                Text("Background and position apply from the next video you open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Done", action: appearance.endEditing)
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
        }
        .pickerStyle(.menu)
        .padding(20)
        .frame(maxWidth: Metrics.capsuleMaxWidth)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}
