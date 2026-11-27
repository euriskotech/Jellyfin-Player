import Foundation

/// Turns whatever the user typed ("jellyfin.local", "192.168.1.10:8096", "https://media.example.com")
/// into the list of URLs worth trying, most likely first.
enum ServerAddress {
    static let defaultPort = 8096

    static func candidates(for input: String) -> [URL] {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        guard !text.isEmpty else { return [] }

        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return [URL(string: text)].compactMap { $0 }
        }

        let hasPort = text.split(separator: "/").first?.contains(":") ?? false
        let strings: [String] = hasPort
            ? ["http://\(text)", "https://\(text)"]
            : ["https://\(text)", "http://\(text):\(defaultPort)", "http://\(text)"]
        return strings.compactMap(URL.init(string:))
    }
}
