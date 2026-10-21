import Domain
import SwiftUI

struct SignInSheet: View {
    let request: SignInRequest
    let onSignIn: (NetworkCredential) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var user: String
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case user
        case password
    }

    init(request: SignInRequest, onSignIn: @escaping (NetworkCredential) -> Void) {
        self.request = request
        self.onSignIn = onSignIn
        _user = State(initialValue: request.user)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("User Name", text: $user)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .focused($focusedField, equals: .user)
                        .onSubmit { focusedField = .password }
                    SecureField("Password", text: $password)
                        .textContentType(.password)
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
                    Button("Sign In", action: signIn)
                        .disabled(user.isEmpty)
                }
            }
            .onAppear {
                focusedField = request.user.isEmpty ? .user : .password
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 260)
        #endif
    }

    private func signIn() {
        guard !user.isEmpty else { return }
        onSignIn(NetworkCredential(user: user, password: password))
        dismiss()
    }
}
