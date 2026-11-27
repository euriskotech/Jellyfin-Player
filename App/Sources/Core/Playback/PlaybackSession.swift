import AVFoundation
import Foundation
import JellyfinAPI

/// One play of one item: asks the server how to stream it, builds the AVPlayerItem,
/// and reports start, progress and stop so resume points and watched status stay in sync.
@MainActor
final class PlaybackSession {
    enum PlaybackError: LocalizedError {
        case noMediaSource
        case noStreamURL

        var errorDescription: String? {
            switch self {
            case .noMediaSource: "The server didn't offer a playable version of this item."
            case .noStreamURL: "The server didn't return a stream for this item."
            }
        }
    }

    let item: BaseItemDto
    let selection: TrackSelection
    private let fromBeginning: Bool
    private let client: JellyfinClient
    private let userID: String

    private(set) var playSessionID: String?
    private(set) var mediaSourceID: String?
    private(set) var playMethod: PlayMethod = .directPlay
    /// Subtitle tracks in the order AVPlayer will list them, for matching up the chosen track.
    private(set) var subtitleStreams: [MediaStream] = []
    private(set) var subtitlesBurnedIn = false

    init(item: BaseItemDto, selection: TrackSelection, fromBeginning: Bool = false, library: LibraryModel) {
        self.item = item
        self.selection = selection
        self.fromBeginning = fromBeginning
        client = library.client
        userID = library.session.account.userID
    }

    var startSeconds: Double {
        guard !fromBeginning, let ticks = item.userData?.playbackPositionTicks, ticks > 0, item.userData?.isPlayed != true else { return 0 }
        return Double(ticks) / 10_000_000
    }

    // MARK: Stream

    func makePlayerItem() async throws -> AVPlayerItem {
        guard let itemID = item.id else { throw PlaybackError.noMediaSource }

        var request = PlaybackInfoDto()
        request.userID = userID
        request.deviceProfile = AppDeviceProfile.make()
        request.maxStreamingBitrate = AppDeviceProfile.maxBitrate
        request.enableDirectPlay = true
        request.enableDirectStream = true
        request.enableTranscoding = true
        request.allowAudioStreamCopy = true
        request.allowVideoStreamCopy = true
        request.isAutoOpenLiveStream = true
        request.audioStreamIndex = selection.audioIndex
        // -1 tells the server explicitly that subtitles are off, rather than "use the file's default".
        request.subtitleStreamIndex = selection.subtitleIndex ?? -1
        request.mediaSourceID = item.mediaSources?.first?.id

        let response = try await client.send(
            Paths.getPostedPlaybackInfo(itemID: itemID, parameters: .init(userID: userID), request)
        ).value

        guard let source = response.mediaSources?.first else { throw PlaybackError.noMediaSource }
        playSessionID = response.playSessionID
        mediaSourceID = source.id

        let url: URL
        if let transcodingURL = source.transcodingURL, let full = client.url(path: transcodingURL) {
            url = withAPIKey(full)
            playMethod = source.isSupportsDirectStream == true && transcodingURL.contains("Static=true")
                ? .directStream : .transcode
        } else if source.isSupportsDirectPlay == true || source.isSupportsDirectStream == true {
            var parameters = Paths.GetVideoStreamParameters()
            parameters.isStatic = true
            parameters.mediaSourceID = source.id
            parameters.playSessionID = response.playSessionID
            parameters.deviceID = DeviceIdentity.deviceID
            guard let direct = client.url(with: Paths.getVideoStream(itemID: itemID, parameters: parameters), queryAPIKey: true) else {
                throw PlaybackError.noStreamURL
            }
            url = direct
            playMethod = .directPlay
        } else {
            throw PlaybackError.noStreamURL
        }

        let streams = source.mediaStreams ?? []
        let chosen = streams.first { $0.type == .subtitle && $0.index == selection.subtitleIndex }
        subtitlesBurnedIn = chosen?.deliveryMethod == .encode
        // Subtitles AVPlayer will see as selectable tracks, in file order.
        subtitleStreams = streams.filter { stream in
            guard stream.type == .subtitle else { return false }
            switch playMethod {
            case .directPlay: return stream.isExternal != true
            default: return stream.deliveryMethod == .hls
            }
        }

        return AVPlayerItem(asset: AVURLAsset(url: url))
    }

    private func withAPIKey(_ url: URL) -> URL {
        guard let token = client.accessToken,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        var items = components.queryItems ?? []
        if !items.contains(where: { ["api_key", "apikey"].contains($0.name.lowercased()) }) {
            items.append(URLQueryItem(name: "ApiKey", value: token))
        }
        components.queryItems = items
        return components.url ?? url
    }

    // MARK: Subtitles

    /// Applies the chosen subtitle track (or none) to the player item.
    /// Called once the item is ready, so the file's own "default" flags can't switch subtitles on.
    func applySubtitleSelection(to playerItem: AVPlayerItem) async {
        guard let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible) else { return }

        // Burned-in subtitles are part of the picture; any text track would double them up.
        guard let index = selection.subtitleIndex, !subtitlesBurnedIn else {
            if group.allowsEmptySelection {
                playerItem.select(nil, in: group)
            } else if let forcedOnly = AVMediaSelectionGroup.mediaSelectionOptions(
                from: group.options, withMediaCharacteristics: [.containsOnlyForcedSubtitles]
            ).first {
                playerItem.select(forcedOnly, in: group)
            }
            return
        }

        let options = group.options.filter { !$0.hasMediaCharacteristic(.containsOnlyForcedSubtitles) || isForced(index) }
        guard let stream = subtitleStreams.first(where: { $0.index == index }) else { return }

        // Match by title first (HLS renditions are named after the track), then by position.
        let byName = options.first { option in
            guard let title = stream.displayTitle else { return false }
            return option.displayName == title
        }
        let position = subtitleStreams.firstIndex { $0.index == index }
        let byPosition = position.flatMap { $0 < group.options.count ? group.options[$0] : nil }
        let byLanguage = options.first { Languages.matches($0.extendedLanguageTag ?? $0.locale?.identifier, stream.language) }

        if let option = byName ?? byPosition ?? byLanguage {
            playerItem.select(option, in: group)
        }
    }

    private func isForced(_ index: Int) -> Bool {
        subtitleStreams.first { $0.index == index }?.isForced == true
    }

    // MARK: Reporting

    func reportStart(positionSeconds: Double) async {
        var info = stateInfo(positionSeconds: positionSeconds, isPaused: false)
        info.canSeek = true
        try? await client.send(Paths.reportPlaybackStart(info))
    }

    func reportProgress(positionSeconds: Double, isPaused: Bool) async {
        try? await client.send(Paths.reportPlaybackProgress(stateInfo(positionSeconds: positionSeconds, isPaused: isPaused)))
    }

    func reportStopped(positionSeconds: Double) async {
        var info = PlaybackStopInfo()
        info.itemID = item.id
        info.mediaSourceID = mediaSourceID
        info.playSessionID = playSessionID
        info.positionTicks = ticks(positionSeconds)
        try? await client.send(Paths.reportPlaybackStopped(info))
    }

    private func stateInfo(positionSeconds: Double, isPaused: Bool) -> PlaybackStateInfo {
        var info = PlaybackStateInfo()
        info.itemID = item.id
        info.mediaSourceID = mediaSourceID
        info.playSessionID = playSessionID
        info.playMethod = playMethod
        info.audioStreamIndex = selection.audioIndex
        info.subtitleStreamIndex = selection.subtitleIndex ?? -1
        info.positionTicks = ticks(positionSeconds)
        info.isPaused = isPaused
        return info
    }

    private func ticks(_ seconds: Double) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(seconds * 10_000_000)
    }
}
