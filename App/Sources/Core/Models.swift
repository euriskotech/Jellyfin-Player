import Foundation

/// A Jellyfin server the app has connected to.
struct SavedServer: Codable, Hashable, Identifiable {
    /// The server's own ID, so the same server reached by a different address is still recognised.
    var id: String
    var name: String
    var url: URL
}

/// A user who has signed in on this device. The access token lives in the Keychain, not here.
struct SavedAccount: Codable, Hashable, Identifiable {
    var serverID: String
    var userID: String
    var userName: String
    var imageTag: String?

    var id: String { "\(serverID)|\(userID)" }
    var tokenKey: String { "token|\(id)" }
}
