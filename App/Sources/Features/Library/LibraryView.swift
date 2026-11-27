import JellyfinAPI
import SwiftUI

/// A whole library as a poster grid, loaded in pages as you scroll.
struct LibraryView: View {
    @Environment(LibraryModel.self) private var library
    let libraryItem: BaseItemDto

    @State private var items: [BaseItemDto] = []
    @State private var total = 0
    @State private var sort: LibraryService.Sort = .name
    @State private var isLoading = false
    @State private var error: String?

    private let pageSize = 60

    init(library: BaseItemDto) {
        libraryItem = library
    }

    var body: some View {
        LoadState(isLoading: isLoading, error: error, isEmpty: items.isEmpty, retry: reload) {
            ScrollView {
                PosterGrid(items: items, onItemAppear: loadMoreIfNeeded) {
                    if isLoading { ProgressView().padding() }
                }
            }
        }
        .navigationTitle(libraryItem.name ?? "Library")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(LibraryService.Sort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .onChange(of: sort) { Task { await reload() } }
        .task { if items.isEmpty { await reload() } }
    }

    private func reload() async {
        items = []
        total = 0
        await loadPage()
    }

    private func loadMoreIfNeeded(_ item: BaseItemDto) {
        guard !isLoading, items.count < total else { return }
        // Start the next page when one of the last few items scrolls into view.
        if let index = items.firstIndex(where: { $0.id == item.id }), index >= items.count - 12 {
            Task { await loadPage() }
        }
    }

    private func loadPage() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let page = try await library.service.items(in: libraryItem, sort: sort, startIndex: items.count, limit: pageSize)
            items.append(contentsOf: page.items)
            total = page.total
        } catch {
            self.error = "Couldn't load \(libraryItem.name ?? "this library"). \(error.localizedDescription)"
        }
    }
}
