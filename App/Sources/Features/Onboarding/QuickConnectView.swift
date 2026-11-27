import JellyfinAPI
import SwiftUI

/// Shows a code to approve from another signed-in device. Handy on Apple TV, where typing passwords is a chore.
struct QuickConnectView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let server: ConnectedServer

    @State private var code: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            if let code {
                Text("Enter this code in Jellyfin on a device where you're already signed in, under your profile's Quick Connect settings.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .kerning(8)
                ProgressView("Waiting for approval…")
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
            }
        }
        .padding(40)
        .navigationTitle("Quick Connect")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task { await run() }
    }

    private func run() async {
        let client = session.quickConnectClient(for: server)
        do {
            for try await event in client.quickConnect.connect() {
                switch event {
                case .polling(let code):
                    self.code = code
                case .authenticated(let secret):
                    try await session.signIn(on: server, quickConnectClient: client, secret: secret)
                    dismiss()
                }
            }
        } catch {
            code = nil
            errorMessage = "Quick Connect isn't available. Make sure it's turned on in your server's dashboard, or sign in with a username instead."
        }
    }
}
