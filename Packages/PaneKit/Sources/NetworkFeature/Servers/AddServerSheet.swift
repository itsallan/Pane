import Domain
import SwiftUI

struct AddServerSheet: View {
    let onSave: (NetworkServer, NetworkCredential?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind = NetworkServer.Kind.smb
    @State private var host = ""
    @State private var port: Int?
    @State private var name = ""
    @State private var user = ""
    @State private var password = ""

    // People paste "smb://nas.local/Movies"; keep just the host.
    private var trimmedHost: String {
        let text = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutScheme = text.range(of: "://").map { String(text[$0.upperBound...]) } ?? text
        return String(withoutScheme.prefix { $0 != "/" })
    }

    private var canSave: Bool {
        !trimmedHost.isEmpty && !trimmedHost.contains(" ") && (kind != .sftp || !user.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("SMB").tag(NetworkServer.Kind.smb)
                        Text("SFTP").tag(NetworkServer.Kind.sftp)
                    }
                    TextField("Host", text: $host, prompt: Text("nas.local or 192.168.1.10"))
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Port", value: $port, format: .number.grouping(.never), prompt: Text(kind == .smb ? "445" : "22"))
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    TextField("Name", text: $name, prompt: Text("Optional"))
                }
                // No login content types, for the same reason as SignInSheet.
                Section {
                    TextField("User Name", text: $user, prompt: Text(kind == .smb ? "Optional for guest access" : "Required"))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    SecureField("Password", text: $password)
                } footer: {
                    Text("Pane keeps the password in your keychain.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .disabled(!canSave)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
    }

    private func save() {
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLogin = !user.isEmpty
        let server = NetworkServer(
            kind: kind,
            host: trimmedHost,
            port: port,
            displayName: displayName.isEmpty ? trimmedHost : displayName,
            requiresCredentials: hasLogin
        )
        onSave(server, hasLogin ? NetworkCredential(user: user, password: password) : nil)
        dismiss()
    }
}
