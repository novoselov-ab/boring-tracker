import Foundation

/// One row in the complete history: every surviving member of a batch, or one
/// ordinary entry when no batch connects it to anything else.
///
/// A batch whose members have been edited across midnight still stays one row,
/// sorted by its newest member: splitting one event across two sections would
/// make editing and deleting it once impossible, which is why the batch exists.
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

    /// The one place that decides what a batch is called — the row and
    /// `BatchEditor` both read it. When each had its own rule, the editor opened
    /// blank on a batch the row showed a name for, and saving wrote that blank
    /// over every member.
    var names: [String] {
        var seen = Set<String>()
        return entries.compactMap { entry in
            guard let name = entry.name, !name.isEmpty, seen.insert(name).inserted else {
                return nil
            }
            return name
        }
    }

    var displayName: String? {
        let names = names
        return names.count > 1 ? "Mixed names" : names.first
    }

    /// The same row with only the members `isIncluded` keeps, or `nil` when that
    /// leaves nothing.
    ///
    /// A Log again row projects *first*, because the screen promises what a tap
    /// writes: built from what the batch holds instead, thirty daily weigh-ins of
    /// the identical breakfast keyed as thirty rows, since `repeatKey` carries
    /// every value and the weight differs every morning.
    ///
    /// `Store.repeatItems` asks this of every row **twice** — once for
    /// membership, once to cut the row down — so it returns `self` unallocated
    /// when everything is kept. The two must stay separate: one merged predicate
    /// would decide membership on what a tap writes, emptying the list the moment
    /// anything is archived.
    func keeping(_ isIncluded: (Entry) -> Bool) -> HistoryItem? {
        if entries.allSatisfy(isIncluded) { return self }
        return HistoryItem(entries: entries.filter(isIncluded))
    }

    /// Which of the three reasons a repeat is not offered for this row, in one
    /// word — or `nil` when the row has already said it.
    ///
    /// **Ask this only about a row that cannot be repeated.** It decides *which*
    /// reason, never *whether* — that question is `Store.repeatableEntries`.
    ///
    /// A row mixing an archived total with a live measurement gets "Archived",
    /// the actionable half. The word comes from `Tracker.Kind.label` rather than
    /// a literal, so renaming the kind cannot leave History saying the old word
    /// with every test still passing.
    ///
    /// Two kinds are unrepeatable now, and a row of both — which only an
    /// imported or hand-edited file produces, since neither can reach the log
    /// sheet — is named by its newest surviving member, which is `entries[0]`
    /// because `init` sorts newest first. That is true of part of the row in the
    /// same way "Archived" is.
    func repeatBlockedReason(trackers: [UUID: Tracker]) -> String? {
        let resolved = entries.compactMap { trackers[$0.trackerID] }
        guard !resolved.isEmpty else { return nil }
        guard resolved.allSatisfy({ $0.kind != .dailyTotal }) else { return "Archived" }
        return resolved[0].kind.label
    }

    /// What makes two rows the same thing you ate. **Both halves**, and the
    /// values are the one easy to leave out: by name alone, "chicken rice" at 160
    /// kcal hides behind the same name at 100. Sorted, because nothing promises
    /// two logs of one meal wrote their members in the same order.
    ///
    /// **Values are compared as stored, not as drawn.** Keying on the formatted
    /// string would make the key depend on the editable `decimals` setting and
    /// cost a `Tracker.format` per value over thousands of rows. The accepted
    /// cost is that dropping a tracker to zero decimals can leave two rows both
    /// reading "rice / 100 kcal".
    ///
    /// Names are compared exactly, unlike `matches`, which folds case: search
    /// decides what you are *shown*, this decides what is *hidden behind* a row,
    /// and swallowing the wrong two is invisible from the screen.
    struct RepeatKey: Hashable, Sendable {
        struct Value: Hashable, Sendable, Comparable {
            var tracker: UUID
            var value: Double

            static func < (lhs: Self, rhs: Self) -> Bool {
                (lhs.tracker, lhs.value) < (rhs.tracker, rhs.value)
            }
        }

        var names: [String]
        var values: [Value]
    }

    var repeatKey: RepeatKey {
        RepeatKey(
            names: names.sorted(),
            values: entries
                .map { RepeatKey.Value(tracker: $0.trackerID, value: $0.value) }
                .sorted()
        )
    }

    /// Against the names that were typed, not against the identity line, which
    /// falls back to a tracker or a group — searching "weight" would otherwise
    /// return rows whose only claim to the word is the tracker they landed on.
    /// **So a row nobody named cannot be found by typing**, which is why both
    /// search fields say "Search names".
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return names.contains { $0.localizedStandardContains(query) }
    }

    /// The two lines a History row draws: what this was called, and what it was.
    struct Line: Equatable {
        /// Non-empty for every document the app can produce, and **not**
        /// guaranteed for one it can only be given: `Store.validateImport` checks
        /// ids, `decimals` and `sortIndex` without ever looking at a name, so an
        /// imported or hand-edited file can draw a blank line here.
        var identity: String
        var values: String
    }

    /// Both lines from one walk, because they have to agree: the identity line
    /// says which tracker a lone number belongs to, so the values line must not
    /// say it again. The dictionary comes from the caller; a screenful of rows
    /// would otherwise each rebuild it from `Store.trackers`.
    func line(trackers: [UUID: Tracker]) -> Line {
        let entries = entries.sorted { lhs, rhs in
            let left = trackers[lhs.trackerID]?.sortIndex ?? .max
            let right = trackers[rhs.trackerID]?.sortIndex ?? .max
            return (left, lhs.trackerID, lhs.id) < (right, rhs.trackerID, rhs.id)
        }
        // A lone number may drop its tracker's name **only when the line above is
        // the tracker**. A name the user typed wins the identity line, and then
        // nothing has said which tracker this is — so "morning / 3" on a unitless
        // tracker names neither the number nor the thing it counts, and a named
        // lone entry whose tracker was deleted loses the "Deleted tracker" that
        // explains why its repeat disc is off.
        let alone = entries.count == 1 && displayName == nil
        // When *no* member's tracker survived, "Deleted tracker" on each value
        // tells nothing apart and the identity line has already said it — a batch
        // whose two trackers were both deleted read it three times in one row.
        // Reachable in two taps: settings offers a deletion that keeps history.
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
                    ? "\(tracker.name): \(tracker.entryText(entry.value))"
                    : tracker.entryText(entry.value)
            }
            .joined(separator: ", ")
        return Line(identity: identity(of: entries, in: trackers), values: values)
    }

    /// What to call a row that was never named. One tracker names itself however
    /// it is grouped — "Weight" says more about a lone reading than the group
    /// "Weight" does. A batch spanning groups, which only a hand-edited or
    /// imported file produces, lists its trackers and is allowed to wrap, because
    /// the values line already does.
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
