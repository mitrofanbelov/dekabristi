import Foundation

public enum DraftKind: String, Codable, Sendable {
    case link
    case file
}

public struct OutboxEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: DraftKind
    public let title: String?
    public let sourceURLString: String?
    public let localFilePath: String?
    public let createdAt: Date
    public let lastAttemptAt: Date?
    public let attemptCount: Int

    public init(
        id: UUID = UUID(),
        kind: DraftKind,
        title: String?,
        sourceURLString: String?,
        localFilePath: String?,
        createdAt: Date = .now,
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.sourceURLString = sourceURLString
        self.localFilePath = localFilePath
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
    }

    public func recordingAttempt(at date: Date = .now) -> OutboxEntry {
        OutboxEntry(
            id: id,
            kind: kind,
            title: title,
            sourceURLString: sourceURLString,
            localFilePath: localFilePath,
            createdAt: createdAt,
            lastAttemptAt: date,
            attemptCount: attemptCount + 1
        )
    }
}
