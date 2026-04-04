import Foundation

public actor OutboxStore {
    private var entries: [OutboxEntry] = []

    public init() {}

    public func enqueue(_ entry: OutboxEntry) {
        entries.append(entry)
        entries.sort { $0.createdAt < $1.createdAt }
    }

    public func snapshot() -> [OutboxEntry] {
        entries
    }

    public func recordAttempt(for id: UUID, at date: Date = .now) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }
        entries[index] = entries[index].recordingAttempt(at: date)
    }

    public func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }
}
