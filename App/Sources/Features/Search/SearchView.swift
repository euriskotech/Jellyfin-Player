import JellyfinAPI
import SwiftUI

struct SearchView: View {
    @Environment(LibraryModel.self) private var library
    @State private var query = ""
    @State private var results: [BaseItemDto] = []
    @State private var isSearching = false

    var body: some View {
        ScrollView {
            if isSearching && results.isEmpty {
                ProgressView().padding(.top, 60)
            } else if results.isEmpty {
                Text(query.isEmpty ? "Search for films, shows, episodes and collections." : "No results for \u{201C}\(query)\u{201D}.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity)
            } else {
                PosterGrid(items: results)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Films, shows and more")
        .task(id: query) { await search() }
    }

    /// Runs shortly after typing stops; cancelled automatically when the text changes.
    private func search() async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard term.count >= 2 else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        let found = (try? await library.service.search(term)) ?? []
        guard !Task.isCancelled else { return }
        results = (try? await library.removingHidden(found)) ?? found
    }
}
