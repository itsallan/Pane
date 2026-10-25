import SwiftUI

struct LanguagePickerScreen: View {
    let excluding: [Locale.Language]
    let onPick: (Locale.Language) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(matches, id: \.minimalIdentifier) { language in
            Button(language.displayName) {
                onPick(language)
                dismiss()
            }
        }
        .searchable(text: $query)
        .navigationTitle("Add Language")
    }

    private var matches: [Locale.Language] {
        let taken = Set(excluding.map(\.minimalIdentifier))
        let available = LanguagePickerScreen.all.filter { !taken.contains($0.minimalIdentifier) }
        guard !query.isEmpty else { return available }
        return available.filter { $0.displayName.localizedStandardContains(query) }
    }

    // Two-letter codes cover every language with a name people would look for; the three-letter ones add thousands of obscure entries.
    private static let all: [Locale.Language] = Locale.LanguageCode.isoLanguageCodes
        .filter { $0.identifier.count == 2 }
        .map { Locale.Language(languageCode: $0) }
        .filter { Locale.current.localizedString(forIdentifier: $0.minimalIdentifier) != nil }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
}
