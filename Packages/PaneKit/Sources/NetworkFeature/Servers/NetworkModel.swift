import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class NetworkModel {
    public private(set) var savedServers: [NetworkServer] = []
    /// Found on the local network and not saved yet.
    public private(set) var nearbyServers: [NetworkServer] = []
    public private(set) var hasLoaded = false
    public var failure: NetworkFailure?

    private let browser: any NetworkBrowser
    private let servers: any NetworkServerRepository
    private let credentials: any CredentialStore
    private var discovered: [NetworkServer] = []

    public init(browser: any NetworkBrowser, servers: any NetworkServerRepository, credentials: any CredentialStore) {
        self.browser = browser
        self.servers = servers
        self.credentials = credentials
    }

    public var isShowingFailure: Bool {
        get { failure != nil }
        set {
            if !newValue {
                failure = nil
            }
        }
    }

    public func load() async {
        savedServers = (try? await servers.servers()) ?? []
        hasLoaded = true
        refreshNearby()
    }

    /// Runs until the calling task is cancelled, which stops discovery.
    public func discover() async {
        for await found in browser.servers() {
            discovered = found
            refreshNearby()
        }
    }

    public func add(_ server: NetworkServer, credential: NetworkCredential?) async {
        do {
            if let credential {
                try await credentials.save(credential, for: server.id)
            }
            try await servers.save(server)
        } catch {
            failure = .saveFailed
        }
        await load()
    }

    /// Forgets the server and its password; a server that's still announcing itself shows up again under Nearby.
    public func remove(_ server: NetworkServer) async {
        do {
            try await credentials.deleteCredential(for: server.id)
            try await servers.deleteServer(withID: server.id)
        } catch {
            failure = .removeFailed
        }
        await load()
    }

    private func refreshNearby() {
        let saved = Set(savedServers.map(\.id))
        nearbyServers = discovered.filter { !saved.contains($0.id) }
    }
}
