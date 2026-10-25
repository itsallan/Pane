import SwiftUI

struct PictureSection: View {
    @Bindable var model: PlayerModel

    var body: some View {
        Section {
            Picker("Scaling", selection: $model.fillsScreen) {
                Text("Fit").tag(false)
                Text("Fill").tag(true)
            }
            .pickerStyle(.segmented)
            Button("Next Frame", systemImage: "forward.frame", action: model.stepFrame)
                .disabled(!model.canStepFrame)
            if model.snapshot.isAvailable {
                Button("Save Frame to Photos", systemImage: "camera", action: saveFrame)
                    .disabled(model.snapshot.isSaving)
            }
        } header: {
            Text("Picture")
        } footer: {
            if !model.canStepFrame {
                Text("Pause to step through frames.")
            }
        }
    }

    private func saveFrame() {
        Task { await model.snapshot.capture() }
    }
}
