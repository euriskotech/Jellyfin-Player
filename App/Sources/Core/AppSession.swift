import Foundation
import JellyfinAPI
import Observation

/// A server we've reached, with a client that has no user signed in yet.
struct ConnectedServer {
    let server: SavedServer
    let client: JellyfinClient
    var id: String { server.id }
}

/// A signed-in user and the client carrying their access token.
struct UserSession {
    let server: SavedServer
    let account: SavedAccount
    let user: UserDto
    let client: JellyfinClient
}

enum SessionError: LocalizedError {
    case emptyAddress
    case unreachable(String)
    case notJellyfin
    case missingUser

    var errorDescription: String? {
        switch self {
        case .emptyAddress:
            "Enter your server's address."
        case let .unreachable(address):
            "Couldn't reach a Jellyfin server at \(address). Check the address and that the server is running."
        case .notJellyfin:
            "That address answered, but it doesn't look like a Jellyfin server."
        case .missingUser:
            "The server signed you in but didn't return your user details."
        }
    }
}

/// Owns the sign-in state for the whole app: which server, which user, and their client.
@MainActor
@Observable
final class AppSession {
    enum Phase {
        case launching
        case connect
        case chooseUser(ConnectedServer)
        case signedIn(UserSession)

        /// Used to animate between screens.
        var key: String {
            switch self {
            case .launching: "launching"
            case .connect: "connect"
            case let .chooseUser(server): "choose-\(server.id)"
            case let .signedIn(session): "signed-in-\(session.account.id)"
            }
        }
    }

    private(set) var phase: Phase = .launching
    /// Shown on the connect screen, e.g. when a saved server can't be reached at launch.
    var notice: String?

    private let store = AccountStore()

    var savedServers: [SavedServer] { store.servers }

    func savedAccounts(on serverID: String) -> [SavedAccount] {
        store.accounts(on: serverID)
    }

    // MARK: Launch

    /// Signs straight back in as the last user if their token still works.
    func start() async {
        guard case .launching = phase else { return }

        guard let account = store.lastAccount, let server = store.server(id: account.serverID) else {
            phase = .connect
            return
        }

        if await resume(account, on: server) { return }

        // Token didn't work. If the server is up, let them pick a user; otherwise explain.
        if let connected = try? await probe(server.url) {
            phase = .chooseUser(connected)
        } else {
            notice = "Couldn't reach \(server.name). Check it's running, or connect to a different address."
            phase = .connect
        }
    }

    // MARK: Server

    /// Finds a Jellyfin server from what the user typed and moves on to choosing a user.
    func connect(to address: String) async throws {
        let candidates = ServerAddress.candidates(for: address)
        guard !candidates.isEmpty else { throw SessionError.emptyAddress }

        var lastError: Error = SessionError.unreachable(address)
        for url in candidates {
            do {
                let connected = try await probe(url)
                store.save(connected.server)
                notice = nil
                phase = .chooseUser(connected)
                return
            } catch let error as SessionError {
                lastError = error
            } catch {
                continue
            }
        }
        throw lastError
    }

    /// Reconnects to a server saved earlier.
    func reconnect(to server: SavedServer) async throws {
        let connected: ConnectedServer
        do {
            connected = try await probe(server.url)
        } catch {
            throw SessionError.unreachable(server.url.absoluteString)
        }
        notice = nil
        phase = .chooseUser(connected)
    }

    func forget(_ server: SavedServer) {
        store.forget(serverID: server.id)
    }

    func changeServer() {
        store.setLastAccount(nil)
        phase = .connect
    }

    // MARK: Users

    func signIn(on server: ConnectedServer, username: String, password: String) async throws {
        let client = makeClient(url: server.server.url)
        let result = try await client.signIn(username: username, password: password)
        try finishSignIn(result, client: client, server: server.server)
    }

    /// Called once Quick Connect has been approved on another device.
    func signIn(on server: ConnectedServer, quickConnectClient client: JellyfinClient, secret: String) async throws {
        let result = try await client.signIn(quickConnectSecret: secret)
        try finishSignIn(result, client: client, server: server.server)
    }

    /// A client for running Quick Connect against this server.
    func quickConnectClient(for server: ConnectedServer) -> JellyfinClient {
        makeClient(url: server.server.url)
    }

    /// Switches to a user who signed in on this device before, without asking for their password again.
    /// Returns false if their saved sign-in has expired.
    @discardableResult
    func resume(_ account: SavedAccount, on server: SavedServer) async -> Bool {
        guard let token = store.token(for: account) else { return false }
        let client = makeClient(url: server.url, accessToken: token)
        do {
            let user = try await client.send(Paths.getCurrentUser).value
            var refreshed = account
            refreshed.userName = user.name ?? account.userName
            refreshed.imageTag = user.primaryImageTag
            store.save(refreshed, token: token)
            phase = .signedIn(UserSession(server: server, account: refreshed, user: user, client: client))
            return true
        } catch {
            return false
        }
    }

    /// Goes back to the user picker but keeps this user's saved sign-in for quick switching.
    func switchUser() async {
        guard case let .signedIn(session) = phase else { return }
        store.setLastAccount(nil)
        phase = .chooseUser(ConnectedServer(server: session.server, client: makeClient(url: session.server.url)))
    }

    /// Ends the session on the server and forgets this user's sign-in on this device.
    func signOut() async {
        guard case let .signedIn(session) = phase else { return }
        try? await session.client.signOut()
        store.forget(session.account)
        phase = .chooseUser(ConnectedServer(server: session.server, client: makeClient(url: session.server.url)))
    }

    /// Removes a saved user from the picker.
    func forget(_ account: SavedAccount) {
        store.forget(account)
    }

    // MARK: Helpers

    private func finishSignIn(_ result: AuthenticationResult, client: JellyfinClient, server: SavedServer) throws {
        guard let user = result.user, let userID = user.id, let token = client.accessToken else {
            throw SessionError.missingUser
        }
        let account = SavedAccount(
            serverID: server.id,
            userID: userID,
            userName: user.name ?? "User",
            imageTag: user.primaryImageTag
        )
        store.save(account, token: token)
        phase = .signedIn(UserSession(server: server, account: account, user: user, client: client))
    }

    /// Checks a URL is a Jellyfin server and returns its details.
    private func probe(_ url: URL) async throws -> ConnectedServer {
        let quick = URLSessionConfiguration.default
        quick.timeoutIntervalForRequest = 6
        let client = makeClient(url: url, sessionConfiguration: quick)

        let info = try await client.send(Paths.getPublicSystemInfo).value
        guard let id = info.id else { throw SessionError.notJellyfin }

        let server = SavedServer(id: id, name: info.serverName ?? url.host() ?? "Jellyfin", url: url)
        return ConnectedServer(server: server, client: makeClient(url: url))
    }

    private func makeClient(
        url: URL,
        accessToken: String? = nil,
        sessionConfiguration: URLSessionConfiguration = .default
    ) -> JellyfinClient {
        JellyfinClient(
            configuration: .init(
                url: url,
                accessToken: accessToken,
                client: DeviceIdentity.clientName,
                deviceName: DeviceIdentity.deviceName,
                deviceID: DeviceIdentity.deviceID,
                version: DeviceIdentity.appVersion
            ),
            sessionConfiguration: sessionConfiguration
        )
    }
}

extension JellyfinClient {
    /// URL for a user's profile picture, or nil if they haven't set one.
    func userImageURL(userID: String?, tag: String?) -> URL? {
        guard let userID, let tag else { return nil }
        return url(with: Paths.getUserImage(parameters: .init(userID: userID, tag: tag)))
    }
}
