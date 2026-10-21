import SwiftUI

struct PictureSection: View {
    @Bindable var model: PlayerModel

    var body: some View {
        OptionsSection(title: "Picture") {
            Picker("Picture", selection: $model.fillsScreen) {
                Text("Fit").tag(false)
                Text("Fill").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
