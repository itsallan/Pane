import Foundation

public struct NetworkServer: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case smb
        case sftp
        case upnp
    }

    public let id: UUID
    public var kind: Kind
    public var host: String
    public var port: Int?
    public var displayName: String
    public var requiresCredentials: Bool

    public init(id: UUID = UUID(), kind: Kind, host: String, port: Int? = nil, displayName: String, requiresCredentials: Bool) {
        self.id = id
        self.kind = kind
        self.host = host
        self.port = port
        self.displayName = displayName
        self.requiresCredentials = requiresCredentials
    }
}

public struct NetworkEntry: Sendable, Hashable, Identifiable {
    public var name: String
    public var path: String
    public var isDirectory: Bool
    public var size: Int64?

    public init(name: String, path: String, isDirectory: Bool, size: Int64? = nil) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
    }

    /// A path is unique within a listing; for UPnP it's the item's full URL.
    public var id: String { path }
}

public struct NetworkCredential: Sendable, Hashable {
    public var user: String
    public var password: String

    public init(user: String, password: String) {
        self.user = user
        self.password = password
    }
}

extension NetworkCredential: CustomStringConvertible, CustomDebugStringConvertible {
    // Interpolating a credential into a log line must never leak the password.
    public var description: String { "NetworkCredential(user: \(user), password: <redacted>)" }
    public var debugDescription: String { description }
}
