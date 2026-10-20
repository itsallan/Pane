import Foundation

extension Locale.Language {
    /// Parses a container's language tag: an ISO 639 code (`en`, `eng`, `fre`) or an English or native name (`English`, `Français`).
    init?(trackTag tag: String) {
        let tag = tag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return nil }
        let code = Self.bibliographicCodes[tag.lowercased()] ?? tag
        let language = Locale.Language(identifier: code)
        if let languageCode = language.languageCode, languageCode.isISOLanguage {
            // Undetermined, uncoded, multiple and no linguistic content: ISO codes that name no language.
            guard !["und", "mis", "mul", "zxx"].contains(languageCode.identifier) else { return nil }
            self = language
            return
        }
        guard let named = Self.languageNamed(tag) else { return nil }
        self = named
    }

    func matches(_ other: Locale.Language) -> Bool {
        guard let lhs = baseCode, let rhs = other.baseCode else { return false }
        return lhs == rhs
    }

    private var baseCode: String? {
        guard let languageCode else { return nil }
        return languageCode.identifier(.alpha2) ?? languageCode.identifier
    }

    private static func languageNamed(_ name: String) -> Locale.Language? {
        let english = Locale(identifier: "en")
        let code = Locale.LanguageCode.isoLanguageCodes.first { code in
            let native = Locale(identifier: code.identifier)
            return [english, native].contains {
                $0.localizedString(forLanguageCode: code.identifier)?.caseInsensitiveCompare(name) == .orderedSame
            }
        }
        return code.map { Locale.Language(languageCode: $0) }
    }

    // Matroska tags tracks with ISO 639-2/B codes, which Foundation doesn't map to their 639-1 equivalents.
    private static let bibliographicCodes: [String: String] = [
        "alb": "sq", "arm": "hy", "baq": "eu", "bur": "my", "chi": "zh", "cze": "cs", "dut": "nl",
        "fre": "fr", "geo": "ka", "ger": "de", "gre": "el", "ice": "is", "mac": "mk", "mao": "mi",
        "may": "ms", "per": "fa", "rum": "ro", "slo": "sk", "tib": "bo", "wel": "cy",
    ]
}

extension MediaTrack {
    func matches(_ language: Locale.Language) -> Bool {
        guard let tag = self.language, let trackLanguage = Locale.Language(trackTag: tag) else { return false }
        return trackLanguage.matches(language)
    }

    func sharesLanguage(with other: MediaTrack) -> Bool {
        guard let tag = other.language, let otherLanguage = Locale.Language(trackTag: tag) else { return false }
        return matches(otherLanguage)
    }
}
