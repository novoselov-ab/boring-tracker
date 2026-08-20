import Foundation

/// A record that two devices can each hold a version of.
///
/// The whole merge story is these two requirements: a stable identity, and a
/// timestamp saying when this copy last changed.
protocol MergeableRecord: Codable, Hashable, Identifiable, Sendable where ID == UUID {
    var id: UUID { get }
    var modified: Date { get }
    /// The part of the record that `modified` actually speaks for.
    ///
    /// Anything carrying its own timestamp is blanked here, because the
    /// conflict tie-break compares records as text and `combining` rewrites
    /// those fields on the survivor. A tie-break that could read them would
    /// depend on what had already been merged, which costs associativity: the
    /// same three documents would resolve differently depending on the order
    /// they were combined in.
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

/// Everything the app owns, in one value.
///
/// This is simultaneously the in-memory state, the file on disk, and the export
/// format — see "Storage: a JSON file" in docs/TECH.md. There is no separate
/// schema and no mapping layer between the three.
struct StoreDocument: Codable, Hashable, Sendable {

    /// What a build recognises a file it cannot safely read by. Migration is a
    /// function from N to N+1, run at load; see `StoreMigration`.
    ///
    /// **Bumping this now costs a step.** While nothing had shipped it was left
    /// alone through several changes of shape, because the number's whole job
    /// is compatibility with a build that exists somewhere else and no such
    /// build existed — the only older files were on our own simulators, and one
    /// of those is quarantined and started over rather than converted. The
    /// first release ends that: from it on, every version of this number is a
    /// shape somebody is holding, and a bump without a step in
    /// `StoreMigration.steps` refuses to read their file. A test asserts there
    /// is a step for every version below this one.
    static let currentSchemaVersion = 2

    /// How long a deletion is remembered. Long enough that a second device can
    /// be off for half a year and still learn about it; short enough that the
    /// file doesn't grow forever. Plain seconds, because a 180-day window does
    /// not care that DST makes two of those days 23 or 25 hours long.
    static let tombstoneLifetime: TimeInterval = 180 * 24 * 60 * 60

    var schemaVersion: Int = currentSchemaVersion
    var trackers: [Tracker] = []
    /// Kept sorted oldest first by (`date`, `id`). Every reader wants
    /// chronological order, so paying for it once at the mutation is cheaper
    /// than sorting per screen.
    var entries: [Entry] = []
    var tombstones: [Tombstone] = []

    /// A brand new install: useful before it has been configured at all.
    static var starter: StoreDocument {
        StoreDocument(trackers: Tracker.starterSet)
    }

    var isEmpty: Bool {
        trackers.isEmpty && entries.isEmpty && tombstones.isEmpty
    }
}

// MARK: - Tombstones

extension StoreDocument {

    /// Deletion times by record id, newest deletion winning.
    ///
    /// Newest rather than oldest: if the same record was deleted on two devices
    /// at different times, keeping the later one delays compaction, and a
    /// tombstone that outlives its usefulness is harmless where one that is
    /// dropped too early resurrects deleted data.
    var deletions: [UUID: Date] {
        var result: [UUID: Date] = [:]
        result.reserveCapacity(tombstones.count)
        for stone in tombstones {
            if let existing = result[stone.id], existing >= stone.deleted { continue }
            result[stone.id] = stone.deleted
        }
        return result
    }

    /// Records a deletion and drops the record. Nothing is ever removed
    /// silently — the merge on the other device has to be able to learn it.
    mutating func delete(id: UUID, at time: Date = .stamp()) {
        trackers.removeAll { $0.id == id }
        entries.removeAll { $0.id == id }
        if let index = tombstones.firstIndex(where: { $0.id == id }) {
            tombstones[index].deleted = max(tombstones[index].deleted, time)
        } else {
            tombstones.append(Tombstone(id: id, deleted: time))
        }
    }

    /// Forgets deletions older than the window. Anything this drops can be
    /// resurrected by a device that has been offline longer than
    /// `tombstoneLifetime`, which is the accepted price of not growing the file
    /// forever.
    func compactingTombstones(now: Date = Date()) -> StoreDocument {
        let cutoff = now.addingTimeInterval(-Self.tombstoneLifetime)
        var copy = self
        copy.tombstones = tombstones.filter { $0.deleted > cutoff }
        return copy
    }
}

// MARK: - Merge

extension StoreDocument {

    /// Union by id: keep the newer version of anything edited on both sides,
    /// and let a tombstone beat a resurrection.
    ///
    /// Deliberately unconditional on that last point — a delete wins over an
    /// edit even if the edit is newer. The motivating case is importing an old
    /// backup that still contains things you have since thrown away, and
    /// "deleted stuff stays deleted" is the behaviour that never loses trust.
    /// The reverse rule would make every restore resurrect old data.
    ///
    /// The operation is commutative, associative and idempotent, so it does not
    /// matter which document is `self`, in what order imports happen, or how
    /// many times the same file is imported.
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

    /// Entries in the order the whole app reads them: oldest first, id breaking
    /// ties so that two entries logged in the same millisecond still land in a
    /// stable order on every device.
    static func sorted(_ entries: [Entry]) -> [Entry] {
        entries.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    /// `combining` gets the winner and the loser, in that order, and returns
    /// the record to keep. It exists for fields that carry their own timestamp
    /// and therefore have to survive their record losing — today that is a
    /// tracker's `sortIndex`. The default keeps the winner whole.
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

    /// Newer `modified` wins.
    ///
    /// The tie-break exists so the result does not depend on argument order:
    /// two genuinely different records stamped in the same millisecond are
    /// settled by comparing their canonical JSON, which is stable across
    /// devices and processes in a way that hash values are not.
    private static func beats<T: MergeableRecord>(_ candidate: T, _ existing: T) -> Bool {
        if candidate.modified != existing.modified {
            return candidate.modified > existing.modified
        }
        // Content only. Two copies of a tracker that differ solely in where it
        // sits are not a conflict at all — they tie here, and `combining`
        // settles the position separately on its own timestamp.
        let (mine, theirs) = (candidate.contentOnly, existing.contentOnly)
        if mine == theirs { return false }
        return canonicalText(mine) > canonicalText(theirs)
    }

    private static func canonicalText<T: Encodable>(_ record: T) -> String {
        guard let data = try? StoreCoding.encoder().encode(record) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
