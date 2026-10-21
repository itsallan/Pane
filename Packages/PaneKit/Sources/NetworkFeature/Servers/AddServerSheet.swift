import Domain
import SwiftUI

struct AddServerSheet: View {
    let onSave: (NetworkServer, NetworkCredential?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ServerDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $draft.kind) {
                        Text("SMB").tag(NetworkServer.Kind.smb)
                        Text("SFTP").tag(NetworkServer.Kind.sftp)
                    }
                    // The LabeledContent shows the title; a field's own label would repeat it on the Mac.
                    LabeledContent("Host") {
                        TextField("Host", text: $draft.host, prompt: Text(verbatim: "nas.local"))
                            .labelsHidden()
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    LabeledContent("Port") {
                        TextField("Port", value: $draft.port, format: .number.grouping(.never), prompt: Text(verbatim: draft.kind == .smb ? "445" : "22"))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                    LabeledContent("Name") {
                        TextField("Name", text: $draft.name, prompt: Text("Optional"))
                            .labelsHidden()
                    }
                }
                // No login content types, for the same reason as SignInSheet.
                Section {
                    LabeledContent("User Name") {
                        TextField("User Name", text: $draft.user, prompt: Text(draft.kind == .smb ? "Optional for guests" : "Required"))
                            .labelsHidden()
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    LabeledContent("Password") {
                        SecureField("Password", text: $draft.password)
                            .labelsHidden()
                    }
                } footer: {
                    Text("Pane keeps the password in your keychain.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .disabled(!draft.canSave)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        onSave(draft.makeServer(), draft.credential)
        dismiss()
    }
}
