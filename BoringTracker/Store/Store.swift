import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The whole state of the app, and the only thing that mutates it.
///
/// Views read this from the environment. There is no repository, no view model
/// per screen, no coordinator — SwiftUI already observes state, and a layer
/// that helps it observe state is the kind of thing this app exists to avoid.
@Observable
@MainActor
final class Store {

    private(set) var trackers: [Tracker]
    /// Oldest first. Every screen wants chronological order.
    private(set) var entries: [Entry]
    private(set) var tombstones: [Tombstone]

    /// Today, in the calendar the user is currently living in. Stored rather
    /// than computed so that SwiftUI redraws when the day rolls over.
    private(set) var today: DayKey
    /// How the document was loaded. `.backup` and `.unreadable` are worth
    /// telling the user about; the rest is uneventful.
    private(set) var origin: StoreOrigin
    /// Set when a save fails, so the app can say so instead of pretending.
    private(set) var saveError: String?
    /// The last write that can still be taken back, and there is only ever one
    /// of it.
    ///
    /// Deleting a row and logging one again are both undoable, and History
    /// offers both through the same Undo button. With two live slots that one
    /// button would have two meanings and no way to say which it meant, and two
    /// buttons is more screen than either case deserves. So the newer write
    /// takes the slot and the older one stops being offered — which is exactly
    /// what a second deletion already did to the first.
    ///
    /// **A newer write also ends a pending repeat's offer, and only a repeat's**
    /// — see `forgetRepeatUndo`. Undoing a repeat removes entries, so an offer
    /// that outlives the write it describes destroys data; undoing a deletion
    /// only puts records back, so it can go stale harmlessly.
    private enum LastWrite {
        /// Everything one deletion removed, newest first.
        case deleted([Entry])
        /// What one repeat wrote, and how many members of the row it had to
        /// leave out because their tracker is gone or archived. The count is
        /// kept because only the moment of the tap knows it: afterwards the
        /// entries that were written look like any other batch.
        case logged(entries: [Entry], skipped: Int)
    }

    private var lastWrite: LastWrite?

    /// The newest member of what was deleted most recently. Detail uses this
    /// to decide whether its undo row belongs on screen; the complete deletion
    /// is kept separately so one history-row delete can restore a whole batch.
    var lastDeletion: Entry? { lastDeletedEntries.first }
    var lastDeletionCount: Int { lastDeletedEntries.count }

    private var lastDeletedEntries: [Entry] {
        if case .deleted(let entries) = lastWrite { entries } else { [] }
    }

    /// What one repeat wrote, when a repeat is the thing waiting to be undone.
    struct LoggedAgain: Equatable, Sendable {
        /// Entries written. Never zero: a repeat that can write nothing does
        /// not happen and does not take the slot.
        var count: Int
        /// Members of the row left out because a repeat may not write them:
        /// their tracker has been deleted or archived, or it is a measurement
        /// and a copy would be a reading nobody took (docs/TODO.md item 23).
        /// The measurement is the common one — a weigh-in batch with both
        /// trackers live and unarchived still skips its weight — so a hunt for
        /// a deleted tracker is the wrong place to start. The screen says so
        /// rather than writing part of a row under a button that promised the
        /// whole of it.
        var skipped: Int
    }

    var lastLoggedAgain: LoggedAgain? {
        guard case .logged(let entries, let skipped) = lastWrite else { return nil }
        return LoggedAgain(count: entries.count, skipped: skipped)
    }

    /// Which history row the last repeat wrote, so History can point at the new
    /// one (docs/TODO.md item 20).
    ///
    /// Beside `lastLoggedAgain` rather than inside it: the bar wants to know
    /// how much was written, this wants to know where, and a row id folded into
    /// that struct would have to be named by every test that asserts a count.
    /// Both read the one slot, so they are never out of step.
    ///
    /// **Two repeats of the same food give two different values here**, because
    /// every write gets a fresh batch id — which is what lets a screen watch
    /// this for changes and see the second tap. A count would be equal across
    /// both, and the second tap would look like nothing having happened.
    var lastLoggedAgainRow: HistoryItem.ID? {
        guard case .logged(let entries, _) = lastWrite, let written = entries.first else {
            return nil
        }
        // Every repeat writes through `addBatch`, which stamps a batch id on
        // every member including a lone one — so this is `.batch` in practice,
        // and the other case is here because `HistoryItem` has it rather than
        // because a path reaches it.
        return written.batchID.map(HistoryItem.ID.batch) ?? .entry(written.id)
    }

    /// When that row was written, for a screen that wants to know whether the
    /// repeat is seconds old or an hour old.
    ///
    /// A repeat's offer stands until something newer is written, so "there is a
    /// repeat to undo" says nothing about *when*. Read off the entries the write
    /// made rather than stamped separately: they carry the moment already, and a
    /// second timestamp is a second thing to keep in step.
    ///
    /// Here rather than in the screen that asks. History had this by finding the
    /// row in `historyItems` and reading its date, which walks and sorts every
    /// entry ever logged — a second full build, on a screen that already pays
    /// for one, every time it opens while an offer stands.
    var lastLoggedAgainAt: Date? {
        guard case .logged(let entries, _) = lastWrite else { return nil }
        return entries.first?.date
    }

    /// The newest thing the last deletion took from this tracker, if it took
    /// anything. Undo restores the whole deletion either way; a tracker's own
    /// screen asks this rather than reading `lastDeletion`, because the newest
    /// member of a deleted batch belongs to only one of the trackers involved
    /// and the other one had just as much taken from it.
    func lastDeletion(for tracker: UUID) -> Entry? {
        lastDeletedEntries.first { $0.trackerID == tracker }
    }

    /// One derived index: the sum of every daily-total tracker, per local day.
    /// It backs both the home screen number and the graph, so nothing has to
    /// scan the entry list to draw.
    private(set) var totals: [DayTotal: Double] = [:]
    /// How many entries back each total, so an emptied day drops out of the
    /// index instead of lingering as a zero.
    private var entryCounts: [DayTotal: Int] = [:]

    struct DayTotal: Hashable {
        var tracker: UUID
        var day: DayKey
    }

    private(set) var calendar: Calendar
    /// The hour the day is cut at. Midnight unless somebody has moved it — see
    /// `DayStart`, which is also where the reversal of TECH.md's "no
    /// configurable day start" is argued.
    ///
    /// Read by everything that derives a day and stored by nothing, so changing
    /// it is a rebuild rather than a migration.
    private(set) var dayStartHour: Int
    /// False when a test pinned the calendar, so system time-zone changes do
    /// not yank it back to the device's.
    private let followsSystemCalendar: Bool
    /// The clock, pinned by tests. `nil` in the app, where the device's clock is
    /// the only honest answer.
    ///
    /// Here for the same reason `calendar` is injectable: a store's idea of
    /// today decides which day a `DayKey` falls in and what a row's date is
    /// labelled, so a fixture's dates and "now" are not independent, and a test
    /// reading against the wall clock is one that passes today and fails in
    /// March. It arrived for `repeatItems`' 60-day counting window
    /// (docs/TODO.md item 16c) and outlived it — the window is gone with item
    /// 29, the day boundary and DST tests are what pin the clock now.
    ///
    /// **It pins which day the store thinks it is, not what a write stamps.**
    /// `today`, `refreshToday()` and `travel(to:)` read it; `add`, `addBatch`,
    /// `logAgain` and every `modified` stamp still read `Date.stamp()`. So in a
    /// store with this pinned, a write lands at the real wall clock rather than
    /// the pinned one, and therefore under a `DayKey` the store does not
    /// consider today. Deliberately not threaded further: this exists so an
    /// ordering test can sit at a known distance from its fixture, and running
    /// the eight timestamps a mutation writes off a test-only clock is a change
    /// to the data path to buy nothing the data path needs. A test that pins
    /// this and then asserts a *total* or a day label wants the real fix first.
    private let pinnedNow: Date?
    private var now: Date { pinnedNow ?? Date() }
    private let file: StoreFile
    private let saver: StoreSaver
    /// Counts mutations. The saver uses it to tell a late-arriving old document
    /// from the current one, and the graph uses it to know when its aggregated
    /// points are stale without watching every array.
    private(set) var revision: UInt64 = 0
    private var timeObserver: (any NSObjectProtocol)?
    /// The sleeping task that rolls the day when the boundary is not midnight,
    /// and the moment it is waiting for. See `scheduleDayRoll`.
    private var dayRollTask: Task<Void, Never>?
    private var dayRollAt: Date?

    // MARK: - Life cycle

    /// Loads synchronously. The file is small, and doing this asynchronously
    /// would flash an empty home screen for longer than the decode takes.
    convenience init(file: StoreFile = .standard()) {
        let loaded = file.load()
        // **The one place `UserDefaults` is read**, and it is the app's
        // entry point rather than the designated init below. Reading it there
        // instead made every `Store` a test builds inherit whatever the last
        // test to call `setDayStartHour` had written — in the same process, in
        // parallel, and on a simulator across runs — so one day-boundary test
        // could move another suite's midnight. Nothing under test now reads the
        // key at all.
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

    /// The document as it would be written or exported. Assembled on demand —
    /// there is no second copy of the state to keep in step.
    var document: StoreDocument {
        StoreDocument(
            schemaVersion: StoreDocument.currentSchemaVersion,
            trackers: trackers,
            entries: entries,
            tombstones: tombstones
        )
    }

    /// Writes anything outstanding and waits. Called when the scene stops being
    /// active.
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
            // Then wait for it, and read back whether it worked. `save`
            // returns as soon as the document is queued, so without
            // `settled()` this task ended before the write it asked for and
            // `saveError` only ever moved on `flush` — which is the scene
            // going inactive. A disk that has stopped accepting writes was
            // therefore silent for as long as the app stayed open, while the
            // notice row that exists to say so sat empty.
            await saver.settled()
            let message = await saver.lastError.map(Self.describe)
            // Only on a change. `@Observable` publishes every set whether or
            // not the value moved, and there is one of these tasks per
            // mutation — fifty in a burst, all waiting on the same write and
            // all reading the same nil. Assigning unconditionally would
            // invalidate home's notice row fifty times for nothing.
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
    /// Derived every time rather than stored, because there is no list of
    /// groups anywhere — a group is a string on a tracker (docs/PRODUCT.md),
    /// so this cannot go stale, leave an empty group behind, or orphan one.
    /// Archived trackers count: their group should still be offered rather
    /// than reappearing as a new one the moment something is unarchived.
    var groups: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tracker in trackers where !tracker.group.isEmpty {
            if seen.insert(tracker.group).inserted { result.append(tracker.group) }
        }
        return result
    }

    /// The active trackers in one group, in the order they are drawn — which
    /// is the order their fields appear in the log sheet.
    func trackers(inGroup group: String) -> [Tracker] {
        trackers.filter { !$0.isArchived && $0.group == group }
    }

    /// Everything you can log in one go, in the order the home screen draws it:
    /// each group once, and every ungrouped tracker on its own.
    ///
    /// This is the list the log sheet switches between. The list belongs
    /// *behind* the sheet, never in front of it (docs/PRODUCT.md).
    var logGroups: [LogGroup] {
        var seen = Set<String>()
        var result: [LogGroup] = []
        for tracker in trackers where !tracker.isArchived {
            let group = LogGroup(of: tracker)
            if seen.insert(group.rawValue).inserted { result.append(group) }
        }
        return result
    }

    /// The blocks both home and settings draw: one named group gathered at its
    /// first active tracker, and one block for each loose tracker. Keeping the
    /// shape here means the two screens cannot disagree about what an order
    /// means.
    var activeTrackerRuns: [[Tracker]] {
        logGroups.map(trackers(in:))
    }

    /// The trackers one log writes to: a group's, or the single ungrouped
    /// tracker, in the order they are drawn.
    func trackers(in group: LogGroup) -> [Tracker] {
        switch group {
        case .group(let name): trackers(inGroup: name)
        case .tracker(let id): tracker(id).map { $0.isArchived ? [] : [$0] } ?? []
        }
    }

    /// What tapping + opens: what you logged last, or the first thing on the
    /// home screen if that is gone — archived, deleted, or moved into a group.
    ///
    /// Takes the remembered group as the plain string it is stored as, because
    /// what comes back out of `UserDefaults` is exactly that, and deciding
    /// whether it still means anything is this method's job. `nil` when there is
    /// nothing to log at all. Never a picker: choosing what to log is a tap on
    /// the common path, and the common path is the product (docs/PRODUCT.md).
    func groupToLog(preferring remembered: String) -> LogGroup? {
        let available = logGroups
        if let group = LogGroup(rawValue: remembered), available.contains(group) {
            return group
        }
        return available.first
    }

    /// The daily total, straight out of the index.
    func total(for tracker: UUID, on day: DayKey) -> Double {
        totals[DayTotal(tracker: tracker, day: day)] ?? 0
    }

    /// The most recent reading, for measurement trackers.
    ///
    /// A reverse scan rather than a second index: entries are already sorted,
    /// so this stops at the first match, and even the worst case — a tracker
    /// with no entries at all — is a few thousand comparisons.
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

    /// Moves where the day is cut, and re-derives everything that depended on
    /// it. Persists, because this is the app's own setting rather than a value
    /// a caller owns; tests inject through `init` and never come here.
    func setDayStartHour(_ hour: Int) {
        let hour = DayStart.hour(hour)
        guard hour != dayStartHour else { return }
        dayStartHour = hour
        UserDefaults.standard.set(hour, forKey: DayStart.key)
        // Both, and in this order: the totals index is keyed by day, so it is
        // stale the instant the offset moves, and `today` may now be yesterday.
        rebuildTotals()
        refreshToday()
        // `refreshToday` only reschedules when the day actually changed, and
        // moving the boundary from 4am to 6am on an afternoon changes the next
        // roll without changing today.
        scheduleDayRoll()
        // No `revision += 1`. Nothing in the document changed, and that counter
        // is what tells the saver a late write is stale. What it was reached
        // for — the graph noticing its buckets moved — belongs in the graph's
        // own staleness key, which now carries the hour (`TrackerChart.Key`).
    }

    /// Every row in the complete history, newest first. `batchID` is consumed
    /// here rather than inferred from matching times or names: those fields are
    /// editable, while the id is the stored statement that the values were one
    /// log. Entries without one are deliberately rows of their own.
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
        // The date decides almost every comparison, and `sortID` builds a string
        // each time it is read — so comparing the pair outright spent 65ms of
        // this method's 76ms on five years of data (iPhone 17 simulator, 15,000
        // entries, 7,500 rows; an old iPhone is several times slower). Reaching
        // for the id only when two rows share a second is the same order in 33ms.
        // This runs on every redraw of the History screen, so it is worth the
        // two lines.
        return items.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.sortID > rhs.sortID
        }
    }

    /// The Repeat screen's list: one row per distinct thing you have logged to
    /// a daily total, most recently logged first.
    ///
    /// **Membership is the projection, not a filter.** Every row is cut down to
    /// the members this screen is about — present, a daily total, archived or
    /// not — and a row with nothing left drops out. The kind decides and the
    /// name decides nothing (docs/TODO.md item 21): the list holds every
    /// unnamed daily total, because 450 kcal and 30 g is a dinner you can eat
    /// again whether or not you typed a word, and holds no measurement, however
    /// carefully one was named.
    ///
    /// **Then a second cut, onto what a tap actually writes.** Membership has
    /// to keep archived members or a listed row could vanish; the row's
    /// *content* must not, or a batch logging a live total beside an archived
    /// one draws a value the tap drops. The loop below does both, in that
    /// order.
    ///
    /// **The second cut costs about 1ms, and about 2ms on twice the history.**
    /// Measured the same way as the figures below — a Debug build on the
    /// iPhone 17 simulator from a temporary test in this target, ten runs each,
    /// the two alternating in one binary behind a temporary flag, over a
    /// fixture of four named meal batches, two unnamed totals, a water and a
    /// weight a day: **21.9–23.5ms against 20.9–22.5ms over 7,644 entries and
    /// 44.6–51.3ms against 42.4–46.2ms over 15,288**, reproduced twice. At the
    /// smaller size the ranges overlap, so the honest reading there is that it
    /// is at the edge of the noise; at the larger one the gap is consistent.
    /// It buys a row that does not lie about what a tap writes.
    ///
    /// **A batch that mixes the two is listed as its daily totals.** It used to
    /// be refused whole, by a predicate that could only accept or reject a row
    /// — and refusing was right for the list even after item 23 made the tap
    /// safe, because `repeatKey` carries every value, so thirty daily weigh-ins
    /// of one breakfast keyed as thirty rows, each drawing a weight the tap
    /// would not write. Projecting first answers both: they are one row, and it
    /// shows what the tap writes. The cost is that a weigh-in breakfast now
    /// collapses onto the plain one — the right answer for "do that again", a
    /// surprise for anyone reading this list as history, which History still
    /// is.
    ///
    /// **That costs 2–3ms on a realistic history and 4–7ms on the worst one.**
    /// More rows reach the collapse and the sort; the filter itself is a
    /// dictionary lookup per entry where it used to be a name check. Measured in
    /// a Debug build on the iPhone 17 simulator from a temporary test in this
    /// target, ten runs each, the two filters **alternating in one binary** so a
    /// warm-up or a thermal drift lands on both columns — fixtures of four named
    /// meals, two unnamed totals, a water and a weight a day, ending today:
    /// **19.0–20.2ms against 17.5–19.5ms over 7,644 entries (4,368 history rows)
    /// and 38.1–40.0ms against 34.7–37.3ms over 15,288 (8,736)**. Those collapse
    /// to 7 rows and 4, so they barely exercise the sort; the shape that does is
    /// the one where every number differs — 3,822 rows against 2,184, and 7,644
    /// against 4,368 — and it reads **23.8–26.0ms against 20.2–22.6ms** and
    /// **48.3–49.4ms against 40.8–42.2ms**. Read the medians rather than the
    /// ends: 19.8 against 17.9, 39.0 against 35.8, 24.6 against 20.7 and 48.8
    /// against 41.8, so the two columns separate on every shape while their
    /// ranges still overlap on the smallest one. It is paid once when the sheet
    /// opens, on a list that is nearly twice as long.
    ///
    /// **Not comparable to the numbers further down this comment**, which were
    /// taken on fixtures without the unnamed logs. The pair to read is the two
    /// columns here.
    ///
    /// **Deduplicated by name *and* values** (`HistoryItem.RepeatKey`). The
    /// plain list was built first on purpose and using it is what settled this:
    /// item 16 recorded eight rows for "rice" with six of them the same meal at
    /// the same numbers, and a fresh fixture of the same shape gives 23 and 15.
    /// Forty logs of "chicken rice 100/10" are one row here, while "chicken
    /// rice 160/16" stays its own, because a bigger portion is a different
    /// thing to log again (docs/TODO.md item 16).
    ///
    /// **The row kept is the newest**, so its date says when you last ate that
    /// — the one fact the collapsed rows all disagreed about, and the only one
    /// worth keeping. It is a real row rather than a summary, so repeating it
    /// goes through the same `logAgain` as everything else.
    ///
    /// **Ordered most recently logged first** (docs/TODO.md item 29). Every row
    /// already carries the date of the last time you logged it — see "the row
    /// kept is the newest" above — so the list is that date, descending, and
    /// nothing else.
    ///
    /// **It replaced a 60-day frequency count with a lifetime count under it,
    /// and that order was measured and it worked.** The case for frequency was
    /// that the portion you usually eat floats to the top. The case against is
    /// that you cannot see a count: the list reordered itself on a number the
    /// screen never shows, so where a row would be next time was not something
    /// you could work out from looking at it. Chronological approximates
    /// frequency for staples anyway — if you eat something often you also ate
    /// it recently — and that was already conceded when recency was first
    /// replaced ("for someone eating the same five things the two converge").
    /// What chronological adds is predictability.
    ///
    /// **The frequency reasoning is kept rather than deleted**, because it is
    /// the first thing to try if this feels wrong in use: docs/TODO.md item 29
    /// carries it in full, and the code is `90dda62` (the 60-day window) and
    /// `6d33fe8` (the lifetime tie-break under it).
    ///
    /// **A row that cannot be written sorts below every row that can**, however
    /// recently it was logged. That rule is about what a tap can do rather than
    /// about order, so the change above leaves it exactly as it was: archiving
    /// a tracker is a supported thing to do, and a screenful of greyed rows in
    /// front of every row that still works is not a list you can log from. They
    /// stay on the list rather than disappearing, which is item 16's decision
    /// and unchanged: the row is still a true statement about what you ate, and
    /// a screen that drops food when you archive a tracker is editing your
    /// history. **An archived tracker is still a tracker**, so item 21's kind
    /// rule reads its kind and keeps these rows exactly where they were; what
    /// item 21 does drop is a row whose trackers were *deleted*, which has no
    /// kind left to qualify it and can never be written again either.
    ///
    /// **Rows tied on `canRepeat` and the date are still ordered**, by
    /// `sortID`, which is unique per row, so the list does not shuffle between
    /// openings.
    ///
    /// A filter over `historyItems` rather than its own walk of `entries`: the
    /// grouping of a batch into one row is the same question both screens ask,
    /// and it is already pinned by tests here. A second walk would be a second
    /// chance to answer it differently.
    ///
    /// One pass and a dictionary of positions, so collapsing costs a hash per
    /// row and the sort runs over the collapsed list rather than the raw one.
    /// Measured in a Debug build on the iPhone 17 simulator, five runs each,
    /// against fixtures of four named meals and a weight reading a day:
    /// **20.6–21.1ms over 7,644 entries (4,248 history rows) and 41.0–42.4ms
    /// over 15,294 (8,498)**, against 15.7–16.4ms and 31.6–36.7ms for the
    /// undeduplicated list on the same two files — so deduplication is about
    /// 5ms and 8ms of it, and the rest is `historyItems`. The worst shape is
    /// the one where nothing collapses: 15,294 entries that all differ cost
    /// **49.9–51.0ms** against a plain 32.2–32.8ms. Paid once, when the screen
    /// opens: `RepeatView` snapshots this and filters the snapshot, so a
    /// keystroke never reaches it. A keystroke got *cheaper*, because there are
    /// far fewer rows left to filter — 0.08–0.16ms against the 5.3ms and 9.9ms
    /// recorded for the plain list.
    ///
    /// **Dropping the two counts did not make it faster, and was not meant
    /// to.** Ten runs each, **alternating in one binary** so a warm-up or a
    /// thermal drift lands on both columns — the frequency order rebuilt in a
    /// temporary test in this target, a Debug build on the iPhone 17 simulator,
    /// over fixtures of four named meal batches, two unnamed totals, a water and
    /// a weight a day ending on the store's today. Medians, ranges beside them,
    /// in ms:
    ///
    ///     shape              entries   rows   chronological     frequency
    ///     collapsing           7,644      7   21.3 (20.3–22.7)  21.6 (20.8–22.9)
    ///     collapsing          15,288      7   41.6 (41.0–42.2)  41.9 (41.3–42.5)
    ///     nothing collapses    7,644  4,459   25.9 (25.1–26.4)  26.4 (26.2–27.0)
    ///     nothing collapses   15,288  8,918   52.3 (51.7–54.3)  53.3 (52.5–55.3)
    ///
    /// Chronological is the faster column in all four, by 0.3–1.0ms of median,
    /// and every range overlaps — so the honest reading is that the difference
    /// does not register, which is what item 16d found from the other direction
    /// when it added the counts. What they cost was one `+= 1` per entry and two
    /// `Int` comparisons per sort comparison. The number that matters is that
    /// the list did not get slower; a second run of the same harness reproduced
    /// every figure within 0.5ms.
    var repeatItems: [HistoryItem] {
        var index: [HistoryItem.RepeatKey: Int] = [:]
        var rows: [(item: HistoryItem, canRepeat: Bool)] = []
        let targets = repeatTargets
        // The two sets are not the same question, and keeping them apart is
        // what makes this work.
        //
        // `targets` is what a tap may **write**: present, not archived, a daily
        // total. `listable` is what this screen is **about**: present and a
        // daily total, archived or not. Archiving is deliberately not part of
        // membership — item 16's rule is that archiving a tracker must not make
        // your food disappear, so those rows stay listed, sink to the bottom
        // and grey — while it very much is part of what a tap writes.
        let listable = repeatListTargets
        for row in historyItems {
            // **Projected before anything else reads it.** The row is built
            // from the members that belong on this screen rather than from
            // everything the batch holds, so a weigh-in is listed as its
            // calories and collapses onto the plain breakfast of the same
            // calories — right for "do that again", and the only way thirty
            // daily weigh-ins of one breakfast become one row instead of
            // thirty (`HistoryItem.keeping`).
            guard let listed = row.keeping({ listable.contains($0.trackerID) }) else { continue }
            // **Twice, and the second one is what makes the promise true.**
            // Membership is decided on `listable` above, because item 16 says
            // archiving a tracker must not take your food off this screen. But
            // a batch that logged a live total *and* one you have since
            // archived survives that first cut whole, and a tap writes only the
            // live half — so the row drew a value it would not write and the
            // bar said "Logged 1 of 2 again", which is the gap this screen
            // exists to close, moved from measurements onto archiving.
            //
            // So the content is projected again onto what a tap writes, and the
            // listable row is kept only when that leaves nothing: a row whose
            // every member is archived is unwritable, greyed, and says
            // "Archived" — a record rather than a promise.
            let item = listed.keeping({ targets.contains($0.trackerID) }) ?? listed
            let key = item.repeatKey
            if let at = index[key] {
                // **The newest row wins the slot, by its projected date.**
                // `historyItems` is newest first, so the first row met is
                // normally already the newest — but it is sorted by the date
                // the row had *before* projection, and projection can drop the
                // member that date came from. A batch whose members were
                // edited apart, holding a live total at 00:10 and an archived
                // one at 01:40, arrives ahead of a plain log of the same thing
                // at 00:50 and then projects down to 00:10. Keeping it would
                // date the row before the last time you logged it, which the
                // day label states outright and the sort below now orders
                // the whole list on.
                if item.date > rows[at].item.date { rows[at].item = item }
            } else {
                index[key] = rows.count
                // Once per collapsed row, not once per comparison, and it is the
                // same answer for every row the key collapsed: the key carries
                // the tracker ids, so they all name the same trackers.
                rows.append((item, !repeatableEntries(of: item, targets: targets).isEmpty))
            }
        }
        // The tie-break is explicit rather than left to the sort's stability,
        // which Swift's does not promise. It also cannot be left to the order
        // `rows` was built in: that is `historyItems` order, which is the
        // date each row had *before* projection, and the slot above now holds
        // whichever collapsed row is newest after it.
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

    /// Logs the same moment against several trackers at once, because calories
    /// and protein come from the same meal. One name across all of them: the
    /// log sheet has one name field.
    func add(values: [UUID: Double], at date: Date = .stamp(), name: String? = nil) {
        addBatch(
            values.sorted { $0.key < $1.key }.map { (tracker: $0.key, value: $0.value, name: name) },
            at: date
        )
    }

    /// The one place a batch is written, and the one code path behind both the
    /// log sheet and repeating a history row.
    ///
    /// Members share a `batchID`, which is what makes them one logged food
    /// rather than two rows that happen to agree on the clock. Assigned even for
    /// a single value: what was logged together is a property of the log, not of
    /// how many trackers it happened to touch — which is also why nothing here
    /// branches on how many there are.
    ///
    /// Takes pairs rather than a `[UUID: Double]` because a repeat carries each
    /// member's own name, and because a row is a list: keying by tracker would
    /// silently drop one of two entries that a hand-edited or imported file put
    /// in one batch against the same tracker, after the row had already
    /// displayed both.
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
    /// A tracker deleted with its history kept leaves entries behind pointing at
    /// nothing, and an archived tracker is one you have said you are done
    /// logging — the log sheet reaches neither. Writing to them from here would
    /// put a number somewhere no other screen in the app offers to put one, and
    /// somewhere home would never show it.
    ///
    /// **A measurement is not writable from here either, and that is the same
    /// rule rather than a second one** (docs/TODO.md item 23). Repeating a
    /// reading does not take one: it writes a weight nobody stood on the scale
    /// for, dated now, which home's Weight card then shows as today's reading
    /// and the chart draws as a point that never happened. Item 21 settled that
    /// and enforced it only in `repeatItems`, so the disc on a History row went
    /// on writing one — the rule lives here now, beside the kind, where every
    /// caller of `logAgain` inherits it.
    ///
    /// **The choke point rather than the control.** Disabling the disc on any
    /// row the Log again list would refuse reads more simply, but it
    /// refuses a weigh-in batch whole — its calories with its weight — and
    /// leaves `logAgain` willing to write a measurement for whatever calls it
    /// next. Dropping the member instead writes the calories, says "Logged 1 of 2
    /// again" through `lastLoggedAgain`, and greys the disc by itself on a row
    /// with nothing writable left.
    func repeatableEntries(of item: HistoryItem) -> [Entry] {
        repeatableEntries(of: item, targets: repeatTargets)
    }

    /// The same question with the answer hoisted, for a caller asking it about
    /// every row at once.
    ///
    /// `repeatItems` asks it once per collapsed row, and `tracker(_:)` is a
    /// linear scan, so the cost grows with the number of trackers as well as
    /// with the number of rows. Measured on the worst shape there is — 15,294
    /// entries that all differ, so nothing collapses and every row asks —
    /// hoisting the set takes the whole walk from 54.0–56.9ms to 49.9–51.0ms
    /// over eight trackers, and from 56.2–59.3ms to 54.4–55.5ms over three. The
    /// rule stays written once; only where the set is built moves.
    ///
    /// The public entry point above pays for that: it builds the set per call,
    /// and its callers are row bodies. Sub-microsecond on a handful of trackers,
    /// and taken deliberately — the alternative is the rule written twice, or a
    /// set threaded through two views to save an allocation neither screen can
    /// measure.
    private func repeatableEntries(of item: HistoryItem, targets: Set<UUID>) -> [Entry] {
        item.entries.filter { targets.contains($0.trackerID) }
    }

    /// Every tracker a repeat may write to: still present, not archived, and a
    /// daily total. See `repeatableEntries(of:)` for why the kind belongs in
    /// this set rather than in the three views that draw the disc.
    private var repeatTargets: Set<UUID> {
        Set(trackers.lazy.filter { !$0.isArchived && $0.kind != .measurement }.map(\.id))
    }

    /// Every tracker the Log again *list* is about: still present, a daily
    /// total, **archived or not**.
    ///
    /// The one difference from `repeatTargets`, and it is item 16's rule: a
    /// tracker you archive is one you have said you are done logging, not one
    /// whose history should vanish from a screen. Those rows stay listed, sort
    /// to the bottom and draw greyed. Deciding membership on what a tap can
    /// write instead would take them straight back out.
    ///
    /// **Membership only.** What a listed row *shows* is `repeatTargets` where
    /// that leaves anything, so an archived member is projected out of a row
    /// that still has a live one — and a row whose every member is archived
    /// keeps them all, because it is the greyed record this set exists for.
    private var repeatListTargets: Set<UUID> {
        Set(trackers.lazy.filter { $0.kind != .measurement }.map(\.id))
    }


    /// Logs a history row again, now: the same values against the same trackers,
    /// each keeping its own name, with today's timestamp and a **new** batch id.
    ///
    /// It writes; it never edits. The row that was tapped is untouched, which is
    /// what makes this safe to tap on a five-year-old entry.
    ///
    /// Partial rows write what they can and say so through `lastLoggedAgain`.
    /// Refusing the whole row because one of three trackers was deleted would
    /// make a normal state — deleting a tracker and keeping its history is a
    /// supported choice — quietly disable a button on every row it ever touched.
    /// A measurement member is partial in exactly that way and drops out here
    /// too, so a weigh-in batch repeats its calories and not its weight
    /// (`repeatableEntries(of:)`, docs/TODO.md item 23).
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
    /// Only the repeat's. The two slots are not symmetric: undoing a repeat
    /// **removes** entries by id, so an offer that outlives the write it
    /// describes destroys data — repeat a row, log a different food, and a bar
    /// still reading "Logged again" deletes the repeat with no tombstone behind
    /// it; edit the batch the repeat wrote and the same tap takes the edit away
    /// with it. Undoing a deletion only puts records back, so a deletion's offer
    /// is harmless however stale it gets, and it keeps standing exactly as it
    /// did before — the undo row in tracker detail survives a log made while it
    /// is on screen, which is what "forgiving" asks for (docs/PHILOSOPHY.md).
    private func forgetRepeatUndo() {
        if case .logged = lastWrite { lastWrite = nil }
    }

    /// Takes back the repeat that was just written.
    ///
    /// A mistap now costs data rather than a moment, so this has to exist. It
    /// records **no tombstone**: these entries are being unmade, not deleted,
    /// and a tombstone would carry "never allow this id again" into every future
    /// merge for a log that lasted two seconds.
    ///
    /// The same honest limit as `undoLastDeletion`, in reverse: if you exported
    /// between the tap and the undo, that export holds the entries, and
    /// re-importing it puts them back.
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
            // editor submits every member of the row whichever one you touched,
            // so stamping them all made a no-op rewrite of the protein entry
            // outrank — and silently discard — a real edit to it made on another
            // device an hour earlier. Same rule, and the same reason, as the one
            // `add(_ tracker:)` follows for `orderModified` (docs/TECH.md).
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
        // The same test decides both: a save that changed nothing is not a
        // newer write, so it must not withdraw a pending repeat's undo any more
        // than it restamps a member. Opening the batch a repeat wrote to check
        // the number and closing it again would otherwise cost the undo.
        if changedSomething { forgetRepeatUndo() }
        refreshToday()
        scheduleSave()
        return true
    }

    func delete(_ entry: Entry) {
        delete(entries: [entry])
    }

    /// Deletes the complete surviving batch behind one history row. A missing
    /// `batchID`, and a batch reduced to one member by tracker detail, both
    /// naturally delete just that ordinary single row.
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

    /// Puts back the entry that was just deleted.
    ///
    /// Fast input means mistakes, so this has to exist. It removes the
    /// tombstone as well as restoring the record — the deletion is being
    /// undone, not recorded and reversed.
    ///
    /// One honest limit: if you exported between the delete and the undo, that
    /// export carries the tombstone, and re-importing it deletes the entry
    /// again. Tombstones beat resurrections on purpose, and the alternative
    /// costs more than this corner is worth.
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

    /// Slots a grouped tracker beside the last visible tracker in that group, so
    /// the settings list draws a new `Food` tracker next to the rest of Food
    /// rather than at the bottom. A loose tracker, one naming a group that does
    /// not exist yet, and one whose group is entirely archived all go at the
    /// end — there is nothing on screen to sit beside.
    ///
    /// Home does not need this. It draws blocks from `logGroups`, so a group is
    /// drawn once wherever it first appears no matter where the record sits.
    ///
    /// Only a real insertion renumbers. Pushing rows down is a decision about
    /// the whole list, so it stamps every row's `orderModified` and merges whole
    /// (docs/TECH.md). Appending moves nothing, so it takes the next index and
    /// leaves every other record alone: stamping there would let adding a
    /// tracker here outrank, and silently discard, a drag made on another
    /// device — which is a position nobody on this one expressed an opinion
    /// about. Neither path touches `modified`, so an add can never outrank an
    /// edit either.
    func add(_ tracker: Tracker) {
        var tracker = tracker
        let now = Date.stamp()
        tracker.modified = now
        // Both stamps: it is a new record and it is taking a place in the list
        // for the first time, so neither is inherited from anywhere.
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
        // Position stays whatever the store currently says, never what the
        // caller is holding. The editor snapshots a tracker when it opens and a
        // swipe action captures one when the row is built, so saving a rename
        // would otherwise quietly undo a drag — or an import — that happened in
        // between, and put the stale position back under a fresh timestamp.
        updated.sortIndex = old.sortIndex
        updated.orderModified = old.orderModified
        // A save that changed nothing is not a write, and must not be stamped
        // like one. `TrackerEditor`'s Save is enabled on a non-empty name
        // rather than on a change, so opening a tracker to read its unit and
        // tapping Save used to make this device's copy newer — and a merge
        // then discarded a rename made on the iPad an hour earlier, silently.
        //
        // The same rule and the same reason as `update(_ updatedEntries:)`
        // above, which has followed it for the members of a batch since the
        // batch editor started submitting all of them. This is the other
        // record type, and it was the half that never got it.
        var withoutStamp = updated
        withoutStamp.modified = old.modified
        guard withoutStamp != old else { return }
        updated.modified = .stamp()
        let kindChanged = old.kind != updated.kind
        trackers[index] = updated
        if kindChanged { rebuildTotals() }
        scheduleSave()
    }

    /// Deletes the tracker. Its entries stay — keeping the history is a
    /// decision, not an oversight (docs/TECH.md).
    func delete(_ tracker: Tracker) {
        trackers.removeAll { $0.id == tracker.id }
        recordDeletion(of: tracker.id)
        scheduleSave()
    }

    /// Deletes the tracker and everything logged against it.
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
    /// A deletion undo must not be allowed to put this tracker's history back
    /// after the explicit, stronger deletion — but only this tracker's, because
    /// dropping the whole slot threw away a pending undo for a different tracker
    /// the deletion never touched. A repeat's undo removes entries rather than
    /// restoring them, so once its members are gone there is nothing left for it
    /// to take back, and an offer to undo what no longer exists is a lie.
    ///
    /// A repeat that lost only *some* of its members drops out whole rather than
    /// shrinking. Its two numbers describe one moment — "you tapped a row of
    /// three and I wrote two of them" — and there is no honest way to restate
    /// them once a tracker deletion has taken one of the two away: keeping the
    /// old `skipped` beside a smaller count reads "Logged 1 of 2 again" about a
    /// row that never existed, and recomputing it would claim the tap skipped
    /// something it had in fact written.
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

    /// The trackers a drop would carry: the dragged one alone inside its own
    /// block, its whole block across a boundary. Settings shows this while the
    /// finger is still down, so the rule lives here rather than being restated
    /// by the screen that draws it — the two answering differently is a bug
    /// nobody would see until after the drop.
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

    /// Drops one visible tracker onto another. Within a block, the tracker
    /// moves to the target's position. Across blocks, its entire source block
    /// moves there instead — position never changes membership or splits a
    /// named group.
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

    /// Puts these trackers in this order without changing their membership.
    /// Group membership changes only through `update`, from the tracker editor.
    ///
    /// Trackers not in `ordered` — the archived ones, normally — keep the slots
    /// they already occupied, so sorting the visible list never disturbs them.
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
            // The row value identifies what moved; content always comes from
            // the store. This keeps reorder an ordering-only operation even if
            // a stale or hand-built caller supplies different fields.
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

    /// Applies the order of the blocks the two screens display to the complete
    /// stored list. Named groups are gathered with archived members included;
    /// blocks that are entirely archived keep their block slot because they do
    /// not participate in active ordering at all.
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
        // `modified` must stay put and a reorder cannot outrank a rename made
        // on another device.
        let now = Date.stamp()
        for index in updated.indices {
            // Every row, not just the ones whose number changed. A drag settles
            // the order of the whole list, and stamping only the rows that moved
            // leaves the rest carrying an older stamp — so merging two devices
            // that each reordered would take some rows from one and some from
            // the other, landing on duplicate indices and an order neither of
            // them chose. Stamped whole, the later reorder simply wins whole.
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
        /// Throw away what is here and take the file as gospel.
        case replace
    }

    struct ImportSummary: Equatable, Sendable {
        var trackersAdded: Int
        var trackersRemoved: Int
        var entriesAdded: Int
        var entriesRemoved: Int
        /// Whether a recoverable copy of the previous document was actually
        /// kept. Carried here so the alert cannot promise a safety net that
        /// does not exist — an import that changed nothing never takes the
        /// slot, and on a fresh install there is then no copy at all.
        var keptBackup: Bool = false
    }

    func exportData() throws -> Data {
        try StoreCoding.encode(document)
    }

    func exportCSV() -> Data {
        CSVExport.data(document: document)
    }

    var hasImportBackup: Bool { file.hasImportBackup }

    /// Whether the document a destructive action is about to put in the
    /// recovery slot could actually come back out of it.
    ///
    /// **Loading is deliberately tolerant and restoring is not.** `StoreFile.load`
    /// runs no validation at all, so a hand-edited `store.json` carrying a
    /// duplicate id, `decimals` outside 0…3, or an id that is both live and
    /// tombstoned opens perfectly well — and `restoreImportBackup` then runs
    /// `validateImport` and refuses it. The copy gets written and cannot be
    /// read back.
    ///
    /// That gap is older than clearing, but a confirmation saying "this can be
    /// undone" is what makes it matter: the sentence that makes the decision
    /// safe to make would be false in the one case where it is load-bearing.
    /// So the screens that promise the safety net ask first, and say the other
    /// thing when the answer is no.
    ///
    /// Every document this app can produce passes — the editor bounds
    /// `decimals`, `add` renumbers a `sortIndex` near `Int.max`, and ids come
    /// from `UUID()` — so this is false only for a file somebody else wrote.
    var currentDocumentIsRestorable: Bool {
        (try? validateImport(document)) != nil
    }

    /// Takes a document in, and does not report success until the result is the
    /// document on disk.
    ///
    /// Async for the same reason the restore below is: an import is the one
    /// action a user takes and then immediately quits, and leaving it to the
    /// save debounce meant a force-quit inside that window silently discarded an
    /// import the app had already announced as complete. Draining the queue
    /// first also stops a write scheduled for the pre-import document from
    /// landing on top of the imported one.
    @discardableResult
    func importData(_ data: Data, mode: ImportMode) async throws -> ImportSummary {
        let incoming = try StoreMigration.migrate(data)
        try validateImport(incoming)
        try validateImportedNames(incoming)
        return try await applyIncoming(incoming, mode: mode)
    }

    /// Removes every tracker and entry, keeping what was here as the
    /// recoverable copy.
    ///
    /// **It is a replacing import with an empty argument**, and it runs through
    /// `applyIncoming(_:mode:)` rather than reimplementing it. That is the whole design
    /// of the item (docs/TODO.md item 24): the instinct is a stack of
    /// confirmations, and confirmations are a poor defence because people learn
    /// to tap through them. What actually makes this safe is the pre-clear copy,
    /// and the code that writes one correctly already exists — drained save
    /// queue, staged copy committed only once the empty document is durable, the
    /// slot untouched if the write fails. A second implementation of that
    /// sequence is a second place for the safety net to be quietly wrong, and
    /// nothing about it would look wrong.
    ///
    /// **No tombstones are written for what goes**, which is `replace`'s meaning
    /// inherited rather than a separate decision: the document afterwards is the
    /// argument, so merging an older export of this data brings it back. The
    /// alternative — a tombstone per record — would leave "start over" holding a
    /// file the size of the history it just removed, since tombstones are only
    /// compacted after `StoreDocument.tombstoneLifetime`. Five years of use is
    /// 29,756 entries (docs/scale.md); clearing them would produce 29,756
    /// deletions to carry around for six months, on the one action whose whole
    /// point is to end up with nothing.
    @discardableResult
    func clearAll() async throws -> ImportSummary {
        let summary = try await applyIncoming(StoreDocument(), mode: .replace)
        // The rolling save backup still holds the whole pre-clear document —
        // `StoreFile.write` copies the old file aside before every save — and
        // `load` reads it whenever the main file will not decode. That is a
        // second copy nobody was told about, of the data somebody has just
        // asked to be rid of. The disclosed recovery slot is the copy a clear
        // keeps; this one goes. See `StoreFile.discardSaveBackup`.
        file.discardSaveBackup()
        return summary
    }

    /// The transaction both of the above are: flush, decide, keep a copy, write,
    /// swap memory. Split out of `importData` when clearing everything turned
    /// out to be the same thing with a smaller argument.
    ///
    /// It takes a validated document, not bytes. `validateImport` is about what
    /// a *foreign* file has to satisfy, and the empty document this app builds
    /// for a clear is not one.
    private func applyIncoming(_ incoming: StoreDocument, mode: ImportMode) async throws -> ImportSummary {
        while true {
            let before = document
            let startingRevision = revision
            await saver.flush(before, revision: startingRevision)
            if let error = await saver.lastError {
                saveError = Self.describe(error)
                throw error
            }

            // Main-actor methods are reentrant at `await`. Anything that changed
            // while the saver drained has to be part of what gets merged and
            // backed up, so start again rather than importing onto a stale
            // snapshot.
            guard revision == startingRevision else { continue }

            let result = switch mode {
            case .merge: before.merged(with: incoming)
            case .replace: incoming.compactingTombstones()
            }
            // Both modes get a recoverable copy of what they are about to
            // change. A merge gets it too, even though it reads as the additive
            // choice: the document it takes in carries tombstones, so an old
            // export — or someone else's — can delete entries that exist here
            // and nowhere in the file. That is the same permanent loss replace
            // makes, arrived at quietly. The copy costs one write of a document
            // the app was about to write anyway.
            //
            // An import that changes nothing does not advance the slot. There
            // is nothing to recover from it, and the slot holds one document.
            // Spending it there would mean that a merge of a file you already
            // have — a single unconfirmed tap, and the import people repeat —
            // could burn the recovery point for the replace that needed it.
            let changesSomething = !Self.sameDocument(result, before)
            // Staged, not written into the slot. Overwriting the slot is itself
            // destructive, so doing it before the write below meant a failure
            // there — a full disk — left the user with neither document: the one
            // they might want back was already replaced by the one they were
            // importing over, under an alert that said nothing had changed.
            if changesSomething { try file.stageImportBackup(before) }
            do {
                // Before memory, so a failure here leaves the app exactly as it
                // was rather than holding a document that never reached disk.
                try file.write(result)
            } catch {
                file.discardStagedImportBackup()
                throw error
            }
            // Only now, with the import durable, is the old document safe to
            // give up. If this cannot be done the import still stands and the
            // summary says the safety net did not advance.
            let keptBackup = changesSomething && file.commitStagedImportBackup()
            replaceState(with: result, saving: false)
            revision += 1
            saveError = nil
            return importSummary(before: before, after: result, keptBackup: keptBackup)
        }
    }

    /// Restores the document saved before the last import, leaving the
    /// current document in that recovery slot. This is an async transaction
    /// because every delayed save must finish before the two files are swapped;
    /// otherwise an older queued write could land after the restore.
    @discardableResult
    func restoreImportBackup() async throws -> ImportSummary {
        while true {
            let incoming = try StoreMigration.migrate(file.importBackupData())
            try validateImport(incoming)
            // The filesystem swap installs these exact bytes as the live file.
            // Keep memory exact too; compaction belongs to ordinary import,
            // where the transformed document is subsequently saved.
            let result = incoming

            let before = document
            let startingRevision = revision
            await saver.flush(before, revision: startingRevision)
            if let error = await saver.lastError {
                saveError = Self.describe(error)
                throw error
            }

            // Main-actor methods are reentrant at `await`. If anything changed
            // while the saver drained, start again with the new current state
            // and recovery file rather than swapping a stale snapshot.
            guard revision == startingRevision else { continue }

            // `revision == 0` can mean the saver has never written this Store
            // instance. Put its exact current document in the live slot first;
            // failure leaves the recovery document untouched.
            try file.write(before)
            try file.swapWithImportBackup()
            replaceState(with: result, saving: false)
            revision += 1
            saveError = nil
            // Always true here: the swap put the document being replaced into
            // the recovery slot, which is what makes a mistaken restore
            // reversible.
            return importSummary(before: before, after: result, keptBackup: true)
        }
    }

    /// What a *foreign* file has to satisfy, and nothing else does.
    ///
    /// A name is what every screen identifies a tracker by, and nothing in the
    /// app can produce a blank one — `TrackerEditor` trims and refuses to save
    /// an empty name. A hand-edited or foreign file can, and it draws a blank
    /// card on home, a blank row in settings and a blank identity line in
    /// History, none of which say what they are or offer a way to find out.
    ///
    /// Refused rather than repaired: a repair rewrites a record the user did
    /// not edit, stamps it as an edit, and the merge then carries that invented
    /// name to every other device. The message names the id so the file can be
    /// fixed and imported again.
    ///
    /// **Separate from `validateImport` because the restore path must not run
    /// it.** That document was written by this app from its own memory, and
    /// loading is deliberately tolerant of a bad local file, so a hand-edited
    /// store file can put a blank name into the recovery slot. Refusing it
    /// there would disable the one action that undoes a destructive import,
    /// over a row that is merely blank. The checks in `validateImport` earn
    /// their strictness on both paths — they are about merges that stop
    /// converging and formatting that crashes; this one is not.
    private func validateImportedNames(_ document: StoreDocument) throws {
        for tracker in document.trackers {
            guard !tracker.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StoreError.invalidDocument(
                    "tracker \(tracker.id.uuidString) has an empty name."
                )
            }
        }
    }

    /// Import has to be idempotent. A decodable document containing duplicate
    /// live ids, duplicate tombstones, or a record that is simultaneously live
    /// and deleted changes meaning after the next merge and can double-count
    /// totals or duplicate SwiftUI identity. Loading remains tolerant of old
    /// bad local files; crossing the explicit import boundary does not.
    ///
    /// Run by the restore path too, which is why a check that is only about how
    /// a row *reads* lives in `validateImportedNames` instead.
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

    /// What the import did, in the terms the user was warned about.
    ///
    /// Trackers are counted in both directions like entries are. A replace that
    /// wipes two trackers and adds none used to report "Added 0 trackers and 0
    /// entries. Removed 0 entries" — a true sentence about entries and a
    /// silence about the two trackers that had just been destroyed.
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
    /// `(deleted, id)` while the live store appends them as deletions happen,
    /// and `Date.stamp()` rounds to whole seconds — so two deletions inside one
    /// second land in deletion order here and id order there. Re-merging a file
    /// you already have would then compare unequal about half the time, purely
    /// on tombstone order, and burn the recovery slot the check exists to
    /// protect. Trackers and entries are already in one canonical order on both
    /// sides; tombstones were the only array without one.
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
        // Import is a new whole-document decision. An undo captured from the
        // document it replaced must never be able to inject old entries into
        // it, duplicate an id the imported file already restored, or delete an
        // entry the file brought in that happens to share an id with one a
        // repeat wrote a moment ago.
        lastWrite = nil
        rebuildTotals()
        if saving { scheduleSave() }
    }

    // MARK: - The day boundary

    /// Re-reads the clock, and the calendar if the device's has changed.
    ///
    /// Called on every mutation and whenever the system reports a significant
    /// time change, which covers midnight rolling over while the app sits open
    /// and stepping off a plane into a new time zone.
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

    /// Wakes the app when the day rolls at an hour the system says nothing
    /// about.
    ///
    /// **`significantTimeChangeNotification` fires at midnight**, which is
    /// exactly where the boundary used to be — so the moment the day start is
    /// moved to 4am, nothing announces the roll any more. Left open overnight
    /// with a 4am start, the home screen went on showing yesterday's total
    /// under today's heading until something else happened to call
    /// `refreshToday`. That is a regression the feature introduced, not an old
    /// gap: the notification and the boundary used to coincide.
    ///
    /// One sleeping task, replaced only when the moment it is waiting for
    /// moves. `refreshToday` runs on every mutation, so rescheduling
    /// unconditionally would spawn a task per logged number.
    ///
    /// Nothing at midnight, where the notification already does this, and
    /// nothing in a store with a pinned clock, where a live timer would be a
    /// test holding a task open against a `now` that never advances. Being
    /// backgrounded across the boundary is covered already — the app calls
    /// `refreshToday` when the scene becomes active.
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

    /// Rebuilt from scratch whenever the day mapping itself could have changed.
    /// Also called at launch, which resets any drift the incremental updates
    /// accumulated during the last session.
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

    /// Adds or removes one entry's contribution.
    ///
    /// The count is what says whether a day still has anything in it. Deciding
    /// that from the sum alone is wrong twice over: a day can legitimately add
    /// up to zero, and repeated addition and subtraction of decimals leaves a
    /// residue that would never compare equal to it.
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

/// The trackers one trip through the log sheet writes to.
///
/// A group when the trackers are logged together — calories and protein from
/// the same meal — and a single tracker when it isn't in one. Being in no
/// group is *not* a group: your cigarettes and your pushups share nothing
/// but the absence of a name, so putting them in one sheet would claim they are
/// logged at the same time. One field is the honest sheet for either of them.
///
/// Nothing about this is stored. It is computed from `Tracker.group` at read
/// time, which makes it a displayed decision (docs/TECH.md) — it can be
/// reworked after a week of real use with no migration and nothing to convert.
/// The one exception is the string form below, which is small on purpose.
enum LogGroup: Hashable, Sendable {
    /// Never empty — an empty group string is the ungrouped case.
    case group(String)
    case tracker(UUID)

    /// Where this tracker gets logged.
    init(of tracker: Tracker) {
        self = tracker.group.isEmpty ? .tracker(tracker.id) : .group(tracker.group)
    }
}

extension LogGroup: RawRepresentable {

    /// A string, because the last-used group lives in `UserDefaults` and that is
    /// what fits there. Prefixed so a group named like a UUID cannot be read
    /// back as a tracker; the value is never inspected anywhere else, and a
    /// string that no longer resolves just means + opens the first group.
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
