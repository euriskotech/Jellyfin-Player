import Foundation
import JellyfinAPI

/// Tells the server what Apple's built-in player (AVPlayer) can handle, so it knows when it can
/// send the file as-is and when it has to remux or transcode to HLS.
enum AppDeviceProfile {
    static let maxBitrate = 120_000_000

    static func make() -> DeviceProfile {
        var profile = DeviceProfile()
        profile.name = DeviceIdentity.clientName
        profile.maxStreamingBitrate = maxBitrate
        profile.maxStaticBitrate = maxBitrate

        profile.directPlayProfiles = [
            DirectPlayProfile(
                audioCodec: "aac,ac3,eac3,alac,flac,mp3",
                container: "mp4,m4v,mov",
                type: .video,
                videoCodec: "h264,hevc"
            ),
        ]

        // HLS with fragmented MP4 segments works for both H.264 and HEVC on AVPlayer.
        var hls = TranscodingProfile(
            protocol: .hls,
            audioCodec: "aac,ac3,eac3",
            container: "mp4",
            context: .streaming,
            maxAudioChannels: "6",
            minSegments: 2,
            type: .video,
            videoCodec: "hevc,h264"
        )
        hls.isBreakOnNonKeyFrames = true
        hls.enableSubtitlesInManifest = true
        profile.transcodingProfiles = [hls]

        // Text subtitles AVPlayer can show inside an MP4, as WebVTT in the HLS manifest, or burned in
        // as a last resort for picture-based subtitles (PGS, VobSub) it can't render.
        let embedded = ["mov_text", "tx3g"].map { SubtitleProfile(format: $0, method: .embed) }
        let inManifest = ["vtt", "webvtt", "srt", "subrip", "ass", "ssa", "mov_text", "tx3g"]
            .map { SubtitleProfile(format: $0, method: .hls) }
        let burnedIn = ["pgs", "pgssub", "dvdsub", "dvbsub", "vobsub", "sub"]
            .map { SubtitleProfile(format: $0, method: .encode) }
        profile.subtitleProfiles = embedded + inManifest + burnedIn

        return profile
    }
}
