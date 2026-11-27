import SwiftUI

/// Signed-in shell: Home, Search and Settings tabs.
struct MainView: View {
    @State private var library: LibraryModel

    init(userSession: UserSession) {
        _library = State(initialValue: LibraryModel(session: userSession))
    }

    var body: some View {
        TabView {
            NavigationStack {
                HomeView().itemNavigation()
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                SearchView().itemNavigation()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(library)
    }
}
