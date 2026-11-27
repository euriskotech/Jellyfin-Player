import JellyfinAPI
import SwiftUI

enum CardMetrics {
    #if os(tvOS)
    static let posterWidth: CGFloat = 220
    static let landscapeWidth: CGFloat = 420
    static let rowSpacing: CGFloat = 40
    static let gridMinimum: CGFloat = 220
    #else
    static let posterWidth: CGFloat = 120
    static let landscapeWidth: CGFloat = 260
    static let rowSpacing: CGFloat = 14
    static let gridMinimum: CGFloat = 110
    #endif
}

/// Loads a remote image with a neutral placeholder.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
    }
}

/// Thin watched-progress bar along the bottom of a card.
struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.5))
                Capsule().fill(Color.accentColor).frame(width: proxy.size.width * value)
            }
        }
        .frame(height: 4)
        .padding(6)
    }
}

struct WatchedBadge: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.accentColor)
            .font(.title3)
            .padding(6)
    }
}

/// 2:3 poster with title underneath.
struct PosterCard: View {
    @Environment(LibraryModel.self) private var library
    let item: BaseItemDto
    var width: CGFloat = CardMetrics.posterWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: library.client.posterURL(for: item))
                .frame(width: width, height: width * 1.5)
                .overlay(alignment: .topTrailing) {
                    if item.isPlayed { WatchedBadge() }
                }
                .overlay(alignment: .bottom) {
                    if let progress = item.progress, !item.isPlayed { ProgressBar(value: progress) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.displayTitle)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            if let subtitle = item.displaySubtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

/// 16:9 card for Continue Watching, Next Up and episodes.
struct LandscapeCard: View {
    @Environment(LibraryModel.self) private var library
    let item: BaseItemDto
    var width: CGFloat = CardMetrics.landscapeWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: library.client.landscapeURL(for: item))
                .frame(width: width, height: width * 9 / 16)
                .overlay(alignment: .topTrailing) {
                    if item.isPlayed { WatchedBadge() }
                }
                .overlay(alignment: .bottom) {
                    if let progress = item.progress, !item.isPlayed { ProgressBar(value: progress) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.displayTitle)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            if let subtitle = item.displaySubtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

/// Button style that gives cards the focus lift on Apple TV and stays plain on touch screens.
struct CardButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(tvOS)
        content.buttonStyle(.card)
        #else
        content.buttonStyle(.plain)
        #endif
    }
}

extension View {
    func cardButtonStyle() -> some View { modifier(CardButtonStyleModifier()) }
}

/// A titled horizontal row of items.
struct ItemRow: View {
    enum Style { case poster, landscape }

    let title: String
    let items: [BaseItemDto]
    var style: Style = .poster

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title3.bold())
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: CardMetrics.rowSpacing) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                switch style {
                                case .poster: PosterCard(item: item)
                                case .landscape: LandscapeCard(item: item)
                                }
                            }
                            .cardButtonStyle()
                        }
                    }
                    .padding(.horizontal)
                    #if os(tvOS)
                    .padding(.vertical, 30)
                    #endif
                }
                #if os(tvOS)
                .scrollClipDisabled()
                #endif
            }
        }
    }
}

/// Grid of posters used for libraries, collections and search.
struct PosterGrid<Footer: View>: View {
    let items: [BaseItemDto]
    var onItemAppear: ((BaseItemDto) -> Void)?
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: CardMetrics.gridMinimum), spacing: CardMetrics.rowSpacing, alignment: .top)],
                  spacing: CardMetrics.rowSpacing * 1.5) {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    PosterCard(item: item, width: CardMetrics.gridMinimum)
                }
                .cardButtonStyle()
                .onAppear { onItemAppear?(item) }
            }
        }
        .padding()
        footer()
    }
}

extension PosterGrid where Footer == EmptyView {
    init(items: [BaseItemDto], onItemAppear: ((BaseItemDto) -> Void)? = nil) {
        self.init(items: items, onItemAppear: onItemAppear, footer: { EmptyView() })
    }
}

/// Simple loading / error / empty wrapper.
struct LoadState<Content: View>: View {
    let isLoading: Bool
    let error: String?
    let isEmpty: Bool
    var emptyText = "Nothing here yet."
    let retry: () async -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        if let error, isEmpty {
            VStack(spacing: 16) {
                Label(error, systemImage: "exclamationmark.triangle")
                    .multilineTextAlignment(.center)
                Button("Try Again") { Task { await retry() } }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content()
        }
    }
}
