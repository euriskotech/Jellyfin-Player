import Foundation
import Observation

/// Per-user library preferences kept on this device.
@MainActor
@Observable
final class LibrarySettings {
    private let defaults = UserDefaults.standard
    private let accountID: String

    /// Libraries hidden from this app, on top of anything hidden in Jellyfin's own settings.
    var hiddenLibraryIDs: Set<String> {
        didSet { defaults.set(Array(hiddenLibraryIDs), forKey: key("hidden-libraries")) }
    }

    /// Leave 3D versions out of collections, even if they aren't in a hidden library.
    var hide3DInCollections: Bool {
        didSet { defaults.set(hide3DInCollections, forKey: key("hide-3d-in-collections")) }
    }

    init(accountID: String) {
        self.accountID = accountID
        let hidden = defaults.stringArray(forKey: "\(accountID)|hidden-libraries") ?? []
        hiddenLibraryIDs = Set(hidden)
        hide3DInCollections = defaults.object(forKey: "\(accountID)|hide-3d-in-collections") as? Bool ?? true
    }

    private func key(_ name: String) -> String { "\(accountID)|\(name)" }
}
