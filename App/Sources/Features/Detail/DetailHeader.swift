import JellyfinAPI
import SwiftUI

/// Backdrop, title, facts and overview shared by film, episode and show pages.
struct DetailHeader: View {
    @Environment(LibraryModel.self) private var library
    let item: BaseItemDto

    #if os(tvOS)
    private let backdropHeight: CGFloat = 600
    #else
    private let backdropHeight: CGFloat = 260
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RemoteImage(url: library.client.backdropURL(for: item))
                .frame(height: backdropHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        if item.type == .episode, let series = item.seriesName {
                            Text(series).font(.headline).foregroundStyle(.white.opacity(0.85))
                        }
                        Text(item.name ?? "Untitled")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding()
                }

            VStack(alignment: .leading, spacing: 12) {
                FactsLine(item: item)

                if let tagline = item.taglines?.first {
                    Text(tagline).font(.headline).italic()
                }
                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .foregroundStyle(.secondary)
                        #if os(tvOS)
                        .lineLimit(5)
                        #endif
                }
                if let genres = item.genres, !genres.isEmpty {
                    Text(genres.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
}

/// "2019 · 12A · 2h 4m · ★ 7.8 · 3D"
struct FactsLine: View {
    let item: BaseItemDto

    var body: some View {
        let facts: [String] = [
            item.type == .episode ? item.displaySubtitle : item.productionYear.map(String.init),
            item.officialRating,
            item.runtimeText,
            item.communityRating.map { String(format: "★ %.1f", $0) },
            item.is3D ? "3D" : nil,
            item.isPlayed ? "Watched" : nil,
        ].compactMap { $0 }

        Text(facts.joined(separator: " · "))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
