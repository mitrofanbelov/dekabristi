import Foundation

public enum RemoteItemKind: String, Codable, Sendable {
    case link
    case file
}

public enum RemoteItemStatus: String, Codable, Sendable {
    case queued
    case uploading
    case available
    case failed
}

public struct RemoteAttachment: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let originalFilename: String
    public let contentType: String?
    public let sizeBytes: Int
    public let sha256: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case originalFilename = "original_filename"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case sha256
        case createdAt = "created_at"
    }
}

public struct RemoteItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: RemoteItemKind
    public let status: RemoteItemStatus
    public let title: String?
    public let sourceURL: String?
    public let comment: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let deletedAt: Date?
    public let attachments: [RemoteAttachment]

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case status
        case title
        case sourceURL = "source_url"
        case comment
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case attachments
    }
}

public struct ItemListPage: Codable, Sendable {
    public let items: [RemoteItem]
    public let nextCursor: Date?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

public struct SyncPage: Codable, Sendable {
    public let items: [RemoteItem]
    public let nextCursor: Date?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

public struct UserProfile: Codable, Equatable, Sendable {
    public let id: String
    public let email: String
}

public struct AuthSession: Codable, Equatable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let user: UserProfile

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case user
    }

    public init(accessToken: String, tokenType: String, user: UserProfile) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.user = user
    }
}

public struct HealthStatus: Codable, Equatable, Sendable {
    public let status: String
    public let app: String
    public let syncPollIntervalSeconds: Int
    public let connectivityProbeIntervalSeconds: Int

    enum CodingKeys: String, CodingKey {
        case status
        case app
        case syncPollIntervalSeconds = "sync_poll_interval_seconds"
        case connectivityProbeIntervalSeconds = "connectivity_probe_interval_seconds"
    }
}

public struct RegisterPayload: Encodable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct LoginPayload: Encodable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct CreateLinkPayload: Encodable, Sendable {
    public let url: String
    public let title: String?

    public init(url: String, title: String?) {
        self.url = url
        self.title = title
    }
}

public struct UpdateItemPayload: Encodable, Sendable {
    public let comment: String?

    public init(comment: String?) {
        self.comment = comment
    }
}
