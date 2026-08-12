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
    private(set) var pins: [Pin]
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
        self.pins = document.pins
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
            pins: pins,
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
    func add(values: [UUID: Double], at date: Date = .stamp(), note: String? = nil) {
        let date = date.canonicalized
        for (tracker, value) in values.sorted(by: { $0.key < $1.key }) {
            add(Entry(trackerID: tracker, value: value, date: date, note: note))
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

    func add(_ tracker: Tracker) {
        var tracker = tracker
        tracker.modified = .stamp()
        tracker.sortIndex = (trackers.map(\.sortIndex).max() ?? -1) + 1
        trackers.append(tracker)
        scheduleSave()
    }

    func update(_ tracker: Tracker) {
        guard let index = trackers.firstIndex(where: { $0.id == tracker.id }) else { return }
        var updated = tracker
        updated.modified = .stamp()
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

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var ordered = trackers
        ordered.move(fromOffsets: offsets, toOffset: destination)
        let now = Date.stamp()
        for index in ordered.indices where ordered[index].sortIndex != index {
            ordered[index].sortIndex = index
            ordered[index].modified = now
        }
        trackers = ordered
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
        pins = document.pins
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
