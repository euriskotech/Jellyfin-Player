import JellyfinAPI
import SwiftUI

struct HomeView: View {
    @Environment(LibraryModel.self) private var library

    @State private var continueWatching: [BaseItemDto] = []
    @State private var nextUp: [BaseItemDto] = []
    @State private var recentlyAdded: [RecentRow] = []
    @State private var isLoading = false
    @State private var error: String?

    private var isEmpty: Bool {
        continueWatching.isEmpty && nextUp.isEmpty && recentlyAdded.isEmpty && library.homeLibraries.isEmpty
    }

    var body: some View {
        LoadState(isLoading: isLoading, error: error, isEmpty: isEmpty, retry: load) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    LibrariesRow(libraries: library.homeLibraries)
                    ItemRow(title: "Continue Watching", items: continueWatching, style: .landscape)
                    ItemRow(title: "Next Up", items: nextUp, style: .landscape)
                    ForEach(recentlyAdded) { row in
                        ItemRow(title: "Recently Added in \(row.library.name ?? "Library")", items: row.items)
                    }
                }
                .padding(.vertical)
            }
            .refreshable { await load() }
        }
        .navigationTitle("Home")
        .task { if isEmpty { await load() } }
    }

    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await library.loadLibraries()
        } catch {
            self.error = "Couldn't load your libraries. \(error.localizedDescription)"
            return
        }

        let service = library.service
        async let resume = try? service.continueWatching()
        async let upNext = try? service.nextUp()
        continueWatching = await resume ?? []
        nextUp = await upNext ?? []

        var rows: [RecentRow] = []
        for lib in library.recentlyAddedLibraries {
            let items = (try? await service.recentlyAdded(in: lib)) ?? []
            if !items.isEmpty { rows.append(RecentRow(library: lib, items: items)) }
        }
        recentlyAdded = rows
    }
}

struct RecentRow: Identifiable {
    let library: BaseItemDto
    let items: [BaseItemDto]
    var id: String { library.id ?? library.name ?? "" }
}

/// Tiles for each library on the home screen.
private struct LibrariesRow: View {
    @Environment(LibraryModel.self) private var library
    let libraries: [BaseItemDto]

    var body: some View {
        if !libraries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Libraries")
                    .font(.title3.bold())
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: CardMetrics.rowSpacing) {
                        ForEach(libraries) { item in
                            NavigationLink(value: item) {
                                RemoteImage(url: library.client.imageURL(
                                    itemID: item.id,
                                    type: .primary,
                                    tag: item.imageTags?[ImageType.primary.rawValue],
                                    maxWidth: 700
                                ))
                                .frame(width: CardMetrics.landscapeWidth, height: CardMetrics.landscapeWidth * 9 / 16)
                                .overlay {
                                    if item.imageTags?[ImageType.primary.rawValue] == nil {
                                        Text(item.name ?? "Library").font(.headline)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel(item.name ?? "Library")
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
