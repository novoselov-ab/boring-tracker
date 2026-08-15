import Foundation

/// One row in the complete history: every surviving member of a batch, or one
/// ordinary entry when no batch connects it to anything else.
///
/// A batch whose members have been edited across midnight still stays one row.
/// Its newest member decides where the row sorts and which day contains it;
/// splitting one event across two sections would make editing and deleting it
/// once impossible, which is the reason the batch exists.
struct HistoryItem: Identifiable, Hashable, Sendable {
    enum ID: Hashable, Sendable {
        case batch(UUID)
        case entry(UUID)
    }

    let id: ID
    let entries: [Entry]
    let date: Date

    var sortID: String {
        switch id {
        case .batch(let id): "batch:\(id.uuidString)"
        case .entry(let id): "entry:\(id.uuidString)"
        }
    }

    init?(entries: [Entry]) {
        guard let newest = entries.max(by: { ($0.date, $0.id) < ($1.date, $1.id) }) else {
            return nil
        }
        self.entries = entries.sorted { ($0.date, $0.id) > ($1.date, $1.id) }
        self.date = newest.date
        self.id = newest.batchID.map(ID.batch) ?? .entry(newest.id)
    }
}
