import Foundation
import JellyfinAPI
import Observation

/// Shared library state for the signed-in user: their libraries, what's hidden, and the collection filter.
@MainActor
@Observable
final class LibraryModel {
    let session: UserSession
    let service: LibraryService
    let settings: LibrarySettings
    let playback: PlaybackPreferences

    private(set) var libraries: [BaseItemDto] = []
    private var excludedItemIDsCache: (libraries: Set<String>, ids: Set<String>)?

    init(session: UserSession) {
        self.session = session
        service = LibraryService(session: session)
        settings = LibrarySettings(accountID: session.account.id)
        playback = PlaybackPreferences(accountID: session.account.id, configuration: session.user.configuration)
    }

    var client: JellyfinClient { session.client }

    func loadLibraries() async throws {
        libraries = try await service.libraries()
    }

    /// Libraries shown in the app (not hidden on this device).
    var visibleLibraries: [BaseItemDto] {
        libraries.filter { library in
            guard let id = library.id else { return false }
            return !settings.hiddenLibraryIDs.contains(id)
        }
    }

    /// Libraries for the home screen: visible, and not excluded from "My Media" in Jellyfin.
    var homeLibraries: [BaseItemDto] {
        let excluded = Set(session.user.configuration?.myMediaExcludes ?? [])
        return visibleLibraries.filter { !excluded.contains($0.id ?? "") }
    }

    /// Libraries that get a Recently Added row, respecting Jellyfin's "Latest" exclusions.
    var recentlyAddedLibraries: [BaseItemDto] {
        let excluded = Set(session.user.configuration?.latestItemsExcludes ?? [])
        return homeLibraries.filter { library in
            !excluded.contains(library.id ?? "") && library.collectionType != .boxsets && library.collectionType != .playlists
        }
    }

    /// Libraries whose items must never appear inside a collection:
    /// hidden on this device, or excluded from My Media in Jellyfin.
    var collectionExcludedLibraryIDs: Set<String> {
        settings.hiddenLibraryIDs.union(session.user.configuration?.myMediaExcludes ?? [])
    }

    /// A collection's items with excluded libraries (and, if set, 3D versions) taken out.
    /// This is the fix for 3D films showing up in collections.
    func filteredCollectionItems(_ collection: BaseItemDto) async throws -> [BaseItemDto] {
        let items = try await service.collectionItems(collection)
        return try await removingHidden(items)
    }

    /// Drops items from excluded libraries, and 3D versions when that setting is on.
    func removingHidden(_ items: [BaseItemDto]) async throws -> [BaseItemDto] {
        let excludedIDs = try await excludedItemIDs()
        return items.filter { item in
            if let id = item.id, excludedIDs.contains(id) { return false }
            if let seriesID = item.seriesID, excludedIDs.contains(seriesID) { return false }
            if settings.hide3DInCollections, item.is3D { return false }
            return true
        }
    }

    private func excludedItemIDs() async throws -> Set<String> {
        let libraries = collectionExcludedLibraryIDs
        if libraries.isEmpty { return [] }
        if let cache = excludedItemIDsCache, cache.libraries == libraries { return cache.ids }
        let ids = try await service.itemIDs(inLibraries: libraries)
        excludedItemIDsCache = (libraries, ids)
        return ids
    }
}
