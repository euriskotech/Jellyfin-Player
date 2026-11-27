import SwiftUI

/// First screen: type a server address, or pick one used before.
struct ServerConnectView: View {
    @Environment(AppSession.self) private var session
    @State private var address = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let notice = session.notice {
                    Section {
                        Label(notice, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    TextField("e.g. 192.168.1.20:8096 or jellyfin.example.com", text: $address)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(connect)

                    Button(action: connect) {
                        HStack {
                            Text("Connect")
                            if isConnecting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                } header: {
                    Text("Server address")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                if !session.savedServers.isEmpty {
                    Section("Your servers") {
                        ForEach(session.savedServers) { server in
                            Button {
                                reconnect(server)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(server.name)
                                    Text(server.url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contextMenu {
                                Button("Forget Server", role: .destructive) {
                                    session.forget(server)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Connect to Jellyfin")
        }
    }

    private func connect() {
        run { try await session.connect(to: address) }
    }

    private func reconnect(_ server: SavedServer) {
        run { try await session.reconnect(to: server) }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        guard !isConnecting else { return }
        isConnecting = true
        errorMessage = nil
        Task {
            defer { isConnecting = false }
            do {
                try await work()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
