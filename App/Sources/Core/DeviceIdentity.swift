import Foundation
import UIKit

/// Identifies this install to the Jellyfin server so it shows up as one device in the dashboard.
enum DeviceIdentity {
    static let clientName = "Jellyfin Player"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    @MainActor
    static var deviceName: String {
        UIDevice.current.name
    }

    /// Stable per-install ID, kept in the Keychain so it survives app updates.
    static var deviceID: String {
        let key = "device-id"
        if let existing = Keychain.string(for: key) {
            return existing
        }
        let new = UUID().uuidString
        Keychain.set(new, for: key)
        return new
    }
}
