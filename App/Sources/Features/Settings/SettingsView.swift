import JellyfinAPI
import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(LibraryModel.self) private var library

    var body: some View {
        @Bindable var settings = library.settings
        @Bindable var playback = library.playback

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
                Picker("Audio language", selection: $playback.audioLanguage) {
                    languageOptions(including: playback.audioLanguage)
                }
                Picker("Subtitles", selection: $playback.subtitleMode) {
                    ForEach(SubtitleMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if playback.subtitleMode != .off {
                    Picker("Subtitle language", selection: $playback.subtitleLanguage) {
                        languageOptions(including: playback.subtitleLanguage)
                    }
                }
            } header: {
                Text("Playback")
            } footer: {
                Text("\(playback.subtitleMode.explanation) These defaults are applied every time something plays, and you can still change tracks before pressing Play.")
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

    @ViewBuilder
    private func languageOptions(including current: String) -> some View {
        let codes = Languages.common.contains(current) ? Languages.common : [current] + Languages.common
        ForEach(codes, id: \.self) { code in
            Text(Languages.displayName(code)).tag(code)
        }
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
