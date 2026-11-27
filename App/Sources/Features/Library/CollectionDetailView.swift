import JellyfinAPI
import SwiftUI

/// The films in a collection, leaving out anything from hidden libraries (such as a 3D library).
struct CollectionDetailView: View {
    @Environment(LibraryModel.self) private var library
    let collection: BaseItemDto

    @State private var items: [BaseItemDto] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        LoadState(
            isLoading: isLoading || !loaded,
            error: error,
            isEmpty: items.isEmpty,
            emptyText: "Nothing in this collection is in your visible libraries.",
            retry: load
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let overview = collection.overview, !overview.isEmpty {
                        Text(overview)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    PosterGrid(items: items)
                }
                .padding(.top)
            }
        }
        .navigationTitle(collection.name ?? "Collection")
        .task { if !loaded { await load() } }
    }

    private func load() async {
        isLoading = true
        error = nil
        defer {
            isLoading = false
            loaded = true
        }
        do {
            items = try await library.filteredCollectionItems(collection)
        } catch {
            self.error = "Couldn't load this collection. \(error.localizedDescription)"
        }
    }
}
