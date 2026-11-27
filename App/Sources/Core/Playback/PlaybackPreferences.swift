import Foundation
import JellyfinAPI
import Observation

/// When subtitles should come on by themselves.
enum SubtitleMode: String, CaseIterable, Identifiable {
    case off
    case forcedOnly
    case foreignAudio
    case always

    var id: Self { self }

    var title: String {
        switch self {
        case .off: "Off"
        case .forcedOnly: "Forced only"
        case .foreignAudio: "When audio isn't in my language"
        case .always: "Always"
        }
    }

    var explanation: String {
        switch self {
        case .off: "Subtitles stay off unless you pick a track."
        case .forcedOnly: "Only forced subtitles, such as translations of foreign dialogue."
        case .foreignAudio: "Full subtitles when the audio isn't in your subtitle language; otherwise only forced ones."
        case .always: "Subtitles in your language whenever there are some."
        }
    }
}

/// Per-user audio and subtitle defaults, stored on this device and applied to every play.
@MainActor
@Observable
final class PlaybackPreferences {
    private let defaults = UserDefaults.standard
    private let accountID: String

    var audioLanguage: String {
        didSet { defaults.set(audioLanguage, forKey: key("audio-language")) }
    }

    var subtitleLanguage: String {
        didSet { defaults.set(subtitleLanguage, forKey: key("subtitle-language")) }
    }

    var subtitleMode: SubtitleMode {
        didSet { defaults.set(subtitleMode.rawValue, forKey: key("subtitle-mode")) }
    }

    /// First run takes its defaults from the user's Jellyfin settings, then the device language.
    init(accountID: String, configuration: UserConfiguration?) {
        self.accountID = accountID
        let stored = { (name: String) in UserDefaults.standard.string(forKey: "\(accountID)|\(name)") }

        audioLanguage = stored("audio-language")
            ?? Languages.normalise(configuration?.audioLanguagePreference)
            ?? Languages.deviceDefault
        subtitleLanguage = stored("subtitle-language")
            ?? Languages.normalise(configuration?.subtitleLanguagePreference)
            ?? Languages.deviceDefault

        if let raw = stored("subtitle-mode"), let mode = SubtitleMode(rawValue: raw) {
            subtitleMode = mode
        } else {
            switch configuration?.subtitleMode {
            case .always: subtitleMode = .always
            case .smart: subtitleMode = .foreignAudio
            case .some(.none): subtitleMode = .off
            // Jellyfin's "Default" follows whatever the file is flagged with, which is how
            // subtitles end up switching themselves on. Forced-only is the safer starting point.
            default: subtitleMode = .forcedOnly
            }
        }
    }

    private func key(_ name: String) -> String { "\(accountID)|\(name)" }
}
