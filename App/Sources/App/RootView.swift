import SwiftUI

/// Chooses which screen to show based on where the user is in the sign-in flow.
struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            switch session.phase {
            case .launching:
                ProgressView()
            case .connect:
                ServerConnectView()
            case let .chooseUser(server):
                UserPickerView(server: server)
                    .id(server.id)
            case let .signedIn(userSession):
                HomeView(userSession: userSession)
                    .id(userSession.account.id)
            }
        }
        .animation(.default, value: session.phase.key)
    }
}
