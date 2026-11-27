import JellyfinAPI
import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(LibraryModel.self) private var library

    var body: some View {
        @Bindable var settings = library.settings

        Form {
            Section {
                HStack(spacing: 16) {
                    UserAvatar(
                        name: library.session.account.userName,
                        imageURL: library.client.userImageURL(
                            userID: library.session.account.userID,
                            tag: library.session.account.imageTag
                        ),
                        size: 56
                    )
                    VStack(alignment: .leading) {
                        Text(library.session.account.userName).font(.headline)
                        Text(library.session.server.name).foregroundStyle(.secondary)
                    }
                }
                Button("Switch User") { Task { await session.switchUser() } }
                Button("Sign Out", role: .destructive) { Task { await session.signOut() } }
            }

            Section {
                ForEach(library.libraries) { item in
                    Toggle(item.name ?? "Library", isOn: visibility(of: item))
                }
            } header: {
                Text("Libraries")
            } footer: {
                Text("Turned-off libraries are hidden from this device, and their films never appear inside collections. Libraries excluded from \u{201C}My Media\u{201D} in Jellyfin are also kept out of collections.")
            }

            Section {
                Toggle("Hide 3D versions in collections and search", isOn: $settings.hide3DInCollections)
            } footer: {
                Text("Uses Jellyfin's 3D format tag, so 3D films stay out of collections even if they aren't in a separate library.")
            }
        }
        .navigationTitle("Settings")
        .task { if library.libraries.isEmpty { try? await library.loadLibraries() } }
    }

    private func visibility(of item: BaseItemDto) -> Binding<Bool> {
        Binding {
            guard let id = item.id else { return true }
            return !library.settings.hiddenLibraryIDs.contains(id)
        } set: { isVisible in
            guard let id = item.id else { return }
            if isVisible {
                library.settings.hiddenLibraryIDs.remove(id)
            } else {
                library.settings.hiddenLibraryIDs.insert(id)
            }
        }
    }
}
