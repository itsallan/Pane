import Domain
import SwiftUI

public struct OpenURLScreen: View {
    @Bindable private var model: OpenURLModel
    private let onOpen: (URL) -> Void

    @FocusState private var isAddressFocused: Bool

    public init(model: OpenURLModel, onOpen: @escaping (URL) -> Void) {
        self.model = model
        self.onOpen = onOpen
    }

    public var body: some View {
        Form {
            Section {
                TextField("Stream Address", text: $model.text, prompt: Text(verbatim: "https://example.com/live.m3u8"))
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .submitLabel(.go)
                    .focused($isAddressFocused)
                    .onSubmit(open)
            } footer: {
                if let error = model.error {
                    Label(error.message, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                } else {
                    Text("HTTP, HTTPS, HLS, RTSP, RTMP, RTP, UDP and MMS streams.")
                }
            }
            if !model.recents.isEmpty {
                RecentStreamsSection(model: model, onReopen: reopen)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Open URL")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Open", action: open)
                    .disabled(!model.canSubmit)
            }
        }
        .task {
            await model.load()
        }
        .onAppear(perform: focusAddress)
    }

    private func focusAddress() {
        isAddressFocused = true
    }

    private func open() {
        Task {
            guard let url = await model.submit() else { return }
            onOpen(url)
        }
    }

    private func reopen(_ stream: RecentStream) {
        Task {
            await model.reopen(stream.url)
            onOpen(stream.url)
        }
    }
}
