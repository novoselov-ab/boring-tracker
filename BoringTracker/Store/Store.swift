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
        /// Members of the row left out because their tracker has been deleted
        /// or archived. The screen says so rather than writing part of a row
        /// under a button that promised the whole of it.
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
    /// False when a test pinned the calendar, so system time-zone changes do
    /// not yank it back to the device's.
    private let followsSystemCalendar: Bool
    /// The clock, pinned by tests. `nil` in the app, where the device's clock is
    /// the only honest answer.
    ///
    /// Here for the same reason `calendar` is injectable: since `repeatItems`
    /// counts only the last `countingWindowDays`, a fixture's dates and "now"
    /// are no longer independent, and a test whose fixture drifts out of the
    /// window as the wall clock advances is a test that passes today and fails
    /// in March.
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

    // MARK: - Life cycle

    /// Loads synchronously. The file is small, and doing this asynchronously
    /// would flash an empty home screen for longer than the decode takes.
    convenience init(file: StoreFile = .standard()) {
        let loaded = file.load()
        self.init(document: loaded.document, origin: loaded.origin, file: file)
    }

    init(
        document: StoreDocument = .starter,
        origin: StoreOrigin = .fresh,
        file: StoreFile = .standard(),
        calendar: Calendar? = nil,
        now: Date? = nil,
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
        self.today = DayKey(now ?? Date(), calendar: calendar ?? .current)
        self.file = file
        self.saver = StoreSaver(file: file, window: saveWindow)
        rebuildTotals()
        watchForTimeChanges()
    }

    isolated deinit {
        if let timeObserver {
            NotificationCenter.default.removeObserver(timeObserver)
        }
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
        Task { await saver.save(document, revision: revision) }
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
        DayKey(entry.date, calendar: calendar)
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

    /// The Repeat screen's list: one row per distinct named thing you have
    /// logged, the ones logged most often lately first.
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
    /// **Ordered by how often you have logged it lately, then by how often you
    /// have logged it ever, then by which is newest.** Recency was right for
    /// the undeduplicated list and stops being
    /// right the moment duplicates collapse: both orderings were built and
    /// screenshotted on a 56-day fixture, and recency spent two of its first
    /// fourteen rows on one food at two portions while four rows in a row read
    /// "Today" — a one-off floats to the top merely because it was yesterday,
    /// and the date column says nothing where it is densest. Frequency's first
    /// screen is thirteen different foods at the portions actually eaten, with
    /// the variants below them. It is also **steadier**: the top of a recency
    /// list moves on every single log, so the row you tap each morning is never
    /// twice in the same place.
    ///
    /// Frequency degrades into recency rather than falling apart, which is what
    /// makes it safe for the case this screen is worst at: someone who weighs
    /// food to the gram repeats no number exactly, every count is 1, and the
    /// tie-break is the whole ordering (docs/TODO.md item 16).
    ///
    /// **A row that cannot be written sorts below every row that can**, whatever
    /// its count. Archiving a tracker is a supported thing to do, and under a
    /// pure frequency order a year of porridge logged against a tracker you have
    /// since archived would own the top of the screen for good — a screenful of
    /// greyed rows in front of every row that still works. Recency used to sink
    /// them on its own, and the count below does so only once the window has
    /// passed over them, which is months of it. They stay on the list
    /// rather than disappearing, which is item 16's decision and unchanged: the
    /// row is still a true statement about what you ate, and a screen that drops
    /// food when you archive a tracker is editing your history.
    ///
    /// **The count is over the last `countingWindowDays` days, not over
    /// everything ever logged.** A lifetime count never falls, so eat porridge
    /// every morning for a year, switch to overnight oats for a month, and last
    /// year's staple still outranks this morning's — reachable only by search,
    /// on a screen whose job is one tap. The window drops that and keeps what
    /// frequency was chosen for: the portion you usually eat first, and a
    /// one-off that cannot reach the top merely because it was yesterday.
    ///
    /// **The lifetime count breaks the ties the window leaves**, between the
    /// windowed count and the date. Inside 60 days most counts are small, so
    /// ties are the common case rather than the edge one — two things each eaten
    /// twice this month tie immediately, and the date then decides on which one
    /// you happened to eat last, which says nothing about which you are likelier
    /// to want. A thing eaten 200 times over two years and twice this month is a
    /// staple having a quiet spell; a thing eaten twice ever is not. It also
    /// settles the saturation the window came with: log porridge and a flat
    /// white once a day each and both count 60, where the windowed count alone
    /// let the date swap them as you logged them — at 400 lifetime against 380
    /// they now hold their order (docs/TODO.md item 16d).
    ///
    /// **It does not undo the window**, because it never speaks first. The
    /// window still decides the opening comparison, so a staple you gave up a
    /// year ago counts zero and stays where 60 days put it however many times
    /// you ate it — the lifetime count only reaches rows the window has already
    /// declared a draw. What it changes underneath that draw is real, though: a
    /// history entirely outside the window is no longer a plain recency list,
    /// it is a lifetime-count list with recency under it.
    ///
    /// **Both counts come off the same walk** — one `+= 1` beside the windowed
    /// one, no second pass over history, and one more `Int` compared per sort
    /// comparison on a list already collapsed to rows. Ten runs each against a
    /// counterfactual build with the tie-break removed and nothing else changed,
    /// on fixtures of four named meals and a weight reading a day ending today:
    /// **20.3–22.3ms against 20.4–22.9ms over 7,641 entries (4,245 history
    /// rows), and 40.5–41.5ms against 39.9–42.1ms over 15,291 (8,495)**. Those
    /// collapse to 10 rows, so they barely exercise the sort; the shape that
    /// does is the one where nothing collapses — every value distinct, so 3,396
    /// and 6,796 repeat rows — and it reads **24.2–26.9ms against 24.6–27.4ms**
    /// and **49.5–54.2ms against 48.7–52.7ms**. Every pair overlaps, and in
    /// three of the four the counterfactual owns the slowest run, so the honest
    /// reading is that the cost does not register.
    ///
    /// **Measured from a temporary test in this target, not from items 16 and
    /// 16c's probe root**, so these numbers are comparable to each other and not
    /// to the ones further down this comment — the same Debug build on the same
    /// iPhone 17 simulator, but a different harness. The pair to read is the two
    /// columns here.
    ///
    /// **Rows tied on `canRepeat`, both counts and the date are still ordered**,
    /// by `sortID`, which is unique per row. The list does not shuffle between
    /// openings.
    ///
    /// **It changes the order, never the membership.** A row whose logs are all
    /// older than the window counts zero and sinks to the bottom of the rows
    /// that can still be written, ordered among them by the lifetime count and
    /// then recency — it does not disappear. Item 16 settled that a screen which
    /// drops food is editing your history, and a count is not a filter.
    ///
    /// A filter over `historyItems` rather than its own walk of `entries`: the
    /// grouping of a batch into one row is the same question both screens ask,
    /// and it is already pinned by tests here. A second walk would be a second
    /// chance to answer it differently.
    ///
    /// One pass and a dictionary of positions, so the counting costs a hash per
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
    /// **The window is free.** One `Date` comparison per named row, no second
    /// pass and nothing extra to sort. Re-measured the same way at the same two
    /// entry counts, five runs each, against a build with the window widened
    /// past the fixture's own history so the counterfactual is the same binary
    /// in every other respect: **19.4–20.6ms against 19.7–23.1ms at 7,644
    /// entries, and 39.1–41.8ms against 39.4–41.7ms at 15,294** (docs/TODO.md
    /// item 16c). The windowed runs are the faster pair on both files, which is
    /// noise rather than a saving — the honest reading is that the difference
    /// does not register.
    ///
    /// **Those are not the fixtures the paragraph above was measured on**, and
    /// the two sets must not be read as a before and after: a window measured
    /// back from today reads nothing unless the file ends today, so these were
    /// generated afresh and collapse to 37 rows rather than 61. The pair to
    /// compare is the two columns here, taken minutes apart on one machine.
    var repeatItems: [HistoryItem] {
        var index: [HistoryItem.RepeatKey: Int] = [:]
        var rows: [(item: HistoryItem, count: Int, lifetime: Int, canRepeat: Bool)] = []
        let targets = repeatTargets
        let windowStart = countingWindowStart
        for item in historyItems where item.isNamed {
            let key = item.repeatKey
            // The only thing the window touches. Every row is still built and
            // still listed; one outside it simply adds nothing to its count.
            let counted = item.date >= windowStart ? 1 : 0
            if let at = index[key] {
                rows[at].count += counted
                rows[at].lifetime += 1
            } else {
                index[key] = rows.count
                // Once per collapsed row, not once per comparison, and it is the
                // same answer for every row the key collapsed: the key carries
                // the tracker ids, so they all name the same trackers.
                rows.append(
                    (item, counted, 1, !repeatableEntries(of: item, targets: targets).isEmpty)
                )
            }
        }
        // `historyItems` is newest first, so the tie-break is already in hand:
        // a stable sort would do, and Swift's is not stable, hence the explicit
        // date and `sortID` below.
        return rows
            .sorted { lhs, rhs in
                if lhs.canRepeat != rhs.canRepeat { return lhs.canRepeat }
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if lhs.lifetime != rhs.lifetime { return lhs.lifetime > rhs.lifetime }
                if lhs.item.date != rhs.item.date { return lhs.item.date > rhs.item.date }
                return lhs.item.sortID > rhs.item.sortID
            }
            .map(\.item)
    }

    /// How far back `repeatItems` counts.
    ///
    /// A displayed decision, free to change again: nothing is stored, derived or
    /// migrated from it, and moving it only reorders a list. Sixty days is long
    /// enough that a weekly thing is still counted about eight times and a
    /// seasonal one does not fall off the moment the weather turns, and short
    /// enough that a habit you dropped two months ago stops holding the top of
    /// the screen (docs/TODO.md item 16c).
    static let countingWindowDays = 60

    /// The first moment `repeatItems` counts: the start of today's day, less the
    /// days before it that the window reaches back over.
    ///
    /// Whole days, in the store's calendar, rather than 60×86,400 seconds before
    /// this instant. Every other boundary in this app is a local day (`DayKey`),
    /// a seconds-based window would slide under the list while you read it, and
    /// asking the calendar is what makes the arithmetic survive a DST change.
    var countingWindowStart: Date {
        today
            .adding(days: -(Self.countingWindowDays - 1), calendar: calendar)
            .startOfDay(calendar: calendar)
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

    /// Every tracker a repeat may write to: still present, and not archived.
    private var repeatTargets: Set<UUID> {
        Set(trackers.lazy.filter { !$0.isArchived }.map(\.id))
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
        var updated = tracker
        updated.modified = .stamp()
        // Position stays whatever the store currently says, never what the
        // caller is holding. The editor snapshots a tracker when it opens and a
        // swipe action captures one when the row is built, so saving a rename
        // would otherwise quietly undo a drag — or an import — that happened in
        // between, and put the stale position back under a fresh timestamp.
        updated.sortIndex = trackers[index].sortIndex
        updated.orderModified = trackers[index].orderModified
        let kindChanged = trackers[index].kind != updated.kind
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
        let day = DayKey(now, calendar: calendar)
        if day != today { today = day }
    }

    /// Moves the store to another calendar, as if the device had been carried
    /// there. Every day-keyed total has to be recomputed, because which day an
    /// entry belongs to is derived, never stored.
    func travel(to calendar: Calendar) {
        self.calendar = calendar
        rebuildTotals()
        let day = DayKey(now, calendar: calendar)
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
            let key = DayTotal(tracker: entry.trackerID, day: DayKey(entry.date, calendar: calendar))
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
        let key = DayTotal(tracker: entry.trackerID, day: DayKey(entry.date, calendar: calendar))
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
