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

    /// Every name its members actually carry, newest member first, without the
    /// blanks. Members can disagree because tracker detail edits one entry at a
    /// time, so this is the one place that decides what a batch is called — the
    /// row and the editor both read it. When they each had their own rule, the
    /// editor opened blank on a batch the row showed a name for, and saving
    /// wrote that blank over every member.
    var names: [String] {
        var seen = Set<String>()
        return entries.compactMap { entry in
            guard let name = entry.name, !name.isEmpty, seen.insert(name).inserted else {
                return nil
            }
            return name
        }
    }

    /// What to call this row: nothing, the one name, or the fact that its
    /// members disagree.
    var displayName: String? {
        let names = names
        return names.count > 1 ? "Mixed names" : names.first
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
