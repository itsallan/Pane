import SwiftUI

/// An ordered list: tracks are matched against the first language, then the next.
struct LanguageListScreen: View {
    let title: LocalizedStringKey
    @Binding var languages: [Locale.Language]

    var body: some View {
        Form {
            Section {
                ForEach(languages, id: \.minimalIdentifier) { language in
                    Text(language.displayName)
                }
                .onDelete(perform: remove)
                .onMove(perform: move)
                NavigationLink {
                    LanguagePickerScreen(excluding: languages, onPick: add)
                } label: {
                    Label("Add Language", systemImage: "plus")
                }
            } footer: {
                Text("Pane picks the first track in a language near the top of this list. Drag to reorder.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
        #if os(iOS)
        .toolbar { EditButton() }
        #endif
    }

    private func remove(at offsets: IndexSet) {
        languages.remove(atOffsets: offsets)
    }

    private func move(from source: IndexSet, to destination: Int) {
        languages.move(fromOffsets: source, toOffset: destination)
    }

    private func add(_ language: Locale.Language) {
        languages.append(language)
    }
}
