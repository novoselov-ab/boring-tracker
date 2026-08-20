import Foundation
#if canImport(UIKit)
import UIKit
#endif

@Observable
@MainActor
final class Store {

    private(set) var trackers: [Tracker]
    private(set) var entries: [Entry]
    private(set) var tombstones: [Tombstone]

    /// Today, in the calendar the user is currently living in. Stored rather
    /// than computed so that SwiftUI redraws when the day rolls over.
    private(set) var today: DayKey
    private(set) var origin: StoreOrigin
    private(set) var saveError: String?
    /// The last write that can be taken back, and there is only ever one of it: a
    /// newer write takes the slot and the older offer stops being made.
    ///
    /// **A newer write also ends a pending repeat's offer, and only a repeat's** —
    /// see `forgetRepeatUndo`. Undoing a repeat removes entries, so an offer that
    /// outlives the write it describes destroys data; undoing a deletion only puts
    /// records back, so it can go stale harmlessly.
    private enum LastWrite {
        /// Everything one deletion removed, newest first.
        case deleted([Entry])
        /// What one repeat wrote, and how many members of the row it had to leave
        /// out. The count is kept because only the moment of the tap knows it.
        case logged(entries: [Entry], skipped: Int)
    }

    private var lastWrite: LastWrite?

    /// The newest member of what was deleted most recently; the whole deletion is
    /// kept separately so one history-row delete can restore a whole batch.
    var lastDeletion: Entry? { lastDeletedEntries.first }
    var lastDeletionCount: Int { lastDeletedEntries.count }

    private var lastDeletedEntries: [Entry] {
        if case .deleted(let entries) = lastWrite { entries } else { [] }
    }

    struct LoggedAgain: Equatable, Sendable {
        var count: Int
        /// Members of the row a repeat may not write: the tracker is deleted or
        /// archived, or it is a measurement and a copy would be a reading nobody
        /// took (docs/TODO.md item 23). The measurement is the common one, so a
        /// hunt for a deleted tracker is the wrong place to start.
        var skipped: Int
    }

    var lastLoggedAgain: LoggedAgain? {
        guard case .logged(let entries, let skipped) = lastWrite else { return nil }
        return LoggedAgain(count: entries.count, skipped: skipped)
    }

    /// Which history row the last repeat wrote, so History can point at the new one
    /// (docs/TODO.md item 20).
    ///
    /// **Two repeats of the same food give two different values here**, because
    /// every write gets a fresh batch id — which is what lets a screen watch this
    /// and see the second tap. A count would be equal across both.
    var lastLoggedAgainRow: HistoryItem.ID? {
        guard case .logged(let entries, _) = lastWrite, let written = entries.first else {
            return nil
        }
        return written.batchID.map(HistoryItem.ID.batch) ?? .entry(written.id)
    }

    /// When that row was written. Read off the entries the write made rather than
    /// stamped separately, and answered here rather than by the screen that asks:
    /// History used to find the row in `historyItems` and read its date, which walks
    /// and sorts every entry ever logged.
    var lastLoggedAgainAt: Date? {
        guard case .logged(let entries, _) = lastWrite else { return nil }
        return entries.first?.date
    }

    /// The newest thing the last deletion took from this tracker. Undo restores the
    /// whole deletion either way; a tracker's own screen asks this because the newest
    /// member of a deleted batch belongs to only one of the trackers involved.
    func lastDeletion(for tracker: UUID) -> Entry? {
        lastDeletedEntries.first { $0.trackerID == tracker }
    }

    /// One derived index: the sum of every daily-total tracker, per local day.
    /// It backs both the home screen number and the graph, so nothing has to
    /// scan the entry list to draw.
    private(set) var totals: [DayTotal: Double] = [:]
    /// How many entries back each total, so an emptied day drops out of the index.
    private var entryCounts: [DayTotal: Int] = [:]

    struct DayTotal: Hashable {
        var tracker: UUID
        var day: DayKey
    }

    private(set) var calendar: Calendar
    /// The hour the day is cut at, midnight unless somebody has moved it (`DayStart`).
    /// Read by everything that derives a day and stored by nothing, so changing it is
    /// a rebuild rather than a migration.
    private(set) var dayStartHour: Int
    /// False when a test pinned the calendar, so system time-zone changes do
    /// not yank it back to the device's.
    private let followsSystemCalendar: Bool
    /// The clock, pinned by tests. `nil` in the app.
    ///
    /// **It pins which day the store thinks it is, not what a write stamps.**
    /// `today`, `refreshToday()` and `travel(to:)` read it; `add`, `addBatch`,
    /// `logAgain` and every `modified` stamp still read `Date.stamp()`. So a write
    /// lands at the real wall clock, under a `DayKey` the store does not consider
    /// today — a test that pins this and then asserts a total or a day label wants
    /// the real fix first.
    private let pinnedNow: Date?
    private var now: Date { pinnedNow ?? Date() }
    private let file: StoreFile
    private let saver: StoreSaver
    /// Counts mutations. The saver tells a late-arriving old document from the
    /// current one by it, and the graph knows when its aggregated points are stale.
    private(set) var revision: UInt64 = 0
    private var timeObserver: (any NSObjectProtocol)?
    private var dayRollTask: Task<Void, Never>?
    private var dayRollAt: Date?

    // MARK: - Life cycle

    /// Loads synchronously. The file is small, and doing this asynchronously
    /// would flash an empty home screen for longer than the decode takes.
    convenience init(file: StoreFile = .standard()) {
        let loaded = file.load()
        // **The one place `UserDefaults` is read**, and it is the app's entry point
        // rather than the designated init below: reading it there made every `Store`
        // a test builds inherit whatever the last test to call `setDayStartHour` had
        // written — in the same process, in parallel, and across simulator runs.
        self.init(
            document: loaded.document, origin: loaded.origin, file: file,
            dayStartHour: DayStart.hour(UserDefaults.standard.integer(forKey: DayStart.key))
        )
    }

    init(
        document: StoreDocument = .starter,
        origin: StoreOrigin = .fresh,
        file: StoreFile = .standard(),
        calendar: Calendar? = nil,
        now: Date? = nil,
        dayStartHour: Int = DayStart.midnight,
        saveWindow: Duration = .milliseconds(500)
    ) {
        let document = document.compactingTombstones()
        self.trackers = document.trackers.sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
        self.entries = StoreDocument.sorted(document.entries)
        self.tombstones = document.tombstones
        self.origin = origin
        self.calendar = calendar ?? .current
        self.followsSystemCalendar = calendar == nil
        self.pinnedNow = now
        let dayStart = DayStart.hour(dayStartHour)
        self.dayStartHour = dayStart
        self.today = DayKey(
            now ?? Date(), calendar: calendar ?? .current, dayStartHour: dayStart
        )
        self.file = file
        self.saver = StoreSaver(file: file, window: saveWindow)
        rebuildTotals()
        watchForTimeChanges()
        scheduleDayRoll()
    }

    isolated deinit {
        if let timeObserver {
            NotificationCenter.default.removeObserver(timeObserver)
        }
        dayRollTask?.cancel()
    }

    /// The document as it would be written or exported, assembled on demand.
    var document: StoreDocument {
        StoreDocument(
            schemaVersion: StoreDocument.currentSchemaVersion,
            trackers: trackers,
            entries: entries,
            tombstones: tombstones
        )
    }

    /// Writes anything outstanding and waits. Called when the scene stops being active.
    func flush() async {
        // No `revision += 1`: flushing when nothing has changed since the last
        // write should not rewrite the file.
        await saver.flush(document, revision: revision)
        saveError = await saver.lastError.map(Self.describe)
    }

    private func scheduleSave() {
        revision += 1
        let (document, revision) = (self.document, self.revision)
        Task { [weak self] in
            guard let self else { return }
            await saver.save(document, revision: revision)
            // Then wait for it, and read back whether it worked. `save` returns as
            // soon as the document is queued, so without `settled()` `saveError` only
            // ever moved on `flush` — and a disk that had stopped accepting writes
            // stayed silent for as long as the app was open.
            await saver.settled()
            let message = await saver.lastError.map(Self.describe)
            // Only on a change. `@Observable` publishes every set whether or not the
            // value moved, and there is one of these tasks per mutation — fifty in a
            // burst would invalidate home's notice row fifty times for nothing.
            if message != saveError { saveError = message }
        }
    }

    private static func describe(_ error: any Error) -> String {
        (error as NSError).localizedDescription
    }

    // MARK: - Reading

    func tracker(_ id: UUID) -> Tracker? {
        trackers.first { $0.id == id }
    }

    var activeTrackers: [Tracker] {
        trackers.filter { !$0.isArchived }
    }

    var archivedTrackers: [Tracker] {
        trackers.filter(\.isArchived)
    }

    /// The groups that exist, in the order their trackers appear.
    ///
    /// Derived every time rather than stored: a group is a string on a tracker, so
    /// this cannot go stale, leave an empty group behind, or orphan one. Archived
    /// trackers count, so their group is still offered.
    var groups: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tracker in trackers where !tracker.group.isEmpty {
            if seen.insert(tracker.group).inserted { result.append(tracker.group) }
        }
        return result
    }

    /// The active trackers in one group, in the order the log sheet draws their fields.
    func trackers(inGroup group: String) -> [Tracker] {
        trackers.filter { !$0.isArchived && $0.group == group }
    }

    /// Everything you can log in one go, in the order the home screen draws it: each
    /// group once, and every ungrouped tracker on its own.
    var logGroups: [LogGroup] {
        var seen = Set<String>()
        var result: [LogGroup] = []
        for tracker in trackers where !tracker.isArchived {
            let group = LogGroup(of: tracker)
            if seen.insert(group.rawValue).inserted { result.append(group) }
        }
        return result
    }

    /// The blocks both home and settings draw. Shared, so the two screens cannot
    /// disagree about what an order means.
    var activeTrackerRuns: [[Tracker]] {
        logGroups.map(trackers(in:))
    }

    func trackers(in group: LogGroup) -> [Tracker] {
        switch group {
        case .group(let name): trackers(inGroup: name)
        case .tracker(let id): tracker(id).map { $0.isArchived ? [] : [$0] } ?? []
        }
    }

    /// What tapping + opens: what you logged last, or the first thing on the home
    /// screen if that is gone — archived, deleted, or moved into a group. Takes the
    /// remembered group as the plain string `UserDefaults` returns it as, because
    /// deciding whether it still means anything is this method's job. Never a picker
    /// (docs/PRODUCT.md).
    func groupToLog(preferring remembered: String) -> LogGroup? {
        let available = logGroups
        if let group = LogGroup(rawValue: remembered), available.contains(group) {
            return group
        }
        return available.first
    }

    func total(for tracker: UUID, on day: DayKey) -> Double {
        totals[DayTotal(tracker: tracker, day: day)] ?? 0
    }

    /// The most recent reading, for measurement trackers. A reverse scan rather than
    /// a second index: entries are already sorted, so it stops at the first match.
    func latestEntry(for tracker: UUID) -> Entry? {
        entries.last { $0.trackerID == tracker }
    }

    func entries(for tracker: UUID) -> [Entry] {
        entries.filter { $0.trackerID == tracker }
    }

    func day(of entry: Entry) -> DayKey {
        dayKey(entry.date)
    }

    /// Which day a moment falls in, for this store. **Every day derived inside
    /// the store goes through here**, so the offset is applied once rather than
    /// remembered at seven call sites — which is how one of them comes to
    /// disagree with the totals index.
    func dayKey(_ date: Date) -> DayKey {
        DayKey(date, calendar: calendar, dayStartHour: dayStartHour)
    }

    /// Moves where the day is cut, and re-derives everything that depended on it.
    /// Persists, because this is the app's own setting rather than a value a caller
    /// owns; tests inject through `init` and never come here.
    func setDayStartHour(_ hour: Int) {
        let hour = DayStart.hour(hour)
        guard hour != dayStartHour else { return }
        dayStartHour = hour
        UserDefaults.standard.set(hour, forKey: DayStart.key)
        // Both, and in this order: the totals index is keyed by day, so it is
        // stale the instant the offset moves, and `today` may now be yesterday.
        rebuildTotals()
        refreshToday()
        // `refreshToday` only reschedules when the day actually changed, and moving
        // the boundary from 4am to 6am on an afternoon changes the next roll without
        // changing today.
        scheduleDayRoll()
        // No `revision += 1`. Nothing in the document changed, and that counter is
        // what tells the saver a late write is stale. What it was reached for — the
        // graph noticing its buckets moved — belongs in `TrackerChart.Key`.
    }

    /// Every row in the complete history, newest first. `batchID` is consumed here
    /// rather than inferred from matching times or names: those fields are editable,
    /// while the id is the stored statement that the values were one log.
    var historyItems: [HistoryItem] {
        var batches: [UUID: [Entry]] = [:]
        var items: [HistoryItem] = []
        for entry in entries {
            if let batchID = entry.batchID {
                batches[batchID, default: []].append(entry)
            } else if let item = HistoryItem(entries: [entry]) {
                items.append(item)
            }
        }
        items.append(contentsOf: batches.values.compactMap(HistoryItem.init(entries:)))
        // Comparing the pair outright spent 65ms of this method's 76ms, because
        // `sortID` builds a string each time it is read (iPhone 17 simulator, 15,000
        // entries, 7,500 rows; an old iPhone is several times slower). Reaching for
        // the id only when two rows share a second is the same order in 33ms, and
        // this runs on every redraw of the History screen.
        return items.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.sortID > rhs.sortID
        }
    }

    /// The Repeat screen's list: one row per distinct thing you have logged to a
    /// daily total, most recently logged first (docs/TODO.md items 16, 21, 29).
    ///
    /// **Membership is the projection, not a filter.** Every row is cut down to the
    /// members this screen is about — present, a daily total, archived or not — and a
    /// row with nothing left drops out. The kind decides and the name decides
    /// nothing: 450 kcal and 30 g is a dinner you can eat again whether or not you
    /// typed a word, and no measurement belongs here however carefully named.
    ///
    /// **Then a second cut, onto what a tap actually writes.** Membership has to keep
    /// archived members or a listed row could vanish; the row's *content* must not,
    /// or a batch logging a live total beside an archived one draws a value the tap
    /// drops. That second cut costs about 1ms over 7,644 entries and 2ms over 15,288
    /// (Debug build, iPhone 17 simulator, ten alternating runs).
    ///
    /// **Deduplicated by name *and* values** (`HistoryItem.RepeatKey`): forty logs of
    /// "chicken rice 100/10" are one row, while "chicken rice 160/16" stays its own,
    /// because a bigger portion is a different thing to log again. The row kept is
    /// the newest, so its date says when you last ate that — the one fact the
    /// collapsed rows all disagreed about. Deduplicating costs about 5ms over 7,644
    /// entries and 8ms over 15,294, paid once when the screen opens; a keystroke got
    /// cheaper, because `RepeatView` filters far fewer rows.
    ///
    /// **A row that cannot be written sorts below every row that can**, however
    /// recently it was logged. Archiving a tracker must not take your food off this
    /// screen, but a screenful of greyed rows in front of every row that still works
    /// is not a list you can log from.
    ///
    /// A filter over `historyItems` rather than its own walk of `entries`: grouping a
    /// batch into one row is the same question both screens ask, and a second walk
    /// would be a second chance to answer it differently.
    var repeatItems: [HistoryItem] {
        var index: [HistoryItem.RepeatKey: Int] = [:]
        var rows: [(item: HistoryItem, canRepeat: Bool)] = []
        let targets = repeatTargets
        // Two different questions, and keeping them apart is what makes this work.
        // `targets` is what a tap may **write**: present, not archived, a daily
        // total. `listable` is what this screen is **about**: present and a daily
        // total, archived or not.
        let listable = repeatListTargets
        for row in historyItems {
            // **Projected before anything else reads it**, so a weigh-in is listed
            // as its calories and collapses onto the plain breakfast of the same
            // calories — the only way thirty daily weigh-ins of one breakfast become
            // one row instead of thirty (`HistoryItem.keeping`).
            guard let listed = row.keeping({ listable.contains($0.trackerID) }) else { continue }
            // **Twice, and the second one is what makes the promise true.** A batch
            // that logged a live total *and* one you have since archived survives the
            // first cut whole, and a tap writes only the live half — so the row drew
            // a value it would not write and the bar said "Logged 1 of 2 again". The
            // listable row is kept only where the second cut leaves nothing: a row
            // whose every member is archived is unwritable, greyed, and says
            // "Archived" — a record rather than a promise.
            let item = listed.keeping({ targets.contains($0.trackerID) }) ?? listed
            let key = item.repeatKey
            if let at = index[key] {
                // **The newest row wins the slot, by its projected date.**
                // `historyItems` is sorted on the date the row had *before*
                // projection, and projection can drop the member that date came from
                // — keeping it would date the row before the last time you logged it,
                // which the day label states outright and the sort below orders on.
                if item.date > rows[at].item.date { rows[at].item = item }
            } else {
                index[key] = rows.count
                // Once per collapsed row, not once per comparison, and the same
                // answer for every row the key collapsed: the key carries the tracker
                // ids, so they all name the same trackers.
                rows.append((item, !repeatableEntries(of: item, targets: targets).isEmpty))
            }
        }
        // The tie-break is explicit rather than left to the sort's stability, which
        // Swift's does not promise. It cannot be left to the order `rows` was built
        // in either: that is `historyItems` order, which is the date each row had
        // before projection.
        return rows
            .sorted { lhs, rhs in
                if lhs.canRepeat != rhs.canRepeat { return lhs.canRepeat }
                if lhs.item.date != rhs.item.date { return lhs.item.date > rhs.item.date }
                return lhs.item.sortID > rhs.item.sortID
            }
            .map(\.item)
    }

    // MARK: - Entries

    func add(_ entry: Entry) {
        var entry = entry
        entry.modified = .stamp()
        insertSorted(entry)
        apply(1, to: entry)
        forgetRepeatUndo()
        refreshToday()
        scheduleSave()
    }

    /// Logs the same moment against several trackers at once. One name across all of
    /// them: the log sheet has one name field.
    func add(values: [UUID: Double], at date: Date = .stamp(), name: String? = nil) {
        addBatch(
            values.sorted { $0.key < $1.key }.map { (tracker: $0.key, value: $0.value, name: name) },
            at: date
        )
    }

    /// The one place a batch is written, and the one code path behind both the log
    /// sheet and repeating a history row.
    ///
    /// Members share a `batchID`, which is what makes them one logged food rather
    /// than two rows that agree on the clock. Assigned even for a single value: what
    /// was logged together is a property of the log, not of how many trackers it
    /// happened to touch.
    ///
    /// Takes pairs rather than a `[UUID: Double]` because a repeat carries each
    /// member's own name, and because keying by tracker would silently drop one of
    /// two entries that an imported file put in one batch against the same tracker,
    /// after the row had already displayed both.
    @discardableResult
    private func addBatch(
        _ values: [(tracker: UUID, value: Double, name: String?)],
        at date: Date = .stamp()
    ) -> [Entry] {
        let date = date.canonicalized
        let batch = UUID()
        return values.map { value in
            let entry = Entry(
                trackerID: value.tracker, value: value.value,
                date: date, name: value.name, batchID: batch
            )
            add(entry)
            return entry
        }
    }

    /// Which members of a history row a repeat can write again.
    ///
    /// A tracker deleted with its history kept leaves entries pointing at nothing,
    /// and an archived tracker is one you have said you are done logging — the log
    /// sheet reaches neither, so writing to them from here would put a number
    /// somewhere no other screen offers to, and somewhere home would never show it.
    ///
    /// **A measurement is refused by the same rule rather than a second one**
    /// (docs/TODO.md item 23): repeating a reading does not take one, it writes a
    /// weight nobody stood on the scale for, dated now, which home's Weight card then
    /// shows as today's reading.
    ///
    /// **The choke point rather than the control.** Disabling the disc on any row the
    /// Log again list would refuse reads more simply, but it refuses a weigh-in batch
    /// whole and leaves `logAgain` willing to write a measurement for whatever calls
    /// it next. Dropping the member instead writes the calories and says "Logged 1 of
    /// 2 again".
    func repeatableEntries(of item: HistoryItem) -> [Entry] {
        repeatableEntries(of: item, targets: repeatTargets)
    }

    /// The same question with the answer hoisted, for a caller asking it about every
    /// row at once.
    ///
    /// `repeatItems` asks once per collapsed row and `tracker(_:)` is a linear scan,
    /// so the cost grows with the number of trackers as well as of rows. On the worst
    /// shape there is — 15,294 entries that all differ, so nothing collapses —
    /// hoisting the set took the whole walk from 54.0–56.9ms to 49.9–51.0ms over
    /// eight trackers, and from 56.2–59.3ms to 54.4–55.5ms over three. The public
    /// entry point above builds the set per call instead, which is sub-microsecond on
    /// a handful of trackers and keeps the rule written once.
    private func repeatableEntries(of item: HistoryItem, targets: Set<UUID>) -> [Entry] {
        item.entries.filter { targets.contains($0.trackerID) }
    }

    /// Every tracker a repeat may write to: still present, not archived, and a daily
    /// total. See `repeatableEntries(of:)` for why the kind belongs in this set.
    private var repeatTargets: Set<UUID> {
        Set(trackers.lazy.filter { !$0.isArchived && $0.kind != .measurement }.map(\.id))
    }

    /// Every tracker the Log again *list* is about: still present, a daily total,
    /// **archived or not**.
    ///
    /// The one difference from `repeatTargets`, and it is item 16's rule: a tracker
    /// you archive is one you have said you are done logging, not one whose history
    /// should vanish from a screen. Those rows stay listed, sort to the bottom and
    /// draw greyed. **Membership only** — what a listed row shows is `repeatTargets`
    /// where that leaves anything.
    private var repeatListTargets: Set<UUID> {
        Set(trackers.lazy.filter { $0.kind != .measurement }.map(\.id))
    }


    /// Logs a history row again, now: the same values against the same trackers, each
    /// keeping its own name, with today's timestamp and a **new** batch id. It writes;
    /// it never edits, which is what makes it safe to tap on a five-year-old entry.
    ///
    /// Partial rows write what they can and say so through `lastLoggedAgain`. Refusing
    /// the whole row because one of three trackers was deleted would make a supported
    /// choice quietly disable a button on every row it ever touched.
    @discardableResult
    func logAgain(_ item: HistoryItem) -> Bool {
        let repeatable = repeatableEntries(of: item)
        guard !repeatable.isEmpty else { return false }
        let written = addBatch(
            repeatable.map { (tracker: $0.trackerID, value: $0.value, name: $0.name) }
        )
        lastWrite = .logged(entries: written, skipped: item.entries.count - repeatable.count)
        return true
    }

    /// Ends a pending repeat's undo, because something newer has been written.
    ///
    /// Only the repeat's. Undoing a repeat **removes** entries by id, so an offer that
    /// outlives the write it describes destroys data: repeat a row, log a different
    /// food, and a bar still reading "Logged again" deletes the repeat with no
    /// tombstone behind it. Undoing a deletion only puts records back, so its offer
    /// keeps standing however stale it gets (docs/PHILOSOPHY.md).
    private func forgetRepeatUndo() {
        if case .logged = lastWrite { lastWrite = nil }
    }

    /// Takes back the repeat that was just written, since a mistap now costs data
    /// rather than a moment. It records **no tombstone**: these entries are being
    /// unmade, not deleted, and a tombstone would carry "never allow this id again"
    /// into every future merge for a log that lasted two seconds. The same honest
    /// limit as `undoLastDeletion`, in reverse: an export taken in between holds them.
    func undoLastLog() {
        guard case .logged(let written, _) = lastWrite else { return }
        let ids = Set(written.map(\.id))
        let existing = entries.filter { ids.contains($0.id) }
        lastWrite = nil
        guard !existing.isEmpty else { return }
        for entry in existing { apply(-1, to: entry) }
        entries.removeAll { ids.contains($0.id) }
        refreshToday()
        scheduleSave()
    }

    func update(_ entry: Entry) {
        update([entry])
    }

    /// Saves every member edited from one history row as one mutation. If any
    /// member disappeared while the editor was open, nothing is written: a
    /// stale sheet must not resurrect an entry deleted elsewhere.
    @discardableResult
    func update(_ updatedEntries: [Entry]) -> Bool {
        let ids = Set(updatedEntries.map(\.id))
        guard !ids.isEmpty,
              ids.count == updatedEntries.count,
              entries.count(where: { ids.contains($0.id) }) == ids.count else { return false }

        let oldEntries = entries.filter { ids.contains($0.id) }
        let previous = Dictionary(oldEntries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for old in oldEntries { apply(-1, to: old) }
        entries.removeAll { ids.contains($0.id) }

        let now = Date.stamp()
        var changedSomething = false
        for var updated in updatedEntries {
            // Only a member that actually changed gets a fresh stamp. The batch
            // editor submits every member of the row whichever one you touched, so
            // stamping them all made a no-op rewrite of the protein entry outrank —
            // and silently discard — a real edit to it made on another device.
            if let old = previous[updated.id] {
                var withoutStamp = updated
                withoutStamp.modified = old.modified
                let changed = withoutStamp != old
                updated.modified = changed ? now : old.modified
                changedSomething = changedSomething || changed
            } else {
                updated.modified = now
                changedSomething = true
            }
            insertSorted(updated)
            apply(1, to: updated)
        }
        // The same test decides both: a save that changed nothing is not a newer
        // write, so it must not withdraw a pending repeat's undo any more than it
        // restamps a member.
        if changedSomething { forgetRepeatUndo() }
        refreshToday()
        scheduleSave()
        return true
    }

    func delete(_ entry: Entry) {
        delete(entries: [entry])
    }

    /// Deletes the complete surviving batch behind one history row. A missing
    /// `batchID`, and a batch reduced to one member by tracker detail, both delete
    /// just that ordinary single row.
    func deleteBatch(containing entry: Entry) {
        let matching = if let batchID = entry.batchID {
            entries.filter { $0.batchID == batchID }
        } else {
            entries.filter { $0.id == entry.id }
        }
        delete(entries: matching)
    }

    private func delete(entries deletedEntries: [Entry]) {
        let ids = Set(deletedEntries.map(\.id))
        let existing = entries.filter { ids.contains($0.id) }
        guard !existing.isEmpty else { return }
        for entry in existing {
            apply(-1, to: entry)
            recordDeletion(of: entry.id)
        }
        entries.removeAll { ids.contains($0.id) }
        lastWrite = .deleted(existing.sorted { ($0.date, $0.id) > ($1.date, $1.id) })
        refreshToday()
        scheduleSave()
    }

    /// Puts back the entry that was just deleted, removing the tombstone as well as
    /// restoring the record — the deletion is being undone, not recorded and reversed.
    ///
    /// One honest limit: an export taken between the delete and the undo carries the
    /// tombstone, and re-importing it deletes the entry again. Tombstones beat
    /// resurrections on purpose.
    func undoLastDeletion() {
        guard !lastDeletedEntries.isEmpty else { return }
        let existingIDs = Set(entries.map(\.id))
        let restorable = lastDeletedEntries.filter { !existingIDs.contains($0.id) }
        let restoredIDs = Set(restorable.map(\.id))
        tombstones.removeAll { restoredIDs.contains($0.id) }
        for entry in restorable {
            insertSorted(entry)
            apply(1, to: entry)
        }
        lastWrite = nil
        guard !restorable.isEmpty else { return }
        refreshToday()
        scheduleSave()
    }

    // MARK: - Trackers

    /// Slots a grouped tracker beside the last visible tracker in that group, so the
    /// settings list draws a new `Food` tracker next to the rest of Food. A loose
    /// tracker, one naming a group that does not exist yet, and one whose group is
    /// entirely archived all go at the end. Home does not need this: it draws blocks
    /// from `logGroups`.
    ///
    /// Only a real insertion renumbers. Pushing rows down is a decision about the
    /// whole list, so it stamps every row's `orderModified` and merges whole
    /// (docs/TECH.md). Appending moves nothing, so it takes the next index and leaves
    /// every other record alone: stamping there would let adding a tracker here
    /// outrank, and silently discard, a drag made on another device.
    func add(_ tracker: Tracker) {
        var tracker = tracker
        let now = Date.stamp()
        tracker.modified = now
        tracker.orderModified = now
        let insertion = tracker.group.isEmpty
            ? trackers.endIndex
            : trackers.lastIndex { !$0.isArchived && $0.group == tracker.group }
                .map { $0 + 1 } ?? trackers.endIndex
        if insertion == trackers.endIndex {
            let maximum = trackers.map(\.sortIndex).max() ?? -1
            if maximum >= Int.max - 1 {
                // An imported file can carry a very large but still valid
                // index. Renumber before arithmetic reaches Int.max; the
                // alternative is a trap on this or the next addition.
                trackers.append(tracker)
                for index in trackers.indices {
                    trackers[index].sortIndex = index
                    trackers[index].orderModified = now
                }
            } else {
                tracker.sortIndex = maximum + 1
                trackers.append(tracker)
            }
        } else {
            trackers.insert(tracker, at: insertion)
            for index in trackers.indices {
                trackers[index].sortIndex = index
                trackers[index].orderModified = now
            }
        }
        scheduleSave()
    }

    func update(_ tracker: Tracker) {
        guard let index = trackers.firstIndex(where: { $0.id == tracker.id }) else { return }
        let old = trackers[index]
        var updated = tracker
        // Position stays whatever the store currently says, never what the caller is
        // holding. The editor snapshots a tracker when it opens and a swipe action
        // captures one when the row is built, so saving a rename would otherwise
        // quietly undo a drag — or an import — that happened in between.
        updated.sortIndex = old.sortIndex
        updated.orderModified = old.orderModified
        // A save that changed nothing is not a write, and must not be stamped like
        // one. `TrackerEditor`'s Save is enabled on a non-empty name rather than on a
        // change, so opening a tracker to read its unit and tapping Save used to make
        // this device's copy newer — and a merge then silently discarded a rename made
        // on the iPad an hour earlier. Same rule as `update(_ updatedEntries:)` above.
        var withoutStamp = updated
        withoutStamp.modified = old.modified
        guard withoutStamp != old else { return }
        updated.modified = .stamp()
        let kindChanged = old.kind != updated.kind
        trackers[index] = updated
        if kindChanged { rebuildTotals() }
        scheduleSave()
    }

    /// Deletes the tracker. Its entries stay — keeping the history is a decision.
    func delete(_ tracker: Tracker) {
        trackers.removeAll { $0.id == tracker.id }
        recordDeletion(of: tracker.id)
        scheduleSave()
    }

    func deleteWithHistory(_ tracker: Tracker) {
        for entry in entries where entry.trackerID == tracker.id {
            apply(-1, to: entry)
            recordDeletion(of: entry.id)
        }
        entries.removeAll { $0.trackerID == tracker.id }
        forgetUndo(of: tracker.id)
        delete(tracker)
    }

    /// Drops one tracker's entries out of whatever undo is pending.
    ///
    /// Only this tracker's: dropping the whole slot threw away a pending undo for a
    /// different tracker the deletion never touched. A repeat that lost only *some* of
    /// its members drops out whole rather than shrinking — its two numbers describe
    /// one moment, "you tapped a row of three and I wrote two of them", and there is
    /// no honest way to restate that once a deletion has taken one of them away.
    private func forgetUndo(of tracker: UUID) {
        func surviving(_ entries: [Entry]) -> [Entry] {
            entries.filter { $0.trackerID != tracker }
        }
        switch lastWrite {
        case .deleted(let entries):
            let remaining = surviving(entries)
            lastWrite = remaining.isEmpty ? nil : .deleted(remaining)
        case .logged(let entries, _):
            if surviving(entries).count != entries.count { lastWrite = nil }
        case .none:
            break
        }
    }

    /// The trackers a drop would carry: the dragged one alone inside its own block,
    /// its whole block across a boundary. Settings shows this while the finger is
    /// still down, so the rule lives here rather than in the screen that draws it.
    func trackersCarried(moving sourceID: UUID, onto targetID: UUID) -> [UUID] {
        let runs = activeTrackerRuns
        guard let (source, target) = runIndices(runs, from: sourceID, to: targetID) else { return [] }
        return source == target ? [sourceID] : runs[source].map(\.id)
    }

    private func runIndices(_ runs: [[Tracker]], from sourceID: UUID, to targetID: UUID) -> (Int, Int)? {
        guard sourceID != targetID,
              let source = runs.firstIndex(where: { run in
                  run.contains { $0.id == sourceID }
              }),
              let target = runs.firstIndex(where: { run in
                  run.contains { $0.id == targetID }
              }) else { return nil }
        return (source, target)
    }

    /// Drops one visible tracker onto another. Within a block, the tracker moves to
    /// the target's position; across blocks its entire source block moves there —
    /// position never changes membership or splits a named group.
    func move(_ sourceID: UUID, onto targetID: UUID) {
        let runs = activeTrackerRuns
        guard let (sourceRun, targetRun) = runIndices(runs, from: sourceID, to: targetID) else { return }

        if sourceRun == targetRun {
            var run = runs[sourceRun]
            guard let source = run.firstIndex(where: { $0.id == sourceID }),
                  let target = run.firstIndex(where: { $0.id == targetID }) else { return }
            let tracker = run.remove(at: source)
            // The original target index means "before" while moving upward
            // and "after" while moving downward, matching a row dragged onto
            // another row without needing a hidden drop zone at either edge.
            run.insert(tracker, at: target)
            reorder(run)
        } else {
            var orderedRuns = runs
            let moved = orderedRuns.remove(at: sourceRun)
            guard let target = orderedRuns.firstIndex(where: { run in
                run.contains { $0.id == targetID }
            }) else { return }
            let insertion = sourceRun < targetRun ? target + 1 : target
            orderedRuns.insert(moved, at: insertion)
            reorderRuns(orderedRuns)
        }
    }

    /// Puts these trackers in this order without changing their membership, which
    /// changes only through `update`. Trackers not in `ordered` — the archived ones,
    /// normally — keep the slots they already occupied.
    func reorder(_ ordered: [Tracker]) {
        let ids = Set(ordered.map(\.id))
        let slots = trackers.indices.filter { ids.contains(trackers[$0].id) }
        let previous = Dictionary(trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard slots.count == ordered.count,
              ids.count == ordered.count,
              ordered.allSatisfy({ previous[$0.id] != nil }) else { return }

        // A drop back where it started expresses no new position. In
        // particular, it must not acquire a fresh `orderModified` and outrank
        // a real reorder made on another device.
        let currentIDs = slots.map { trackers[$0].id }
        guard currentIDs != ordered.map(\.id) else { return }

        var updated = trackers
        for (slot, tracker) in zip(slots, ordered) {
            // The row value identifies what moved; content always comes from the
            // store, so a stale or hand-built caller cannot smuggle other fields in.
            updated[slot] = previous[tracker.id] ?? updated[slot]
        }
        commitReorder(updated)
    }

    /// Reorders every stored tracker. Group moves use this so members hidden by
    /// archiving travel with their group and cannot re-anchor it elsewhere when
    /// they are later restored.
    private func reorderAll(_ ordered: [Tracker]) {
        let previous = Dictionary(trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard ordered.count == trackers.count,
              Set(ordered.map(\.id)).count == trackers.count,
              ordered.allSatisfy({ previous[$0.id] != nil }) else { return }
        let updated = ordered.compactMap { previous[$0.id] }
        commitReorder(updated)
    }

    /// Applies the order of the blocks the two screens display to the complete stored
    /// list. Named groups are gathered with archived members included; blocks that are
    /// entirely archived keep their slot, not taking part in active ordering at all.
    private func reorderRuns(_ orderedRuns: [[Tracker]]) {
        var seenGroups: Set<String> = []
        let blocks = trackers.compactMap { tracker -> [Tracker]? in
            guard !tracker.group.isEmpty else { return [tracker] }
            guard seenGroups.insert(tracker.group).inserted else { return nil }
            return trackers.filter { $0.group == tracker.group }
        }
        let activeSlots = blocks.indices.filter { block in
            blocks[block].contains { !$0.isArchived }
        }
        let orderedBlocks = orderedRuns.compactMap { run -> [Tracker]? in
            guard let id = run.first?.id else { return nil }
            return blocks.first { block in block.contains { $0.id == id } }
        }
        guard activeSlots.count == orderedBlocks.count else { return }

        var updatedBlocks = blocks
        for (slot, block) in zip(activeSlots, orderedBlocks) {
            updatedBlocks[slot] = block
        }
        reorderAll(updatedBlocks.flatMap { $0 })
    }

    private func commitReorder(_ order: [Tracker]) {
        guard order.map(\.id) != trackers.map(\.id) else { return }
        var updated = order
        for index in updated.indices { updated[index].sortIndex = index }

        // A drag stamps ordering only. None of these records were edited, so
        // `modified` must stay put and a reorder cannot outrank a rename made on
        // another device.
        let now = Date.stamp()
        for index in updated.indices {
            // Every row, not just the ones whose number changed. Stamping only the
            // rows that moved leaves the rest carrying an older stamp, so merging two
            // devices that each reordered would take some rows from one and some from
            // the other, landing on duplicate indices and an order neither chose.
            updated[index].orderModified = now
        }
        trackers = updated
        scheduleSave()
    }

    // MARK: - Export and import

    enum ImportMode: String, CaseIterable, Sendable {
        /// Converge by id. Distinct records survive; a deletion recorded in
        /// either document stays deleted, and newer edits win conflicts.
        case merge
        case replace
    }

    struct ImportSummary: Equatable, Sendable {
        var trackersAdded: Int
        var trackersRemoved: Int
        var entriesAdded: Int
        var entriesRemoved: Int
        /// Whether a recoverable copy of the previous document was actually kept, so
        /// the alert cannot promise a safety net that does not exist: an import that
        /// changed nothing never takes the slot.
        var keptBackup: Bool = false
    }

    func exportData() throws -> Data {
        try StoreCoding.encode(document)
    }

    func exportCSV() -> Data {
        CSVExport.data(document: document)
    }

    var hasImportBackup: Bool { file.hasImportBackup }

    /// Whether the document a destructive action is about to put in the recovery slot
    /// could actually come back out of it.
    ///
    /// **Loading is deliberately tolerant and restoring is not.** `StoreFile.load`
    /// validates nothing, so a hand-edited `store.json` with a duplicate id or
    /// `decimals` outside 0…3 opens fine — and `restoreImportBackup` runs
    /// `validateImport` and refuses it, which would make a clear irreversible under a
    /// dialog that had just said it was not. So both destructive confirmations ask
    /// this first and say the other thing when the answer is no. No document this app
    /// can produce fails it.
    var currentDocumentIsRestorable: Bool {
        (try? validateImport(document)) != nil
    }

    /// Takes a document in, and does not report success until the result is the
    /// document on disk.
    ///
    /// Async because an import is the one action a user takes and then immediately
    /// quits: leaving it to the save debounce meant a force-quit inside that window
    /// silently discarded an import the app had already announced as complete.
    /// Draining the queue first also stops a write scheduled for the pre-import
    /// document from landing on top of the imported one.
    @discardableResult
    func importData(_ data: Data, mode: ImportMode) async throws -> ImportSummary {
        let incoming = try StoreMigration.migrate(data)
        try validateImport(incoming)
        try validateImportedNames(incoming)
        return try await applyIncoming(incoming, mode: mode)
    }

    /// Removes every tracker and entry, keeping what was here as the recoverable copy.
    ///
    /// **It is a replacing import with an empty argument**, and it runs through
    /// `applyIncoming(_:mode:)` rather than reimplementing it (docs/TODO.md item 24).
    /// Confirmations are a poor defence because people learn to tap through them; what
    /// makes this safe is the pre-clear copy, and the code that writes one correctly
    /// already exists. A second implementation of that sequence is a second place for
    /// the safety net to be quietly wrong, and nothing about it would look wrong.
    ///
    /// **No tombstones are written for what goes**, which is `replace`'s meaning
    /// inherited: the document afterwards is the argument, so merging an older export
    /// brings the data back. A tombstone per record would leave "start over" holding
    /// 29,756 deletions for six months (docs/scale.md).
    @discardableResult
    func clearAll() async throws -> ImportSummary {
        let summary = try await applyIncoming(StoreDocument(), mode: .replace)
        // The rolling save backup still holds the whole pre-clear document, and `load`
        // reads it whenever the main file will not decode — a second copy nobody was
        // told about, of the data somebody has just asked to be rid of. The disclosed
        // recovery slot is the copy a clear keeps; this one goes.
        file.discardSaveBackup()
        return summary
    }

    /// The transaction both of the above are: flush, decide, keep a copy, write, swap
    /// memory. It takes a validated document, not bytes: `validateImport` is about what
    /// a *foreign* file has to satisfy, and the empty document a clear builds is not
    /// one.
    private func applyIncoming(_ incoming: StoreDocument, mode: ImportMode) async throws -> ImportSummary {
        while true {
            let before = document
            let startingRevision = revision
            await saver.flush(before, revision: startingRevision)
            if let error = await saver.lastError {
                saveError = Self.describe(error)
                throw error
            }

            // Main-actor methods are reentrant at `await`. Anything that changed while
            // the saver drained has to be part of what gets merged and backed up, so
            // start again rather than importing onto a stale snapshot.
            guard revision == startingRevision else { continue }

            let result = switch mode {
            case .merge: before.merged(with: incoming)
            case .replace: incoming.compactingTombstones()
            }
            // Both modes get a recoverable copy of what they are about to change. A
            // merge too, even though it reads as the additive choice: the document it
            // takes in carries tombstones, so an old export — or someone else's — can
            // delete entries that exist here and nowhere in the file.
            //
            // An import that changes nothing does not advance the slot. The slot holds
            // one document, and spending it there would mean re-merging a file you
            // already have could burn the recovery point for the replace that needed
            // it.
            let changesSomething = !Self.sameDocument(result, before)
            // Staged, not written into the slot. Overwriting the slot is itself
            // destructive, so doing it before the write below meant a failure there —
            // a full disk — left the user with neither document.
            if changesSomething { try file.stageImportBackup(before) }
            do {
                // Before memory, so a failure here leaves the app exactly as it
                // was rather than holding a document that never reached disk.
                try file.write(result)
            } catch {
                file.discardStagedImportBackup()
                throw error
            }
            // Only now, with the import durable, is the old document safe to give up.
            // If this cannot be done the import still stands and the summary says the
            // safety net did not advance.
            let keptBackup = changesSomething && file.commitStagedImportBackup()
            replaceState(with: result, saving: false)
            revision += 1
            saveError = nil
            return importSummary(before: before, after: result, keptBackup: keptBackup)
        }
    }

    /// Restores the document saved before the last import, leaving the current
    /// document in that recovery slot. Async because every delayed save must finish
    /// before the two files are swapped, or an older queued write lands after it.
    @discardableResult
    func restoreImportBackup() async throws -> ImportSummary {
        while true {
            let incoming = try StoreMigration.migrate(file.importBackupData())
            try validateImport(incoming)
            // The filesystem swap installs the recovery file's bytes as the live
            // document, so memory is kept exact too. The two are the same document but
            // not always the same bytes: a recovery file from an older schema is
            // migrated in memory while the file stays at its own version until the next
            // ordinary save. That converges, because the step is deterministic.
            let result = incoming

            let before = document
            let startingRevision = revision
            await saver.flush(before, revision: startingRevision)
            if let error = await saver.lastError {
                saveError = Self.describe(error)
                throw error
            }

            // Reentrant at `await` as above: if anything changed while the saver
            // drained, start again rather than swapping a stale snapshot.
            guard revision == startingRevision else { continue }

            // `revision == 0` can mean the saver has never written this Store
            // instance. Put its exact current document in the live slot first;
            // failure leaves the recovery document untouched.
            try file.write(before)
            try file.swapWithImportBackup()
            replaceState(with: result, saving: false)
            revision += 1
            saveError = nil
            // Always true here: the swap put the document being replaced into the
            // recovery slot, which is what makes a mistaken restore reversible.
            return importSummary(before: before, after: result, keptBackup: true)
        }
    }

    /// What a *foreign* file has to satisfy, and nothing else does.
    ///
    /// Nothing in the app can produce a blank tracker name — `TrackerEditor` trims and
    /// refuses one. A hand-edited or foreign file can, and it draws a blank card on
    /// home, a blank row in settings and a blank identity line in History. Refused
    /// rather than repaired: a repair rewrites a record the user did not edit, stamps
    /// it as an edit, and the merge carries that invented name to every other device.
    ///
    /// **Separate from `validateImport` because the restore path must not run it.**
    /// That document was written by this app from its own memory, and refusing it over
    /// a merely blank row would disable the one action that undoes a destructive
    /// import.
    private func validateImportedNames(_ document: StoreDocument) throws {
        for tracker in document.trackers {
            guard !tracker.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StoreError.invalidDocument(
                    "tracker \(tracker.id.uuidString) has an empty name."
                )
            }
        }
    }

    /// Import has to be idempotent. A decodable document containing duplicate live
    /// ids, duplicate tombstones, or a record that is simultaneously live and deleted
    /// changes meaning after the next merge and can double-count totals or duplicate
    /// SwiftUI identity. Loading stays tolerant of old bad local files; crossing the
    /// explicit import boundary does not.
    ///
    /// Run by the restore path too, which is why a check that is only about how a row
    /// *reads* lives in `validateImportedNames` instead.
    private func validateImport(_ document: StoreDocument) throws {
        var live = Set<UUID>()
        for id in document.trackers.map(\.id) + document.entries.map(\.id) {
            guard live.insert(id).inserted else {
                throw StoreError.invalidDocument("record id \(id.uuidString) appears more than once.")
            }
        }
        var deleted = Set<UUID>()
        for tombstone in document.tombstones {
            guard deleted.insert(tombstone.id).inserted else {
                throw StoreError.invalidDocument(
                    "deletion id \(tombstone.id.uuidString) appears more than once."
                )
            }
            guard !live.contains(tombstone.id) else {
                throw StoreError.invalidDocument(
                    "id \(tombstone.id.uuidString) is both present and deleted."
                )
            }
        }
        for tracker in document.trackers {
            guard (0...3).contains(tracker.decimals) else {
                throw StoreError.invalidDocument(
                    "tracker \(tracker.id.uuidString) has decimals outside 0 through 3."
                )
            }
            guard tracker.sortIndex >= 0, tracker.sortIndex < Int.max else {
                throw StoreError.invalidDocument(
                    "tracker \(tracker.id.uuidString) has an invalid sort index."
                )
            }
        }
    }

    /// What the import did, in the terms the user was warned about. Trackers are
    /// counted in both directions like entries are: a replace that wiped two trackers
    /// and added none used to report "Added 0 trackers and 0 entries. Removed 0
    /// entries" — a true sentence about entries and a silence about the trackers.
    private func importSummary(
        before: StoreDocument,
        after result: StoreDocument,
        keptBackup: Bool
    ) -> ImportSummary {
        let oldTrackers = Set(before.trackers.map(\.id))
        let newTrackers = Set(result.trackers.map(\.id))
        let oldEntries = Set(before.entries.map(\.id))
        let newEntries = Set(result.entries.map(\.id))
        return ImportSummary(
            trackersAdded: newTrackers.subtracting(oldTrackers).count,
            trackersRemoved: oldTrackers.subtracting(newTrackers).count,
            entriesAdded: newEntries.subtracting(oldEntries).count,
            entriesRemoved: oldEntries.subtracting(newEntries).count,
            keptBackup: keptBackup
        )
    }

    /// Whether two documents say the same thing, whatever order they say it in.
    ///
    /// Plain `==` is not that: `merged(with:)` rebuilds tombstones sorted by
    /// `(deleted, id)` while the live store appends them as deletions happen, and
    /// `Date.stamp()` rounds to whole seconds — so two deletions inside one second
    /// land in deletion order here and id order there. Re-merging a file you already
    /// have then compared unequal about half the time, purely on tombstone order, and
    /// burned the recovery slot this check exists to protect.
    private static func sameDocument(_ one: StoreDocument, _ other: StoreDocument) -> Bool {
        func ordered(_ document: StoreDocument) -> StoreDocument {
            var copy = document
            copy.tombstones.sort { ($0.deleted, $0.id) < ($1.deleted, $1.id) }
            return copy
        }
        return ordered(one) == ordered(other)
    }

    private func replaceState(with document: StoreDocument, saving: Bool = true) {
        trackers = document.trackers.sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
        entries = StoreDocument.sorted(document.entries)
        tombstones = document.tombstones
        // Import is a new whole-document decision. An undo captured from the document
        // it replaced must never inject old entries into it, duplicate an id the
        // imported file already restored, or delete an entry the file brought in that
        // happens to share an id with one a repeat wrote a moment ago.
        lastWrite = nil
        rebuildTotals()
        if saving { scheduleSave() }
    }

    // MARK: - The day boundary

    /// Re-reads the clock, and the calendar if the device's has changed. Called on
    /// every mutation and whenever the system reports a significant time change, which
    /// covers midnight rolling over while the app sits open and stepping off a plane
    /// into a new time zone.
    func refreshToday() {
        if followsSystemCalendar {
            let current = Calendar.current
            if current.timeZone != calendar.timeZone || current.identifier != calendar.identifier {
                calendar = current
                rebuildTotals()
            }
        }
        let day = dayKey(now)
        if day != today {
            today = day
            scheduleDayRoll()
        }
    }

    /// Wakes the app when the day rolls at an hour the system says nothing about.
    ///
    /// **`significantTimeChangeNotification` fires at midnight**, which is exactly
    /// where the boundary used to be — so the moment the day start is moved to 4am,
    /// nothing announces the roll any more. Left open overnight with a 4am start, the
    /// home screen went on showing yesterday's total under today's heading.
    ///
    /// One sleeping task, replaced only when the moment it is waiting for moves:
    /// `refreshToday` runs on every mutation, so rescheduling unconditionally would
    /// spawn a task per logged number. Nothing at midnight, where the notification
    /// already does this, and nothing under a pinned clock, where a live timer would
    /// be a test holding a task open against a `now` that never advances.
    private func scheduleDayRoll() {
        guard dayStartHour != DayStart.midnight, pinnedNow == nil else {
            dayRollTask?.cancel()
            dayRollTask = nil
            dayRollAt = nil
            return
        }
        let next = today
            .adding(days: 1, calendar: calendar)
            .startOfDay(calendar: calendar, dayStartHour: dayStartHour)
        guard next != dayRollAt else { return }
        dayRollAt = next
        dayRollTask?.cancel()
        let delay = next.timeIntervalSince(now)
        dayRollTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            self?.refreshToday()
        }
    }

    /// Moves the store to another calendar, as if the device had been carried
    /// there. Every day-keyed total has to be recomputed, because which day an
    /// entry belongs to is derived, never stored.
    func travel(to calendar: Calendar) {
        self.calendar = calendar
        rebuildTotals()
        // The boundary is a wall-clock hour, so stepping off a plane moves it.
        dayRollAt = nil
        scheduleDayRoll()
        let day = dayKey(now)
        if day != today { today = day }
    }

    private func watchForTimeChanges() {
        #if canImport(UIKit)
        timeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // `queue: .main` guarantees the main thread, which is the main
            // actor — the one place `assumeIsolated` is the honest answer.
            MainActor.assumeIsolated { self?.refreshToday() }
        }
        #endif
    }

    // MARK: - The totals index

    /// Rebuilt from scratch whenever the day mapping itself could have changed, and
    /// at launch, which resets any drift the incremental updates accumulated.
    func rebuildTotals() {
        var result: [DayTotal: Double] = [:]
        var counts: [DayTotal: Int] = [:]
        result.reserveCapacity(entries.count / 4)
        for entry in entries {
            let key = DayTotal(tracker: entry.trackerID, day: dayKey(entry.date))
            result[key, default: 0] += entry.value
            counts[key, default: 0] += 1
        }
        totals = result
        entryCounts = counts
    }

    /// Adds or removes one entry's contribution. The count is what says whether a day
    /// still has anything in it: deciding that from the sum alone is wrong twice over,
    /// because a day can legitimately add up to zero, and repeated addition and
    /// subtraction of decimals leaves a residue that would never compare equal to it.
    private func apply(_ sign: Double, to entry: Entry) {
        let key = DayTotal(tracker: entry.trackerID, day: dayKey(entry.date))
        let count = (entryCounts[key] ?? 0) + Int(sign)
        guard count > 0 else {
            entryCounts[key] = nil
            totals[key] = nil
            return
        }
        entryCounts[key] = count
        totals[key] = (totals[key] ?? 0) + sign * entry.value
    }

    private func insertSorted(_ entry: Entry) {
        // Scans back from the end because the overwhelmingly common case is
        // logging something now, which belongs at the end. Backdating a week
        // costs a walk over that week.
        var index = entries.count
        while index > 0, (entries[index - 1].date, entries[index - 1].id) > (entry.date, entry.id) {
            index -= 1
        }
        entries.insert(entry, at: index)
    }

    private func recordDeletion(of id: UUID) {
        let now = Date.stamp()
        if let index = tombstones.firstIndex(where: { $0.id == id }) {
            tombstones[index].deleted = max(tombstones[index].deleted, now)
        } else {
            tombstones.append(Tombstone(id: id, deleted: now))
        }
    }
}

// MARK: - What one log covers

/// The trackers one trip through the log sheet writes to: a group when the trackers
/// are logged together — calories and protein from the same meal — and a single
/// tracker when it isn't in one. Being in no group is *not* a group: your cigarettes
/// and your pushups share nothing but the absence of a name.
///
/// Nothing about this is stored. It is computed from `Tracker.group` at read time,
/// which makes it a displayed decision (docs/TECH.md) — it can be reworked after a
/// week of real use with nothing to convert. The one exception is the string form
/// below.
enum LogGroup: Hashable, Sendable {
    /// Never empty — an empty group string is the ungrouped case.
    case group(String)
    case tracker(UUID)

    init(of tracker: Tracker) {
        self = tracker.group.isEmpty ? .tracker(tracker.id) : .group(tracker.group)
    }
}

extension LogGroup: RawRepresentable {

    /// A string, because the last-used group lives in `UserDefaults` and that is what
    /// fits there. Prefixed so a group named like a UUID cannot be read back as a
    /// tracker; a string that no longer resolves just means + opens the first group.
    init?(rawValue: String) {
        if let name = rawValue.dropPrefix("group:") {
            guard !name.isEmpty else { return nil }
            self = .group(name)
        } else if let id = rawValue.dropPrefix("tracker:").flatMap(UUID.init(uuidString:)) {
            self = .tracker(id)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .group(let name): "group:\(name)"
        case .tracker(let id): "tracker:\(id.uuidString)"
        }
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
