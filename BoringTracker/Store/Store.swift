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
    /// The newest member of what was deleted most recently. Detail uses this
    /// to decide whether its undo row belongs on screen; the complete deletion
    /// is kept separately so one history-row delete can restore a whole batch.
    var lastDeletion: Entry? { lastDeletedEntries.first }
    var lastDeletionCount: Int { lastDeletedEntries.count }
    private var lastDeletedEntries: [Entry] = []

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
    /// single value: what was logged together is a property of the log, not of
    /// how many trackers it happened to touch.
    func add(values: [UUID: Double], at date: Date = .stamp(), name: String? = nil) {
        let date = date.canonicalized
        let batch = UUID()
        for (tracker, value) in values.sorted(by: { $0.key < $1.key }) {
            add(Entry(trackerID: tracker, value: value, date: date, name: name, batchID: batch))
        }
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
                updated.modified = withoutStamp == old ? old.modified : now
            } else {
                updated.modified = now
            }
            insertSorted(updated)
            apply(1, to: updated)
        }
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
        lastDeletedEntries = existing.sorted { ($0.date, $0.id) > ($1.date, $1.id) }
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
        lastDeletedEntries = []
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
        // A previous entry undo must not be allowed to put this tracker's
        // history back after the explicit, stronger deletion — but only this
        // tracker's. Dropping the whole undo threw away a pending undo for a
        // different tracker that the deletion never touched.
        lastDeletedEntries.removeAll { $0.trackerID == tracker.id }
        delete(tracker)
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
            // Both modes. Decode and validate the incoming file first; once it
            // is known to be usable, preserving the exact current document must
            // succeed or the import does not happen.
            //
            // A merge gets this too, even though it reads as the additive
            // choice: the document it takes in carries tombstones, so an old
            // export — or someone else's — can delete entries that exist here
            // and nowhere in the file. That is the same permanent loss replace
            // makes, arrived at quietly. The copy costs one write of a document
            // the app was about to write anyway.
            //
            // An import that changes nothing does not advance the slot. There
            // is nothing to recover from it, and the slot holds one document:
            // spending it would mean a merge of a file you already have — a
            // single unconfirmed tap, and the one import people repeat — could
            // burn the recovery point for the replace that actually needs it.
            if result != before {
                try file.writeImportBackup(before)
            }
            // Before memory, so a failure here leaves the app exactly as it was
            // rather than holding a document that never reached disk.
            try file.write(result)
            replaceState(with: result, saving: false)
            revision += 1
            saveError = nil
            return importSummary(before: before, after: result)
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
            return importSummary(before: before, after: result)
        }
    }

    /// Import has to be idempotent. A decodable document containing duplicate
    /// live ids, duplicate tombstones, or a record that is simultaneously live
    /// and deleted changes meaning after the next merge and can double-count
    /// totals or duplicate SwiftUI identity. Loading remains tolerant of old
    /// bad local files; crossing the explicit import boundary does not.
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
    private func importSummary(before: StoreDocument, after result: StoreDocument) -> ImportSummary {
        let oldTrackers = Set(before.trackers.map(\.id))
        let newTrackers = Set(result.trackers.map(\.id))
        let oldEntries = Set(before.entries.map(\.id))
        let newEntries = Set(result.entries.map(\.id))
        return ImportSummary(
            trackersAdded: newTrackers.subtracting(oldTrackers).count,
            trackersRemoved: oldTrackers.subtracting(newTrackers).count,
            entriesAdded: newEntries.subtracting(oldEntries).count,
            entriesRemoved: oldEntries.subtracting(newEntries).count
        )
    }

    private func replaceState(with document: StoreDocument, saving: Bool = true) {
        trackers = document.trackers.sorted { ($0.sortIndex, $0.id) < ($1.sortIndex, $1.id) }
        entries = StoreDocument.sorted(document.entries)
        tombstones = document.tombstones
        // Import is a new whole-document decision. An undo captured from the
        // document it replaced must never be able to inject old entries into
        // it, or duplicate an id the imported file already restored.
        lastDeletedEntries = []
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
