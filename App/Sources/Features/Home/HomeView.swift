import SwiftUI

/// Placeholder home screen. Library browsing (Continue Watching, Next Up, Movies, TV, Collections) arrives in step 2.
struct HomeView: View {
    @Environment(AppSession.self) private var session
    let userSession: UserSession

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                UserAvatar(
                    name: userSession.account.userName,
                    imageURL: userSession.client.userImageURL(
                        userID: userSession.account.userID,
                        tag: userSession.account.imageTag
                    ),
                    size: 120
                )
                Text("Signed in as \(userSession.account.userName)")
                    .font(.title2.bold())
                Text("Connected to \(userSession.server.name)")
                    .foregroundStyle(.secondary)
                Text("Your library will appear here next.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 24) {
                    Button("Switch User") {
                        Task { await session.switchUser() }
                    }
                    Button("Sign Out", role: .destructive) {
                        Task { await session.signOut() }
                    }
                }
                .padding(.top)
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}
