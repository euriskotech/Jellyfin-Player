import Foundation

/// Remembers servers and signed-in users between launches.
/// Server and account details go in UserDefaults; tokens go in the Keychain.
struct AccountStore {
    private let defaults: UserDefaults
    private let serversKey = "saved-servers"
    private let accountsKey = "saved-accounts"
    private let lastAccountKey = "last-account-id"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Servers

    var servers: [SavedServer] {
        decode([SavedServer].self, key: serversKey) ?? []
    }

    func save(_ server: SavedServer) {
        var all = servers.filter { $0.id != server.id }
        all.insert(server, at: 0)
        encode(all, key: serversKey)
    }

    func server(id: String) -> SavedServer? {
        servers.first { $0.id == id }
    }

    func forget(serverID: String) {
        for account in accounts(on: serverID) {
            forget(account)
        }
        encode(servers.filter { $0.id != serverID }, key: serversKey)
    }

    // MARK: Accounts

    var accounts: [SavedAccount] {
        decode([SavedAccount].self, key: accountsKey) ?? []
    }

    func accounts(on serverID: String) -> [SavedAccount] {
        accounts.filter { $0.serverID == serverID && token(for: $0) != nil }
    }

    func save(_ account: SavedAccount, token: String) {
        Keychain.set(token, for: account.tokenKey)
        var all = accounts.filter { $0.id != account.id }
        all.insert(account, at: 0)
        encode(all, key: accountsKey)
        defaults.set(account.id, forKey: lastAccountKey)
    }

    func token(for account: SavedAccount) -> String? {
        Keychain.string(for: account.tokenKey)
    }

    func forget(_ account: SavedAccount) {
        Keychain.remove(account.tokenKey)
        encode(accounts.filter { $0.id != account.id }, key: accountsKey)
        if lastAccountID == account.id {
            defaults.removeObject(forKey: lastAccountKey)
        }
    }

    var lastAccountID: String? {
        defaults.string(forKey: lastAccountKey)
    }

    func setLastAccount(_ account: SavedAccount?) {
        defaults.set(account?.id, forKey: lastAccountKey)
    }

    var lastAccount: SavedAccount? {
        guard let id = lastAccountID else { return nil }
        return accounts.first { $0.id == id }
    }

    // MARK: Helpers

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode(_ value: some Encodable, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
