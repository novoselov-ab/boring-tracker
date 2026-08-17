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

    /// Whether this row is one of the things you can ask for by name.
    ///
    /// The Repeat screen lists these and nothing else: a name is what makes
    /// something repeatable, and an unnamed number is a measurement rather than
    /// a meal (docs/TODO.md item 16). *Any* named member is enough — a batch
    /// whose members disagree is already known by `displayName` everywhere
    /// else, and it is still a thing you typed a name for.
    var isNamed: Bool { !names.isEmpty }

    /// What makes two rows the same thing you ate: the names you typed, and
    /// every value against the tracker it was logged to.
    ///
    /// **Both halves, and the values are the half that is easy to leave out.**
    /// Collapsing by name alone would hide a bigger portion behind whichever
    /// one was logged last — "chicken rice" at 160 kcal and at 100 kcal are two
    /// things you ate, and a screen that shows one of them and calls it the
    /// other is worse than a screen that repeats itself (docs/TODO.md item 16).
    ///
    /// The tracker is part of a value because a number on its own is not one:
    /// 100 on Calories and 100 on Protein are different logs, and a batch that
    /// logged both is different again from one that logged only the first.
    ///
    /// Both halves are sorted, because neither is ordered by anything the user
    /// controls: a batch's members each carry their own name, and nothing
    /// promises two logs of one meal wrote them in the same order.
    ///
    /// Names are compared exactly, so "Porridge" and "porridge" stay two rows.
    /// Search folds case and diacritics and this does not, deliberately: search
    /// only decides what you are shown, while this decides what is *hidden
    /// behind* a row, and a normalisation that swallows the wrong two rows is
    /// invisible from the screen. iOS capitalises the name field's first letter
    /// either way, so the case that would benefit is rare.
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

    /// Whether a search for `query` keeps this row.
    ///
    /// Against the names that were typed, not against the identity line: that
    /// line falls back to a tracker or a group for rows nobody named, and those
    /// are not on this screen at all — so searching "weight" would otherwise
    /// return rows whose only claim to the word is the tracker they landed on.
    ///
    /// `localizedStandardContains` is the comparison the Finder uses: case- and
    /// diacritic-insensitive, so "creme" finds "Crème" and "RICE" finds "rice".
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return names.contains { $0.localizedStandardContains(query) }
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
