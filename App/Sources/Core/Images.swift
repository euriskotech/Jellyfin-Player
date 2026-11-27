import Foundation
import JellyfinAPI

extension JellyfinClient {
    /// URL for one of an item's images, sized for the screen it's shown on.
    func imageURL(itemID: String?, type: ImageType, tag: String?, maxWidth: Int) -> URL? {
        guard let itemID, let tag else { return nil }
        let parameters = Paths.GetItemImageParameters(maxWidth: maxWidth, quality: 90, tag: tag)
        return url(with: Paths.getItemImage(itemID: itemID, imageType: type.rawValue, parameters: parameters))
    }

    /// Portrait poster. Episodes and seasons fall back to their show's poster.
    func posterURL(for item: BaseItemDto, maxWidth: Int = 400) -> URL? {
        if let tag = item.imageTags?[ImageType.primary.rawValue], item.type != .episode {
            return imageURL(itemID: item.id, type: .primary, tag: tag, maxWidth: maxWidth)
        }
        return imageURL(itemID: item.seriesID, type: .primary, tag: item.seriesPrimaryImageTag, maxWidth: maxWidth)
    }

    /// Landscape artwork: an episode's still, otherwise a thumb or backdrop from the item or its show.
    func landscapeURL(for item: BaseItemDto, maxWidth: Int = 700) -> URL? {
        if item.type == .episode, let tag = item.imageTags?[ImageType.primary.rawValue] {
            return imageURL(itemID: item.id, type: .primary, tag: tag, maxWidth: maxWidth)
        }
        if let tag = item.imageTags?[ImageType.thumb.rawValue] {
            return imageURL(itemID: item.id, type: .thumb, tag: tag, maxWidth: maxWidth)
        }
        if let tag = item.parentThumbImageTag {
            return imageURL(itemID: item.parentThumbItemID, type: .thumb, tag: tag, maxWidth: maxWidth)
        }
        return backdropURL(for: item, maxWidth: maxWidth)
    }

    func backdropURL(for item: BaseItemDto, maxWidth: Int = 1920) -> URL? {
        if let tag = item.backdropImageTags?.first {
            return imageURL(itemID: item.id, type: .backdrop, tag: tag, maxWidth: maxWidth)
        }
        if let tag = item.parentBackdropImageTags?.first {
            return imageURL(itemID: item.parentBackdropItemID, type: .backdrop, tag: tag, maxWidth: maxWidth)
        }
        return nil
    }

    func logoURL(for item: BaseItemDto, maxWidth: Int = 600) -> URL? {
        imageURL(itemID: item.id, type: .logo, tag: item.imageTags?[ImageType.logo.rawValue], maxWidth: maxWidth)
    }
}

extension BaseItemDto {
    var displayTitle: String {
        if type == .episode, let seriesName { return seriesName }
        return name ?? "Untitled"
    }

    /// "S2 · E5 · Episode name" for episodes, the year for everything else.
    var displaySubtitle: String? {
        if type == .episode {
            var parts: [String] = []
            if let season = parentIndexNumber { parts.append("S\(season)") }
            if let episode = indexNumber { parts.append("E\(episode)") }
            if let name { parts.append(name) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        return productionYear.map(String.init)
    }

    var runtimeText: String? {
        guard let ticks = runTimeTicks, ticks > 0 else { return nil }
        let minutes = ticks / 600_000_000
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// 0...1, or nil when not started.
    var progress: Double? {
        guard let percent = userData?.playedPercentage, percent > 0 else { return nil }
        return min(percent / 100, 1)
    }

    var isPlayed: Bool { userData?.isPlayed == true }

    var is3D: Bool { video3DFormat != nil }
}
