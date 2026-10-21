import Domain
import SwiftUI

public struct OpenURLScreen: View {
    @Bindable private var model: OpenURLModel
    private let onOpen: (URL) -> Void

    @FocusState private var isAddressFocused: Bool
    @State private var isConfirmingClear = false

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
                Section {
                    ForEach(model.recents) { stream in
                        Button {
                            reopen(stream)
                        } label: {
                            RecentStreamRow(stream: stream)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove from History", systemImage: "trash", role: .destructive) {
                                remove(stream)
                            }
                        }
                    }
                    .onDelete(perform: remove)
                } header: {
                    HStack {
                        Text("Recent")
                        Spacer()
                        Button("Clear", role: .destructive) {
                            isConfirmingClear = true
                        }
                        .textCase(nil)
                        .confirmationDialog("Clear stream history?", isPresented: $isConfirmingClear) {
                            Button("Clear History", role: .destructive, action: clearHistory)
                        } message: {
                            Text("Streams you've already played stay in your library.")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Open URL")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Open", action: open)
                    .disabled(model.text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .task {
            await model.load()
        }
        .onAppear {
            isAddressFocused = true
        }
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

    private func remove(_ stream: RecentStream) {
        Task { await model.remove(stream) }
    }

    private func remove(at offsets: IndexSet) {
        let streams = offsets.map { model.recents[$0] }
        Task {
            for stream in streams {
                await model.remove(stream)
            }
        }
    }

    private func clearHistory() {
        Task { await model.clearHistory() }
    }
}
