import SwiftUI

struct PasswordSignInView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let server: ConnectedServer

    @State private var username: String
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field { case username, password }

    init(server: ConnectedServer, initialUsername: String) {
        self.server = server
        _username = State(initialValue: initialUsername)
    }

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit(signIn)
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                Button(action: signIn) {
                    HStack {
                        Text("Sign In")
                        if isSigningIn {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(username.isEmpty || isSigningIn)
            }
        }
        .navigationTitle("Sign in to \(server.server.name)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear { focusedField = username.isEmpty ? .username : .password }
    }

    private func signIn() {
        guard !username.isEmpty, !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        Task {
            defer { isSigningIn = false }
            do {
                try await session.signIn(on: server, username: username, password: password)
                dismiss()
            } catch {
                errorMessage = "Sign-in failed. Check your username and password."
            }
        }
    }
}
