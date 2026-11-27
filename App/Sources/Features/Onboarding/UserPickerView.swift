import JellyfinAPI
import SwiftUI

/// "Who's watching?" screen: saved users, the server's public users, or sign in another way.
struct UserPickerView: View {
    @Environment(AppSession.self) private var session
    let server: ConnectedServer

    @State private var publicUsers: [UserDto] = []
    @State private var savedAccounts: [SavedAccount] = []
    @State private var route: Route?
    @State private var busyID: String?
    @State private var errorMessage: String?

    enum Route: Hashable, Identifiable {
        case password(username: String)
        case quickConnect
        var id: Self { self }
    }

    #if os(tvOS)
    private let avatarSize: CGFloat = 160
    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 48)]
    #else
    private let avatarSize: CGFloat = 84
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 20)]
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(server.server.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }

                    LazyVGrid(columns: columns, spacing: 32) {
                        ForEach(savedAccounts) { account in
                            tile(
                                name: account.userName,
                                imageURL: server.client.userImageURL(userID: account.userID, tag: account.imageTag),
                                isBusy: busyID == account.id
                            ) {
                                Task { await resume(account) }
                            }
                            .contextMenu {
                                Button("Remove from This Device", role: .destructive) {
                                    session.forget(account)
                                    reload()
                                }
                            }
                        }

                        ForEach(unsavedPublicUsers, id: \.id) { user in
                            tile(
                                name: user.name ?? "User",
                                imageURL: server.client.userImageURL(userID: user.id, tag: user.primaryImageTag),
                                isBusy: busyID == user.id
                            ) {
                                Task { await choose(user) }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Button("Sign in with a username", systemImage: "person.badge.key") {
                            route = .password(username: "")
                        }
                        Button("Use Quick Connect", systemImage: "qrcode") {
                            route = .quickConnect
                        }
                        Button("Change server", systemImage: "server.rack") {
                            session.changeServer()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Who's watching?")
            .sheet(item: $route) { route in
                NavigationStack {
                    switch route {
                    case let .password(username):
                        PasswordSignInView(server: server, initialUsername: username)
                    case .quickConnect:
                        QuickConnectView(server: server)
                    }
                }
            }
            .task { await load() }
        }
    }

    /// Public users who aren't already shown as a saved account.
    private var unsavedPublicUsers: [UserDto] {
        let saved = Set(savedAccounts.map(\.userID))
        return publicUsers.filter { user in
            guard let id = user.id else { return false }
            return !saved.contains(id)
        }
    }

    @ViewBuilder
    private func tile(name: String, imageURL: URL?, isBusy: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    UserAvatar(name: name, imageURL: imageURL, size: avatarSize)
                    if isBusy { ProgressView() }
                }
                Text(name).lineLimit(1)
            }
            .padding(8)
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .disabled(busyID != nil)
    }

    private func load() async {
        reload()
        publicUsers = (try? await server.client.send(Paths.getPublicUsers).value) ?? []
    }

    private func reload() {
        savedAccounts = session.savedAccounts(on: server.id)
    }

    private func resume(_ account: SavedAccount) async {
        busyID = account.id
        defer { busyID = nil }
        errorMessage = nil
        let resumed = await session.resume(account, on: server.server)
        if !resumed {
            session.forget(account)
            reload()
            route = .password(username: account.userName)
        }
    }

    /// Users without a password go straight in; everyone else is asked for one.
    private func choose(_ user: UserDto) async {
        let name = user.name ?? ""
        guard user.hasPassword == false else {
            route = .password(username: name)
            return
        }
        busyID = user.id
        defer { busyID = nil }
        do {
            try await session.signIn(on: server, username: name, password: "")
        } catch {
            route = .password(username: name)
        }
    }
}
