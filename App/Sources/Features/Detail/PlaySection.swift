import JellyfinAPI
import SwiftUI

/// Play / Resume buttons with audio and subtitle pickers, pre-set from the user's defaults.
struct PlaySection: View {
    @Environment(LibraryModel.self) private var library
    let item: BaseItemDto
    /// Called after the player closes, so the page can refresh its resume point and watched state.
    var onPlaybackFinished: () async -> Void = {}

    @State private var selection = TrackSelection()
    @State private var isStarting = false
    @State private var errorMessage: String?

    private var streams: [MediaStream] {
        item.mediaSources?.first?.mediaStreams ?? item.mediaStreams ?? []
    }

    private var audioStreams: [MediaStream] { streams.filter { $0.type == .audio } }
    private var subtitleStreams: [MediaStream] { streams.filter { $0.type == .subtitle } }

    private var resumeMinutes: Int? {
        guard let ticks = item.userData?.playbackPositionTicks, ticks > 0, !item.isPlayed else { return nil }
        return ticks / 600_000_000
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                if let minutes = resumeMinutes {
                    Button { play(fromBeginning: false) } label: {
                        Label("Resume from \(Self.format(minutes: minutes))", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button { play(fromBeginning: true) } label: {
                        Label("Start Over", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button { play(fromBeginning: true) } label: {
                        Label("Play", systemImage: "play.fill").frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                }
                if isStarting { ProgressView() }
            }
            .disabled(isStarting)

            if audioStreams.count > 1 || !subtitleStreams.isEmpty {
                HStack(spacing: 16) {
                    if audioStreams.count > 1 {
                        Picker(selection: $selection.audioIndex) {
                            ForEach(audioStreams, id: \.index) { stream in
                                Text(stream.trackLabel).tag(stream.index)
                            }
                        } label: {
                            Label("Audio", systemImage: "speaker.wave.2")
                        }
                    }
                    if !subtitleStreams.isEmpty {
                        Picker(selection: $selection.subtitleIndex) {
                            Text("Off").tag(Int?.none)
                            ForEach(subtitleStreams, id: \.index) { stream in
                                Text(stream.trackLabel).tag(stream.index)
                            }
                        } label: {
                            Label("Subtitles", systemImage: "captions.bubble")
                        }
                    }
                }
                .pickerStyle(.menu)
            }

            if let errorMessage {
                Text(errorMessage).font(.callout).foregroundStyle(.red)
            }
        }
        .onAppear(perform: applyDefaults)
        .onChange(of: streams.compactMap(\.index)) { applyDefaults() }
    }

    /// Picks tracks from the user's defaults every time the page loads, so nothing carries over by accident.
    private func applyDefaults() {
        let preferences = library.playback
        selection = TrackSelection.choose(
            from: streams,
            audioLanguage: preferences.audioLanguage,
            subtitleLanguage: preferences.subtitleLanguage,
            subtitleMode: preferences.subtitleMode
        )
    }

    private func play(fromBeginning: Bool) {
        guard !isStarting else { return }
        isStarting = true
        errorMessage = nil
        let session = PlaybackSession(item: item, selection: selection, fromBeginning: fromBeginning, library: library)
        Task {
            defer { isStarting = false }
            do {
                try await PlayerPresenter.shared.play(session) {
                    Task { await onPlaybackFinished() }
                }
            } catch {
                errorMessage = "Couldn't start playback. \(error.localizedDescription)"
            }
        }
    }

    private static func format(minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
