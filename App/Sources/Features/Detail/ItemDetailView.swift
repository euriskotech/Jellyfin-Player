import JellyfinAPI
import SwiftUI

/// Film or episode page.
struct ItemDetailView: View {
    @Environment(LibraryModel.self) private var library
    @State private var item: BaseItemDto

    init(item: BaseItemDto) {
        _item = State(initialValue: item)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeader(item: item)
                PlaySection(item: item, onPlaybackFinished: refresh)
                    .padding(.horizontal)

                if item.type == .episode, item.seriesID != nil {
                    NavigationLink(value: seriesStub) {
                        Label("Go to \(item.seriesName ?? "show")", systemImage: "tv")
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await refresh() }
    }

    /// Enough of the show for navigation; the show page loads the rest.
    private var seriesStub: BaseItemDto {
        var series = BaseItemDto()
        series.id = item.seriesID
        series.name = item.seriesName
        series.type = .series
        return series
    }

    /// Fetch the full item so the page has the overview, taglines and everything else.
    private func refresh() async {
        guard let id = item.id, let full = try? await library.service.item(id: id) else { return }
        item = full
    }
}
