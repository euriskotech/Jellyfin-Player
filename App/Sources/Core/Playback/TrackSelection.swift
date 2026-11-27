import Foundation
import JellyfinAPI

/// Picks the audio and subtitle tracks to start with, from the user's defaults.
/// A subtitle index of nil means subtitles off.
struct TrackSelection: Equatable {
    var audioIndex: Int?
    var subtitleIndex: Int?

    static func choose(
        from streams: [MediaStream],
        audioLanguage: String,
        subtitleLanguage: String,
        subtitleMode: SubtitleMode
    ) -> TrackSelection {
        let audio = streams.filter { $0.type == .audio }
        let subtitles = streams.filter { $0.type == .subtitle }

        let chosenAudio = audio.first { Languages.matches($0.language, audioLanguage) && $0.isDefault == true }
            ?? audio.first { Languages.matches($0.language, audioLanguage) }
            ?? audio.first { $0.isDefault == true }
            ?? audio.first

        let inLanguage = subtitles.filter { Languages.matches($0.language, subtitleLanguage) }
        let forced = inLanguage.first { $0.isForced == true }
            // Forced tracks are often untagged; one matching the audio language is a good guess.
            ?? subtitles.first { $0.isForced == true && (Languages.matches($0.language, chosenAudio?.language) || $0.language == nil) }
        let full = inLanguage.first { $0.isForced != true && $0.isHearingImpaired != true }
            ?? inLanguage.first { $0.isForced != true }

        let subtitle: MediaStream?
        switch subtitleMode {
        case .off:
            subtitle = nil
        case .forcedOnly:
            subtitle = forced
        case .foreignAudio:
            let audioIsForeign = chosenAudio.map { !Languages.matches($0.language, subtitleLanguage) } ?? false
            subtitle = audioIsForeign ? (full ?? forced) : forced
        case .always:
            subtitle = full ?? forced
        }

        return TrackSelection(audioIndex: chosenAudio?.index, subtitleIndex: subtitle?.index)
    }
}

extension MediaStream {
    /// "English · Dolby Digital 5.1" style label for pickers.
    var trackLabel: String {
        if let displayTitle, !displayTitle.isEmpty {
            return isForced == true && !displayTitle.localizedCaseInsensitiveContains("forced")
                ? "\(displayTitle) (Forced)" : displayTitle
        }
        var parts: [String] = []
        if let language { parts.append(Languages.displayName(language)) }
        if let codec { parts.append(codec.uppercased()) }
        if isForced == true { parts.append("Forced") }
        return parts.isEmpty ? "Track \(index ?? 0)" : parts.joined(separator: " · ")
    }
}
