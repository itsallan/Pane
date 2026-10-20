import DesignSystem
import Domain
import SwiftUI

struct OptionsPanel: View {
    let model: PlayerModel

    private static let rates = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Speed") {
                    Picker("Speed", selection: Binding(get: { model.rate }, set: { model.setRate($0) })) {
                        ForEach(Self.rates, id: \.self) { Text($0.rateLabel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                section("Picture") {
                    Picker("Picture", selection: Binding(get: { model.videoScaling == .fill }, set: { _ in model.toggleVideoScaling() })) {
                        Text("Fit").tag(false)
                        Text("Fill").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if !model.chapters.isEmpty {
                    section("Chapters") {
                        ForEach(model.chapters) { chapter in
                            row(chapter.displayName, detail: chapter.start.timecode, isSelected: model.currentChapter == chapter) {
                                model.seek(toChapter: chapter)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 300, idealWidth: 340, maxHeight: 480)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func row(_ title: String, detail: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.timecode)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "checkmark")
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 36)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
