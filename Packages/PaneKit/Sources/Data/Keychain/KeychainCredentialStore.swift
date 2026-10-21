import Domain
import Foundation
import Security

public struct KeychainError: Error, Sendable, Hashable {
    public let status: OSStatus
}

/// Internet passwords keyed by server ID rather than host, so two shares on one host keep separate logins
/// and renaming a host doesn't orphan its password.
public struct KeychainCredentialStore: CredentialStore {
    private let label: String
    private let accessGroup: String?

    /// Tests pass their own label so they never touch the app's items.
    public init(label: String = "Pane network share", accessGroup: String? = nil) {
        self.label = label
        self.accessGroup = accessGroup
    }

    public func credential(for server: NetworkServer.ID) async throws -> NetworkCredential? {
        var query = baseQuery(for: server)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnAttributes] = true
        query[kSecReturnData] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let attributes = result as? [CFString: Any],
              let user = attributes[kSecAttrAccount] as? String,
              let data = attributes[kSecValueData] as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return NetworkCredential(user: user, password: password)
    }

    public func save(_ credential: NetworkCredential, for server: NetworkServer.ID) async throws {
        try await deleteCredential(for: server)
        var item = baseQuery(for: server)
        item[kSecAttrAccount] = credential.user
        item[kSecValueData] = Data(credential.password.utf8)
        // Shares are opened in the background to resume playback, but never from a locked device's backup.
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func deleteCredential(for server: NetworkServer.ID) async throws {
        let status = SecItemDelete(baseQuery(for: server) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func baseQuery(for server: NetworkServer.ID) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.uuidString,
            kSecAttrLabel: label,
            // The file-based macOS keychain would prompt and ignores access groups; use the iOS-style one everywhere.
            kSecUseDataProtectionKeychain: true,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        return query
    }
}
