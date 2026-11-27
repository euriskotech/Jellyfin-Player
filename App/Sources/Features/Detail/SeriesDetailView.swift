import JellyfinAPI
import SwiftUI

/// Show page with a season picker and its episodes.
struct SeriesDetailView: View {
    @Environment(LibraryModel.self) private var library
    @State private var series: BaseItemDto
    /// Season to open on, when arriving from a season rather than the show.
    private let initialSeasonID: String?

    @State private var seasons: [BaseItemDto] = []
    @State private var selectedSeasonID: String?
    @State private var episodes: [BaseItemDto] = []
    @State private var isLoadingEpisodes = false

    init(item: BaseItemDto) {
        if item.type == .season {
            var series = BaseItemDto()
            series.id = item.seriesID
            series.name = item.seriesName
            series.type = .series
            _series = State(initialValue: series)
            initialSeasonID = item.id
        } else {
            _series = State(initialValue: item)
            initialSeasonID = nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeader(item: series)

                if !seasons.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(seasons) { season in
                                Button(season.name ?? "Season") {
                                    selectedSeasonID = season.id
                                }
                                .buttonStyle(.bordered)
                                .tint(season.id == selectedSeasonID ? .accentColor : .secondary)
                            }
                        }
                        .padding(.horizontal)
                        #if os(tvOS)
                        .padding(.vertical, 20)
                        #endif
                    }
                }

                if isLoadingEpisodes {
                    ProgressView().frame(maxWidth: .infinity)
                }

                LazyVStack(alignment: .leading, spacing: CardMetrics.rowSpacing) {
                    ForEach(episodes) { episode in
                        NavigationLink(value: episode) {
                            EpisodeRow(episode: episode)
                        }
                        .cardButtonStyle()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
        .onChange(of: selectedSeasonID) { Task { await loadEpisodes() } }
    }

    private func load() async {
        if let id = series.id, let full = try? await library.service.item(id: id) {
            series = full
        }
        guard seasons.isEmpty else { return }
        seasons = (try? await library.service.seasons(of: series)) ?? []
        // Open on the requested season, else the first one with something unwatched.
        selectedSeasonID = initialSeasonID
            ?? seasons.first(where: { ($0.userData?.unplayedItemCount ?? 0) > 0 })?.id
            ?? seasons.first?.id
    }

    private func loadEpisodes() async {
        guard let season = seasons.first(where: { $0.id == selectedSeasonID }) else { return }
        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }
        episodes = (try? await library.service.episodes(of: series, season: season)) ?? []
    }
}

private struct EpisodeRow: View {
    let episode: BaseItemDto

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            LandscapeCardImage(item: episode)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(episode.indexNumber.map { "\($0). " } ?? "")\(episode.name ?? "Episode")")
                    .font(.headline)
                    .lineLimit(2)
                if let runtime = episode.runtimeText {
                    Text(runtime).font(.caption).foregroundStyle(.secondary)
                }
                if let overview = episode.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Just the image part of a landscape card, for list rows.
private struct LandscapeCardImage: View {
    @Environment(LibraryModel.self) private var library
    let item: BaseItemDto

    #if os(tvOS)
    private let width: CGFloat = 360
    #else
    private let width: CGFloat = 150
    #endif

    var body: some View {
        RemoteImage(url: library.client.landscapeURL(for: item))
            .frame(width: width, height: width * 9 / 16)
            .overlay(alignment: .topTrailing) {
                if item.isPlayed { WatchedBadge() }
            }
            .overlay(alignment: .bottom) {
                if let progress = item.progress, !item.isPlayed { ProgressBar(value: progress) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
