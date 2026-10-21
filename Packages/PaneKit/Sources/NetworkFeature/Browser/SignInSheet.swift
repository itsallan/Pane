import Domain
import SwiftUI

struct SignInSheet: View {
    let request: SignInRequest
    let isSigningIn: Bool
    let onSignIn: (NetworkCredential) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var user: String
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case user
        case password
    }

    init(request: SignInRequest, isSigningIn: Bool, onSignIn: @escaping (NetworkCredential) -> Void) {
        self.request = request
        self.isSigningIn = isSigningIn
        self.onSignIn = onSignIn
        _user = State(initialValue: request.user)
    }

    var body: some View {
        NavigationStack {
            Form {
                // No username or password content types: they make iOS offer to save the login to Passwords
                // with no website to tie it to, on top of the keychain item Pane already keeps.
                Section {
                    TextField("User Name", text: $user)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .focused($focusedField, equals: .user)
                        .onSubmit { focusedField = .password }
                    SecureField("Password", text: $password)
                        .focused($focusedField, equals: .password)
                        .onSubmit(signIn)
                } header: {
                    if request.isRetry {
                        Label("The user name or password is incorrect.", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .textCase(nil)
                    }
                } footer: {
                    Text("Pane keeps the password in your keychain and uses it whenever it opens this server.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Sign In to \(request.serverName)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Button("Sign In", action: signIn)
                            .disabled(user.isEmpty)
                    }
                }
            }
            .onAppear {
                focusedField = request.user.isEmpty ? .user : .password
            }
            .onChange(of: isSigningIn) { _, isSigningIn in
                // Still open after an attempt means it was rejected; start the password over.
                guard !isSigningIn else { return }
                password = ""
                focusedField = .password
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isSigningIn)
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 260)
        #endif
    }

    private func signIn() {
        guard !user.isEmpty, !isSigningIn else { return }
        onSignIn(NetworkCredential(user: user, password: password))
    }
}
