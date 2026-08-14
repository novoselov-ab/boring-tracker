import Foundation
import SwiftUI  // only for `move(fromOffsets:toOffset:)`, which lives there
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
    /// The entry deleted most recently, so it can be put straight back.
    private(set) var lastDeletion: Entry?

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
        saveWindow: Duration = .milliseconds(500)
    ) {
        let document = document.compactingTombstones()
        self.trackers = document.trackers.sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
        self.entries = StoreDocument.sorted(document.entries)
        self.tombstones = document.tombstones
        self.origin = origin
        self.calendar = calendar ?? .current
        self.followsSystemCalendar = calendar == nil
        self.today = DayKey(Date(), calendar: calendar ?? .current)
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

    /// The trackers one save writes to: a group's, or the single ungrouped
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

    /// The last few distinct values logged against a tracker, newest first.
    ///
    /// This is the whole of "recents", and eventually the raw material for
    /// presets: you eat the same things over and over, so the number you want
    /// is usually one you have typed before. No setup, nothing to maintain.
    func recentValues(for tracker: UUID, limit: Int = 5) -> [Double] {
        var seen = Set<Double>()
        var result: [Double] = []
        for entry in entries.reversed() where entry.trackerID == tracker {
            if seen.insert(entry.value).inserted { result.append(entry.value) }
            if result.count == limit { break }
        }
        return result
    }

    func day(of entry: Entry) -> DayKey {
        DayKey(entry.date, calendar: calendar)
    }

    // MARK: - Entries

    func add(_ entry: Entry) {
        var entry = entry
        entry.modified = .stamp()
        insertSorted(entry)
        apply(1, to: entry)
        refreshToday()
        scheduleSave()
    }

    /// Logs the same moment against several trackers at once, because calories
    /// and protein come from the same meal.
    ///
    /// They share a `batchID`, which is what makes them one logged food rather
    /// than two rows that happen to agree on the clock. Assigned even for a
    /// single value: what was saved together is a property of the save, not of
    /// how many trackers it happened to touch.
    func add(values: [UUID: Double], at date: Date = .stamp(), name: String? = nil) {
        let date = date.canonicalized
        let batch = UUID()
        for (tracker, value) in values.sorted(by: { $0.key < $1.key }) {
            add(Entry(trackerID: tracker, value: value, date: date, name: name, batchID: batch))
        }
    }

    func update(_ entry: Entry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let old = entries[index]
        var updated = entry
        updated.modified = .stamp()
        apply(-1, to: old)
        entries.remove(at: index)
        insertSorted(updated)
        apply(1, to: updated)
        refreshToday()
        scheduleSave()
    }

    func delete(_ entry: Entry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        apply(-1, to: entries[index])
        entries.remove(at: index)
        recordDeletion(of: entry.id)
        lastDeletion = entry
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
        guard let entry = lastDeletion else { return }
        tombstones.removeAll { $0.id == entry.id }
        insertSorted(entry)
        apply(1, to: entry)
        lastDeletion = nil
        refreshToday()
        scheduleSave()
    }

    func forgetLastDeletion() {
        lastDeletion = nil
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
            tracker.sortIndex = (trackers.map(\.sortIndex).max() ?? -1) + 1
            trackers.append(tracker)
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
        delete(tracker)
    }

    /// Reorders trackers the way they were drawn on screen.
    ///
    /// Takes the list the user was actually looking at, because a `List` reports
    /// offsets into what it drew — and every screen that reorders hides the
    /// archived ones. Applying those offsets to `trackers` directly moves the
    /// wrong rows the moment anything is archived.
    func move(_ visible: [Tracker], fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var reordered = visible
        reordered.move(fromOffsets: offsets, toOffset: destination)
        reorder(reordered)
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

        var updated = trackers
        for (slot, tracker) in zip(slots, ordered) {
            // The row value identifies what moved; content always comes from
            // the store. This keeps reorder an ordering-only operation even if
            // a stale or hand-built caller supplies different fields.
            updated[slot] = previous[tracker.id] ?? updated[slot]
        }
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
        /// Union by id — nothing you already have is lost.
        case merge
        /// Throw away what is here and take the file as gospel.
        case replace
    }

    struct ImportSummary: Equatable, Sendable {
        var trackersAdded: Int
        var entriesAdded: Int
        var entriesRemoved: Int
    }

    func exportData() throws -> Data {
        try StoreCoding.encode(document)
    }

    @discardableResult
    func importData(_ data: Data, mode: ImportMode) throws -> ImportSummary {
        let incoming = try StoreMigration.migrate(data)
        let before = document
        let result = switch mode {
        case .merge: before.merged(with: incoming)
        case .replace: incoming.compactingTombstones()
        }
        replaceState(with: result)

        let oldEntries = Set(before.entries.map(\.id))
        let newEntries = Set(result.entries.map(\.id))
        return ImportSummary(
            trackersAdded: Set(result.trackers.map(\.id))
                .subtracting(before.trackers.map(\.id)).count,
            entriesAdded: newEntries.subtracting(oldEntries).count,
            entriesRemoved: oldEntries.subtracting(newEntries).count
        )
    }

    private func replaceState(with document: StoreDocument) {
        trackers = document.trackers.sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
        entries = StoreDocument.sorted(document.entries)
        tombstones = document.tombstones
        rebuildTotals()
        scheduleSave()
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
        let day = DayKey(Date(), calendar: calendar)
        if day != today { today = day }
    }

    /// Moves the store to another calendar, as if the device had been carried
    /// there. Every day-keyed total has to be recomputed, because which day an
    /// entry belongs to is derived, never stored.
    func travel(to calendar: Calendar) {
        self.calendar = calendar
        rebuildTotals()
        let day = DayKey(Date(), calendar: calendar)
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

// MARK: - What one save covers

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
