import Foundation
import JellyfinAPI

/// All the library queries the app makes, for one signed-in user.
struct LibraryService {
    let client: JellyfinClient
    let userID: String

    init(session: UserSession) {
        client = session.client
        userID = session.account.userID
    }

    /// Fields the browsing screens need beyond the defaults.
    static let listFields: [ItemFields] = [.primaryImageAspectRatio, .overview, .genres, .childCount]

    // MARK: Home

    func libraries() async throws -> [BaseItemDto] {
        let result = try await client.send(Paths.getUserViews(parameters: .init(userID: userID))).value
        return result.items ?? []
    }

    func continueWatching(limit: Int = 20) async throws -> [BaseItemDto] {
        let parameters = Paths.GetResumeItemsParameters(
            userID: userID,
            limit: limit,
            fields: Self.listFields,
            mediaTypes: [.video],
            enableUserData: true,
            enableImageTypes: [.primary, .backdrop, .thumb]
        )
        return try await client.send(Paths.getResumeItems(parameters: parameters)).value.items ?? []
    }

    func nextUp(limit: Int = 20) async throws -> [BaseItemDto] {
        let parameters = Paths.GetNextUpParameters(
            userID: userID,
            limit: limit,
            fields: Self.listFields,
            enableImageTypes: [.primary, .backdrop, .thumb],
            enableUserData: true,
            enableResumable: false
        )
        return try await client.send(Paths.getNextUp(parameters: parameters)).value.items ?? []
    }

    func recentlyAdded(in library: BaseItemDto, limit: Int = 20) async throws -> [BaseItemDto] {
        let parameters = Paths.GetLatestMediaParameters(
            userID: userID,
            parentID: library.id,
            fields: Self.listFields,
            enableUserData: true,
            limit: limit,
            isGroupItems: true
        )
        return try await client.send(Paths.getLatestMedia(parameters: parameters)).value
    }

    // MARK: Libraries

    enum Sort: String, CaseIterable, Identifiable {
        case name, dateAdded, year, rating

        var id: Self { self }

        var title: String {
            switch self {
            case .name: "Name"
            case .dateAdded: "Date Added"
            case .year: "Year"
            case .rating: "Rating"
            }
        }

        var sortBy: [ItemSortBy] {
            switch self {
            case .name: [.sortName]
            case .dateAdded: [.dateCreated, .sortName]
            case .year: [.productionYear, .sortName]
            case .rating: [.communityRating, .sortName]
            }
        }

        var order: [JellyfinAPI.SortOrder] {
            self == .name ? [.ascending] : [.descending, .ascending]
        }
    }

    /// Item types to list for a library, based on what kind of library it is.
    static func itemTypes(for library: BaseItemDto) -> [BaseItemKind]? {
        switch library.collectionType {
        case .movies: [.movie]
        case .tvshows: [.series]
        case .boxsets: [.boxSet]
        case .homevideos: [.video]
        default: nil
        }
    }

    func items(
        in library: BaseItemDto,
        sort: Sort,
        startIndex: Int,
        limit: Int
    ) async throws -> (items: [BaseItemDto], total: Int) {
        var parameters = Paths.GetItemsParameters(userID: userID)
        parameters.parentID = library.id
        parameters.isRecursive = true
        parameters.includeItemTypes = Self.itemTypes(for: library)
        parameters.sortBy = sort.sortBy
        parameters.sortOrder = sort.order
        parameters.startIndex = startIndex
        parameters.limit = limit
        parameters.fields = Self.listFields
        parameters.enableUserData = true
        parameters.enableTotalRecordCount = true
        let result = try await client.send(Paths.getItems(parameters: parameters)).value
        return (result.items ?? [], result.totalRecordCount ?? 0)
    }

    /// Everything inside a collection (box set), in release order.
    func collectionItems(_ collection: BaseItemDto) async throws -> [BaseItemDto] {
        var parameters = Paths.GetItemsParameters(userID: userID)
        parameters.parentID = collection.id
        parameters.sortBy = [.productionYear, .premiereDate, .sortName]
        parameters.sortOrder = [.ascending]
        parameters.fields = Self.listFields
        parameters.enableUserData = true
        return try await client.send(Paths.getItems(parameters: parameters)).value.items ?? []
    }

    /// IDs of every film, show and episode in the given libraries, so they can be filtered out of collections.
    func itemIDs(inLibraries libraryIDs: Set<String>) async throws -> Set<String> {
        var ids = Set<String>()
        for libraryID in libraryIDs {
            var parameters = Paths.GetItemsParameters(userID: userID)
            parameters.parentID = libraryID
            parameters.isRecursive = true
            parameters.includeItemTypes = [.movie, .series, .video]
            parameters.enableUserData = false
            parameters.enableImages = false
            parameters.fields = []
            let items = try await client.send(Paths.getItems(parameters: parameters)).value.items ?? []
            ids.formUnion(items.compactMap(\.id))
        }
        return ids
    }

    // MARK: Details

    func item(id: String) async throws -> BaseItemDto {
        try await client.send(Paths.getItem(itemID: id, userID: userID)).value
    }

    func seasons(of series: BaseItemDto) async throws -> [BaseItemDto] {
        guard let seriesID = series.id else { return [] }
        let parameters = Paths.GetSeasonsParameters(userID: userID, fields: Self.listFields, enableUserData: true)
        return try await client.send(Paths.getSeasons(seriesID: seriesID, parameters: parameters)).value.items ?? []
    }

    func episodes(of series: BaseItemDto, season: BaseItemDto) async throws -> [BaseItemDto] {
        guard let seriesID = series.id ?? season.seriesID else { return [] }
        let parameters = Paths.GetEpisodesParameters(
            userID: userID,
            fields: Self.listFields,
            seasonID: season.id,
            enableUserData: true
        )
        return try await client.send(Paths.getEpisodes(seriesID: seriesID, parameters: parameters)).value.items ?? []
    }

    // MARK: Search

    func search(_ term: String, limit: Int = 60) async throws -> [BaseItemDto] {
        var parameters = Paths.GetItemsParameters(userID: userID)
        parameters.searchTerm = term
        parameters.isRecursive = true
        parameters.includeItemTypes = [.movie, .series, .episode, .boxSet]
        parameters.limit = limit
        parameters.fields = Self.listFields
        parameters.enableUserData = true
        return try await client.send(Paths.getItems(parameters: parameters)).value.items ?? []
    }
}
