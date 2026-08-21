import Foundation

protocol MergeableRecord: Codable, Hashable, Identifiable, Sendable where ID == UUID {
    var id: UUID { get }
    var modified: Date { get }
    /// The part of the record that `modified` speaks for. Anything carrying its
    /// own timestamp is blanked, because `combining` rewrites those fields on the
    /// survivor — a tie-break that could read them would depend on what had
    /// already been merged, and three documents would resolve differently
    /// depending on the order they were combined in.
    var contentOnly: Self { get }
}

extension MergeableRecord {
    var contentOnly: Self { self }
}

extension Tracker: MergeableRecord {
    var contentOnly: Tracker {
        var copy = self
        copy.sortIndex = 0
        copy.orderModified = .distantPast
        return copy
    }
}

extension Entry: MergeableRecord {}

/// Everything the app owns, in one value: the in-memory state, the file on disk
/// and the export format are the same thing (docs/TECH.md).
struct StoreDocument: Codable, Hashable, Sendable {

    /// Bumping this needs a step in `StoreMigration.steps` for the version below
    /// it, or every shipped file is refused. A test asserts one exists for every
    /// version below this one.
    static let currentSchemaVersion = 2

    /// How long a deletion is remembered: long enough for a second device to be
    /// off for half a year. Plain seconds, because a 180-day window does not care
    /// that DST makes two of those days 23 or 25 hours long.
    static let tombstoneLifetime: TimeInterval = 180 * 24 * 60 * 60

    var schemaVersion: Int = currentSchemaVersion
    var trackers: [Tracker] = []
    /// Kept sorted oldest first by (`date`, `id`); every reader wants that order.
    var entries: [Entry] = []
    var tombstones: [Tombstone] = []

    var isEmpty: Bool {
        trackers.isEmpty && entries.isEmpty && tombstones.isEmpty
    }
}

// MARK: - Tombstones

extension StoreDocument {

    /// Deletion times by record id, newest deletion winning. A tombstone that
    /// outlives its usefulness is harmless; one dropped too early resurrects
    /// deleted data.
    var deletions: [UUID: Date] {
        var result: [UUID: Date] = [:]
        result.reserveCapacity(tombstones.count)
        for stone in tombstones {
            if let existing = result[stone.id], existing >= stone.deleted { continue }
            result[stone.id] = stone.deleted
        }
        return result
    }

    mutating func delete(id: UUID, at time: Date = .stamp()) {
        trackers.removeAll { $0.id == id }
        entries.removeAll { $0.id == id }
        if let index = tombstones.firstIndex(where: { $0.id == id }) {
            tombstones[index].deleted = max(tombstones[index].deleted, time)
        } else {
            tombstones.append(Tombstone(id: id, deleted: time))
        }
    }

    /// Forgets deletions older than the window. Anything dropped here can be
    /// resurrected by a device that was offline longer than `tombstoneLifetime`,
    /// which is the price of not growing the file forever.
    func compactingTombstones(now: Date = Date()) -> StoreDocument {
        let cutoff = now.addingTimeInterval(-Self.tombstoneLifetime)
        var copy = self
        copy.tombstones = tombstones.filter { $0.deleted > cutoff }
        return copy
    }
}

// MARK: - Merge

extension StoreDocument {

    /// Union by id: keep the newer version of anything edited on both sides, and
    /// let a tombstone beat a resurrection.
    ///
    /// Unconditionally on that last point — a delete wins over a newer edit —
    /// because the motivating case is importing an old backup holding things you
    /// have since thrown away. The reverse rule makes every restore resurrect
    /// them. Commutative, associative and idempotent, so the order and number of
    /// imports does not matter.
    func merged(with other: StoreDocument) -> StoreDocument {
        var deleted = deletions
        for (id, time) in other.deletions where (deleted[id] ?? .distantPast) < time {
            deleted[id] = time
        }

        var result = StoreDocument()
        result.schemaVersion = Self.currentSchemaVersion
        result.trackers = Self.union(trackers, other.trackers, deleted: deleted,
                                     combining: Tracker.keepingNewerOrder)
            .sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
        result.entries = Self.sorted(Self.union(entries, other.entries, deleted: deleted))
        result.tombstones = deleted
            .map { Tombstone(id: $0.key, deleted: $0.value) }
            .sorted { ($0.deleted, $0.id) < ($1.deleted, $1.id) }
        return result
    }

    /// The order the whole app reads entries in, stable across devices.
    static func sorted(_ entries: [Entry]) -> [Entry] {
        entries.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    /// `combining` takes the winner and the loser and returns the record to keep.
    /// It exists for fields that carry their own timestamp and so have to survive
    /// their record losing — today only a tracker's `sortIndex`.
    private static func union<T: MergeableRecord>(
        _ mine: [T], _ theirs: [T], deleted: [UUID: Date],
        combining: (T, T) -> T = { winner, _ in winner }
    ) -> [T] {
        var winners: [UUID: T] = [:]
        winners.reserveCapacity(mine.count + theirs.count)
        for record in mine where deleted[record.id] == nil {
            winners[record.id] = record
        }
        for record in theirs where deleted[record.id] == nil {
            guard let existing = winners[record.id] else {
                winners[record.id] = record
                continue
            }
            winners[record.id] = beats(record, existing)
                ? combining(record, existing)
                : combining(existing, record)
        }
        return Array(winners.values)
    }

    /// Newer `modified` wins. The tie-break stops the result depending on
    /// argument order: records stamped in the same second are settled on their
    /// canonical JSON, which is stable across devices and processes in a way
    /// hash values are not.
    private static func beats<T: MergeableRecord>(_ candidate: T, _ existing: T) -> Bool {
        if candidate.modified != existing.modified {
            return candidate.modified > existing.modified
        }
        // Content only: two copies differing solely in where the tracker sits are
        // not a conflict, so they tie here and `combining` settles the position.
        let (mine, theirs) = (candidate.contentOnly, existing.contentOnly)
        if mine == theirs { return false }
        return canonicalText(mine) > canonicalText(theirs)
    }

    private static func canonicalText<T: Encodable>(_ record: T) -> String {
        guard let data = try? StoreCoding.encoder().encode(record) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
