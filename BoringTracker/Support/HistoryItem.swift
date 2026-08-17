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

    /// The two lines a History row draws: what this was called, and what it
    /// was.
    struct Line: Equatable {
        /// Every row has an identity line, so the eye lands on what a row *is*
        /// before it lands on its numbers.
        ///
        /// Non-empty for every document the app can produce, and **not**
        /// guaranteed for one it can only be given: a tracker whose `name` is
        /// blank draws a blank line here. The editor will not save one and
        /// nothing in the app creates one, but `Store.validateImport` checks
        /// ids, `decimals` and `sortIndex` without ever looking at a name, so an
        /// imported or hand-edited file can carry it. Guarding it here would
        /// treat the symptom — that tracker is blank in settings and blank on
        /// its own card too — so the note is in the small-things list instead.
        var identity: String
        var values: String
    }

    /// Both lines, from one walk over the row's trackers.
    ///
    /// Together rather than as two calls because they have to agree: the
    /// identity line says which tracker a lone number belongs to, so the values
    /// line must not say it again. Here rather than in the view because that
    /// agreement is a rule worth pinning down in a test, and because
    /// `displayName` — the other half of the same question — already lives on
    /// this type.
    ///
    /// The dictionary comes from the caller: a screenful of rows would
    /// otherwise each rebuild it from `Store.trackers`.
    func line(trackers: [UUID: Tracker]) -> Line {
        let entries = entries.sorted { lhs, rhs in
            let left = trackers[lhs.trackerID]?.sortIndex ?? .max
            let right = trackers[rhs.trackerID]?.sortIndex ?? .max
            return (left, lhs.trackerID, lhs.id) < (right, rhs.trackerID, rhs.id)
        }
        // One number is a special case for the identity line's sake, not for
        // the layout's: with nothing to tell it apart from, its tracker has
        // already been named on the line above it.
        //
        // **Only when the line above is the tracker.** A name the user typed
        // wins the identity line, and then nothing has said which tracker this
        // is — so "morning / 3" on a unitless tracker would name neither the
        // number nor the thing it counts, and a named lone entry whose tracker
        // has been deleted would drop the "Deleted tracker" that explains why
        // its repeat disc is off. Both were live for one review round.
        let alone = entries.count == 1 && displayName == nil
        // "Deleted tracker" on a value tells that member apart from the ones
        // that survived. When *none* survived, it tells nothing apart, and the
        // identity line has already said it once — so a batch whose two
        // trackers were both deleted read "Deleted tracker" three times in one
        // row. Reachable in two taps: settings offers a deletion that keeps the
        // history, so removing both members of a group orphans every batch it
        // ever logged.
        let identitySaysDeleted = displayName == nil
            && !entries.contains { trackers[$0.trackerID] != nil }
        let units = entries.compactMap { trackers[$0.trackerID]?.unit }
        let values = entries
            .map { entry in
                guard let tracker = trackers[entry.trackerID] else {
                    return alone || identitySaysDeleted
                        ? entry.value.formatted()
                        : "Deleted tracker: \(entry.value.formatted())"
                }
                let needsName = !alone
                    && (tracker.unit.isEmpty || units.count(where: { $0 == tracker.unit }) > 1)
                return needsName
                    ? "\(tracker.name): \(tracker.format(entry.value))"
                    : tracker.format(entry.value)
            }
            .joined(separator: ", ")
        return Line(identity: identity(of: entries, in: trackers), values: values)
    }

    /// What to call a row that was never named: the tracker, the group, or the
    /// honest admission that the tracker is gone.
    ///
    /// One tracker names itself, however it is grouped — "Weight" says more
    /// about a lone reading than the group "Weight" does, and for a lone
    /// calorie entry "Food" would be the wrong half of the answer. Several
    /// trackers take the group they were logged as, which is what the log sheet
    /// called them when it wrote them. Anything else — a batch spanning groups,
    /// which only a hand-edited or imported file produces — lists its trackers,
    /// and the row wraps if that runs long. No line limit: the values line is
    /// already allowed to wrap (item 14b measured a two-line row and kept it),
    /// so capping the identity line alone would truncate the quieter half of a
    /// row whose louder half is permitted to grow.
    private func identity(of entries: [Entry], in trackers: [UUID: Tracker]) -> String {
        if let name = displayName { return name }
        let resolved = entries.compactMap { trackers[$0.trackerID] }
        guard !resolved.isEmpty else { return "Deleted tracker" }
        if Set(resolved.map(\.id)).count == 1 { return resolved[0].name }
        let groups = Set(resolved.map(\.group))
        if groups.count == 1, let group = groups.first, !group.isEmpty { return group }
        var seen = Set<String>()
        return resolved
            .compactMap { seen.insert($0.name).inserted ? $0.name : nil }
            .joined(separator: ", ")
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
