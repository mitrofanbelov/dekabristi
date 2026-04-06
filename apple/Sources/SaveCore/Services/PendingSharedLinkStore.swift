import Foundation

public struct PendingSharedLink: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: String
    public let title: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), url: String, title: String?, createdAt: Date = .now) {
        self.id = id
        self.url = url
        self.title = title
        self.createdAt = createdAt
    }
}

public actor PendingSharedLinkStore {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = SharedAppConfiguration.sharedUserDefaults()) {
        self.userDefaults = userDefaults
    }

    public func enqueue(_ draft: PendingSharedLink) {
        var drafts = loadDrafts()
        drafts.append(draft)
        drafts.sort { $0.createdAt < $1.createdAt }
        saveDrafts(drafts)
    }

    public func snapshot() -> [PendingSharedLink] {
        loadDrafts()
    }

    public func drain() -> [PendingSharedLink] {
        let drafts = loadDrafts()
        userDefaults.removeObject(forKey: SharedAppConfiguration.pendingSharedLinksKey)
        return drafts
    }

    public func remove(_ id: UUID) {
        var drafts = loadDrafts()
        drafts.removeAll { $0.id == id }
        if drafts.isEmpty {
            userDefaults.removeObject(forKey: SharedAppConfiguration.pendingSharedLinksKey)
        } else {
            saveDrafts(drafts)
        }
    }

    public func clear() {
        userDefaults.removeObject(forKey: SharedAppConfiguration.pendingSharedLinksKey)
    }

    private func loadDrafts() -> [PendingSharedLink] {
        guard
            let savedData = userDefaults.data(forKey: SharedAppConfiguration.pendingSharedLinksKey),
            let drafts = try? decoder.decode([PendingSharedLink].self, from: savedData)
        else {
            return []
        }

        return drafts
    }

    private func saveDrafts(_ drafts: [PendingSharedLink]) {
        guard let encodedDrafts = try? encoder.encode(drafts) else {
            return
        }

        userDefaults.set(encodedDrafts, forKey: SharedAppConfiguration.pendingSharedLinksKey)
    }
}
