import Domain
import Testing
@testable import NetworkFeature

struct ServerDraftTests {
    @Test func keepsOnlyTheHostFromAPastedAddress() {
        var draft = ServerDraft()
        draft.host = " smb://nas.local/Movies/2024 "
        #expect(draft.trimmedHost == "nas.local")
        #expect(draft.makeServer().displayName == "nas.local")
    }

    @Test func sftpNeedsAUserButSMBCanBeAGuest() {
        var draft = ServerDraft(host: "nas.local")
        #expect(draft.canSave)
        #expect(draft.credential == nil)
        #expect(!draft.makeServer().requiresCredentials)

        draft.kind = .sftp
        #expect(!draft.canSave)
        draft.user = "me"
        #expect(draft.canSave)
        #expect(draft.makeServer().requiresCredentials)
    }

    @Test func refusesAHostWithSpaces() {
        #expect(!ServerDraft(host: "my nas").canSave)
    }

    @Test func usesTheNameWhenGiven() {
        let server = ServerDraft(host: "192.168.1.10", port: 4450, name: " Attic ").makeServer()
        #expect(server.displayName == "Attic")
        #expect(server.port == 4450)
    }
}
