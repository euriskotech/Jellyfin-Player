import Foundation

/// Language code helpers. Jellyfin reports ISO 639-2 codes, sometimes the bibliographic form
/// ("ger", "fre"), so everything is normalised to the terminology form ("deu", "fra") before comparing.
enum Languages {
    private static let bibliographicToTerminology: [String: String] = [
        "alb": "sqi", "arm": "hye", "baq": "eus", "bur": "mya", "chi": "zho", "cze": "ces",
        "dut": "nld", "fre": "fra", "geo": "kat", "ger": "deu", "gre": "ell", "ice": "isl",
        "mac": "mkd", "mao": "mri", "may": "msa", "per": "fas", "rum": "ron", "slo": "slk",
        "tib": "bod", "wel": "cym",
    ]

    /// Common choices offered in Settings.
    static let common = [
        "eng", "fra", "deu", "spa", "ita", "por", "nld", "swe", "nor", "dan", "fin", "pol",
        "ces", "hun", "ell", "tur", "rus", "ara", "heb", "hin", "jpn", "kor", "zho",
    ]

    static func normalise(_ code: String?) -> String? {
        guard var code = code?.trimmingCharacters(in: .whitespaces).lowercased(), !code.isEmpty else { return nil }
        if let dash = code.firstIndex(where: { $0 == "-" || $0 == "_" }) {
            code = String(code[..<dash])
        }
        if code.count == 2 {
            return Locale.Language.LanguageCode(code).identifier(.alpha3) ?? code
        }
        return bibliographicToTerminology[code] ?? code
    }

    static func matches(_ a: String?, _ b: String?) -> Bool {
        guard let a = normalise(a), let b = normalise(b) else { return false }
        return a == b
    }

    /// The device's own language, used as the first-run default.
    static var deviceDefault: String {
        normalise(Locale.current.language.languageCode?.identifier) ?? "eng"
    }

    static func displayName(_ code: String) -> String {
        let normalised = normalise(code) ?? code
        let twoLetter = Locale.Language.LanguageCode(normalised).identifier(.alpha2) ?? normalised
        return Locale.current.localizedString(forLanguageCode: twoLetter)?.capitalized ?? code.uppercased()
    }
}
