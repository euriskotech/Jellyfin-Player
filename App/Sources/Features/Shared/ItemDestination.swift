import JellyfinAPI
import SwiftUI

/// Decides which screen an item opens.
struct ItemDestination: View {
    let item: BaseItemDto

    var body: some View {
        switch item.type {
        case .collectionFolder, .userView, .folder:
            LibraryView(library: item)
        case .boxSet:
            CollectionDetailView(collection: item)
        case .series, .season:
            SeriesDetailView(item: item)
        default:
            ItemDetailView(item: item)
        }
    }
}

extension View {
    /// Adds item navigation to a NavigationStack.
    func itemNavigation() -> some View {
        navigationDestination(for: BaseItemDto.self) { item in
            ItemDestination(item: item)
        }
    }
}
