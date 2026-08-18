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

    /// Whether this row belongs on the Log again list — which is a question
    /// about the trackers it was logged to, not about what you called it.
    ///
    /// **It is not "can this be repeated", and the name says so since item 23**:
    /// a live weigh-in batch is rejected here and `logAgain` still writes its
    /// calories. The question a *control* asks is `Store.repeatableEntries`,
    /// which is what decides both the write and the greying — guarding a new
    /// repeat control on this predicate instead would refuse the whole weigh-in
    /// row, which is the "at the control" shape item 23 weighed and turned
    /// down. It was called `isRepeatable` until then, when the two questions
    /// still had one answer.
    ///
    /// **The kind decides, and the name decides nothing** (docs/TODO.md item
    /// 21). A **daily total** can be logged again whether or not you named it:
    /// 450 kcal and 30 g is the same dinner however it was typed, and item 16's
    /// rule — a name is what makes something repeatable — was hiding every one
    /// of those. A **measurement** cannot, however carefully it was named:
    /// repeating yesterday's weight does not weigh you, it writes a reading you
    /// never took.
    ///
    /// **A batch mixing kinds is not listed, and item 21's reason for that has
    /// gone.** It was that one tap would write a false weight to save retyping
    /// the calories; since item 23 the tap writes the calories alone, from
    /// `Store.repeatableEntries`, so the row could be offered here without
    /// writing anything nobody logged.
    ///
    /// **What keeps it out now is this list rather than that write.** A row here
    /// is `repeatKey`, and the key holds every value the row carries — including
    /// the weight, which is different every morning. Listing mixed rows
    /// therefore collapses none of them: measured on thirty daily weigh-ins of
    /// the identical 200 kcal breakfast, thirty rows, each drawing a weight it
    /// would not write, and a plain 200 kcal logged without the scale makes a
    /// thirty-first rather than joining one of them. That is History with a
    /// search field, which is the one thing this screen must not become. Making
    /// it right means a Log again row being built from what a tap *writes*
    /// rather than from what the batch *holds* — a change to what a row on this
    /// screen is, and its own item.
    ///
    /// The app produces these whenever a measurement tracker shares a log group
    /// with a daily total, so it is an ordinary shape, not an imported one.
    ///
    /// **A member whose tracker has been deleted is neither**, so it can
    /// neither qualify a row nor veto one: there is no record left to read a
    /// kind from, and nothing writes to it anyway. A row with no surviving
    /// tracker at all therefore drops out of the list, where item 16 kept it —
    /// a row that can never be written is a record rather than a thing to do
    /// again, and it is still in History. Item 16's reason for keeping it was
    /// that *archiving* a tracker must not make your food disappear, and
    /// archiving still cannot: an archived tracker is still a record, still has
    /// a kind, and its rows stay listed and sink to the bottom, greyed.
    ///
    /// **Archiving is not part of this question at all**, which is why the kind
    /// is read from the tracker whether or not it is archived. Deciding
    /// membership on what a tap would *write* instead would take the rows item
    /// 16 protected straight back out: archive a tracker and its rows would
    /// stop being listed, where the rule is that they stay, sink to the bottom
    /// and grey.
    ///
    /// Until item 23 this paragraph gave the mirror-image reason — that a
    /// write-based rule would let archiving your scale silently *add* the
    /// weigh-in batches above. That half is spent, and is left recorded rather
    /// than quietly swapped: a tap never writes a measurement now, so those
    /// batches are exactly as writable archived as not.
    func belongsInRepeatList(kinds: [UUID: Tracker.Kind]) -> Bool {
        // No `compactMap` and no intermediate array: `Store.repeatItems` asks
        // this of every row in the history, on a walk measured in milliseconds.
        var found = false
        for entry in entries {
            guard let kind = kinds[entry.trackerID] else { continue }
            if kind == .measurement { return false }
            found = true
        }
        return found
    }

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
    /// **Values are compared as stored, not as drawn**, and the two can come
    /// apart: a tracker's `decimals` is editable, so logging "rice" at 100.4 and
    /// at 100.0 against a one-decimal tracker gives two rows correctly, and
    /// setting that tracker to zero decimals afterwards leaves both rows reading
    /// "rice / 100 kcal" with only their dates to tell them apart. Keying on the
    /// formatted string instead would collapse them — and would make the key
    /// depend on a setting, and cost a `Tracker.format` per value on a walk
    /// measured in milliseconds over thousands of rows. Left as a known limit of
    /// a rare sequence: both rows write nearly the same thing, so a tap on the
    /// wrong one is nearly the right log.
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
    /// line falls back to a tracker or a group for rows nobody named, so
    /// searching "weight" would otherwise return rows whose only claim to the
    /// word is the tracker they landed on. **So a row nobody named cannot be
    /// found by typing** — on either screen — and both fields say "Search
    /// names" for that reason. Since item 21 the Log again list carries unnamed
    /// rows too, and a query empties them out of it; that is the field doing
    /// what it says rather than a gap, and a search that fell back to tracker
    /// names would be answering a different question from the one asked.
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
