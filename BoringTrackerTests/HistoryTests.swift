import Foundation
import Testing
@testable import BoringTracker

@MainActor
@Suite("History")
struct HistoryTests {
    private func historyStore(_ document: StoreDocument) -> Store {
        Store(
            document: document,
            file: StoreFile(directory: URL.temporaryDirectory.appending(path: "history-\(UUID())")),
            calendar: calendar("UTC"),
            saveWindow: .seconds(60)
        )
    }

    @Test("A batch is one row and ordinary entries stay one row each")
    func grouping() {
        let tracker = Tracker(name: "Calories")
        let batch = UUID()
        let entries = [
            Entry(trackerID: tracker.id, value: 1, date: time(10)),
            Entry(trackerID: tracker.id, value: 2, date: time(20), batchID: batch),
            Entry(trackerID: tracker.id, value: 3, date: time(20), batchID: batch),
            Entry(trackerID: tracker.id, value: 4, date: time(30), batchID: UUID()),
        ]
        let store = historyStore(StoreDocument(trackers: [tracker], entries: entries))

        #expect(store.historyItems.count == 3)
        #expect(store.historyItems.map(\.entries.count) == [1, 2, 1])
        #expect(store.historyItems.flatMap(\.entries).count == entries.count)
    }

    @Test("A batch spanning midnight stays one row on its newest member's day")
    func spanningMidnight() {
        let tracker = Tracker(name: "Calories")
        let batch = UUID()
        let earlier = Entry(trackerID: tracker.id, value: 1,
                            date: date(2026, 3, 14, 23, 59), batchID: batch)
        let later = Entry(trackerID: tracker.id, value: 2,
                          date: date(2026, 3, 15, 0, 1), batchID: batch)
        let store = historyStore(StoreDocument(trackers: [tracker], entries: [earlier, later]))

        #expect(store.historyItems.count == 1)
        #expect(store.historyItems[0].date == later.date)
        #expect(store.day(of: store.historyItems[0].entries[0]) == DayKey(year: 2026, month: 3, day: 15))
    }

    @Test("Deleted trackers and partial batches leave the surviving history readable")
    func deletedTrackerAndPartialBatch() {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        let first = Entry(trackerID: calories.id, value: 100, date: time(10), batchID: batch)
        let second = Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch)
        let store = historyStore(StoreDocument(trackers: [calories, protein], entries: [first, second]))

        store.delete(calories)
        #expect(store.historyItems.first?.entries.count == 2)
        store.delete(first)
        #expect(store.historyItems.first?.entries == [second])
    }

    @Test("Editing and deleting a history row changes the whole batch once")
    func batchMutations() {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        let first = Entry(trackerID: calories.id, value: 100, date: time(10), batchID: batch)
        let second = Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch)
        let store = historyStore(StoreDocument(trackers: [calories, protein], entries: [first, second]))
        var edited = [first, second]
        edited[0].value = 200
        edited[1].value = 20

        #expect(store.update(edited))
        #expect(Dictionary(uniqueKeysWithValues: store.entries.map { ($0.id, $0.value) })
            == [first.id: 200, second.id: 20])

        store.deleteBatch(containing: first)
        #expect(store.entries.isEmpty)
        #expect(store.tombstones.count == 2)

        store.undoLastDeletion()
        #expect(Dictionary(uniqueKeysWithValues: store.entries.map { ($0.id, $0.value) })
            == [first.id: 200, second.id: 20])
        #expect(store.tombstones.isEmpty)
    }

    @Test("Undo cannot resurrect an entry after deleting its tracker and history")
    func deleteWithHistoryInvalidatesUndo() {
        let tracker = Tracker(name: "Calories")
        let entry = Entry(trackerID: tracker.id, value: 100, date: time(10))
        let store = historyStore(StoreDocument(trackers: [tracker], entries: [entry]))

        store.delete(entry)
        #expect(store.lastDeletion == entry)
        store.deleteWithHistory(tracker)
        store.undoLastDeletion()

        #expect(store.entries.isEmpty)
        #expect(store.lastDeletion == nil)
    }

    @Test("A replace import invalidates undo from the document it replaced")
    func replaceImportInvalidatesUndo() async throws {
        let tracker = Tracker(name: "Calories")
        let entry = Entry(trackerID: tracker.id, value: 100, date: time(10))
        let store = historyStore(StoreDocument(trackers: [tracker], entries: [entry]))
        store.delete(entry)
        let replacement = StoreDocument(trackers: [tracker], entries: [entry])

        try await store.importData(StoreCoding.encode(replacement), mode: .replace)
        store.undoLastDeletion()

        #expect(store.entries == [entry])
        #expect(store.lastDeletion == nil)
    }

    @Test("A batch is called what the row shows, even if its newest member lost the name")
    func batchNameSurvivesAMemberLosingIt() throws {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        // The newest member is the one whose name was cleared in tracker detail.
        let named = Entry(trackerID: protein.id, value: 10, date: time(10),
                          name: "chicken rice", batchID: batch)
        let cleared = Entry(trackerID: calories.id, value: 100, date: time(20),
                            name: nil, batchID: batch)
        let store = historyStore(
            StoreDocument(trackers: [calories, protein], entries: [named, cleared])
        )

        let item = try #require(store.historyItems.first)
        #expect(item.names == ["chicken rice"])
        // What the row shows and what the editor seeds must be the same string,
        // or saving the editor writes a blank over the name the row displayed.
        #expect(item.displayName == "chicken rice")
    }

    @Test("A row whose members disagree says so rather than picking one")
    func mixedNames() throws {
        let tracker = Tracker(name: "Calories")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [tracker], entries: [
            Entry(trackerID: tracker.id, value: 1, date: time(10), name: "rice", batchID: batch),
            Entry(trackerID: tracker.id, value: 2, date: time(20), name: "beans", batchID: batch),
        ]))

        let item = try #require(store.historyItems.first)
        #expect(item.names == ["beans", "rice"])
        #expect(item.displayName == "Mixed names")
    }

    // MARK: - What a row says (docs/TODO.md item 14b)

    /// The rule the two lines have to keep between them: the identity line
    /// leads, and the values line never repeats what it already said.
    private func line(_ store: Store, _ index: Int = 0) throws -> HistoryItem.Line {
        let trackers = Dictionary(
            store.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        let items = store.historyItems
        try #require(index < items.count)
        return items[index].line(trackers: trackers)
    }

    @Test("A named row leads with the name and keeps it out of the values")
    func lineUsesTheName() throws {
        let calories = Tracker(name: "Calories", unit: "kcal", group: "Food")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1, group: "Food")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [calories, protein], entries: [
            Entry(trackerID: calories.id, value: 100, date: time(10),
                  name: "chicken rice", batchID: batch),
            Entry(trackerID: protein.id, value: 10, date: time(10),
                  name: "chicken rice", batchID: batch),
        ]))

        #expect(try line(store) == .init(identity: "chicken rice", values: "100 kcal, 10 g"))
    }

    @Test("An unnamed batch leads with the group it was logged as")
    func lineFallsBackToTheGroup() throws {
        let calories = Tracker(name: "Calories", unit: "kcal", group: "Food")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1, group: "Food")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [calories, protein], entries: [
            Entry(trackerID: calories.id, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch),
        ]))

        #expect(try line(store) == .init(identity: "Food", values: "100 kcal, 10 g"))
    }

    @Test("An unnamed single entry leads with its tracker, not with its group")
    func lineFallsBackToTheTracker() throws {
        let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
                             group: "Weight")
        let store = historyStore(StoreDocument(trackers: [weight], entries: [
            Entry(trackerID: weight.id, value: 78.4, date: time(10)),
        ]))

        #expect(try line(store) == .init(identity: "Weight", values: "78.4 kg"))
    }

    /// The one the layout change is for: with the tracker named above it, a
    /// unitless number must not be prefixed with that same name again.
    @Test("A lone unitless number is not prefixed with the name above it")
    func lineDoesNotSayTheTrackerTwice() throws {
        let cigarettes = Tracker(name: "Cigarettes")
        let store = historyStore(StoreDocument(trackers: [cigarettes], entries: [
            Entry(trackerID: cigarettes.id, value: 3, date: time(10)),
        ]))

        #expect(try line(store) == .init(identity: "Cigarettes", values: "3"))
    }

    /// The mirror of the test above, and the case it got wrong: dropping the
    /// prefix is only safe while the identity line is the tracker's name. Once
    /// the user has typed one, nothing else on the row says what was counted.
    @Test("A lone unitless number keeps its tracker's name under a typed one")
    func lineKeepsTheTrackerUnderAName() throws {
        let cigarettes = Tracker(name: "Cigarettes")
        let store = historyStore(StoreDocument(trackers: [cigarettes], entries: [
            Entry(trackerID: cigarettes.id, value: 3, date: time(10), name: "after lunch"),
        ]))

        #expect(try line(store) == .init(identity: "after lunch", values: "Cigarettes: 3"))
    }

    @Test("A named row whose tracker is gone still says the tracker is gone")
    func lineForANamedDeletedTracker() throws {
        let store = historyStore(StoreDocument(trackers: [], entries: [
            Entry(trackerID: UUID(), value: 3, date: time(10), name: "after lunch"),
        ]))

        #expect(try line(store) == .init(identity: "after lunch", values: "Deleted tracker: 3"))
    }

    /// A name must not start printing a prefix that was never needed: with a
    /// unit doing the telling-apart, the values line stays exactly as it was.
    @Test("A named lone entry with a unit is unchanged")
    func lineForANamedSingleWithAUnit() throws {
        let calories = Tracker(name: "Calories", unit: "kcal", group: "Food")
        let store = historyStore(StoreDocument(trackers: [calories], entries: [
            Entry(trackerID: calories.id, value: 90, date: time(10), name: "flat white"),
        ]))

        #expect(try line(store) == .init(identity: "flat white", values: "90 kcal"))
    }

    @Test("Members that share a unit are still told apart inside a batch")
    func lineNamesAmbiguousMembers() throws {
        let eaten = Tracker(name: "Calories", unit: "kcal", group: "Food")
        let burned = Tracker(name: "Calories burned", unit: "kcal", sortIndex: 1, group: "Food")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [eaten, burned], entries: [
            Entry(trackerID: eaten.id, value: 320, date: time(10), batchID: batch),
            Entry(trackerID: burned.id, value: 410, date: time(10), batchID: batch),
        ]))

        #expect(try line(store) == .init(
            identity: "Food", values: "Calories: 320 kcal, Calories burned: 410 kcal"
        ))
    }

    @Test("A row whose tracker is gone says so on the line that identifies it")
    func lineForADeletedTracker() throws {
        let store = historyStore(StoreDocument(trackers: [], entries: [
            Entry(trackerID: UUID(), value: 3, date: time(10)),
        ]))

        #expect(try line(store) == .init(identity: "Deleted tracker", values: "3"))
    }

    @Test("A batch that half survives names the survivor and flags the rest")
    func lineForAPartlyDeletedBatch() throws {
        let protein = Tracker(name: "Protein", unit: "g", group: "Food")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [protein], entries: [
            Entry(trackerID: UUID(), value: 100, date: time(10), batchID: batch),
            Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch),
        ]))

        #expect(try line(store) == .init(
            identity: "Protein", values: "10 g, Deleted tracker: 100"
        ))
    }

    /// Fixed ids, not `UUID()`: with every tracker gone they all sort at
    /// `.max`, so the row's order falls through to the ids themselves and a
    /// random pair makes the expectation a coin toss. `…AA` sorts before `…BB`.
    private var ghosts: (UUID, UUID) {
        (UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
         UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!)
    }

    /// Two taps in settings reach this: the deletion that keeps the history,
    /// applied to both members of a group.
    @Test("A batch whose trackers are all gone says so once, not three times")
    func lineForAWhollyDeletedBatch() throws {
        let (first, second) = ghosts
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [], entries: [
            Entry(trackerID: first, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: second, value: 10, date: time(10), batchID: batch),
        ]))

        #expect(try line(store) == .init(identity: "Deleted tracker", values: "100, 10"))
    }

    /// …but a name of your own on the row leaves nothing else to say it, so
    /// each value carries it rather than none of them.
    @Test("A named batch whose trackers are all gone still says they are gone")
    func lineForANamedWhollyDeletedBatch() throws {
        let (first, second) = ghosts
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [], entries: [
            Entry(trackerID: first, value: 100, date: time(10), name: "lunch", batchID: batch),
            Entry(trackerID: second, value: 10, date: time(10), name: "lunch", batchID: batch),
        ]))

        #expect(try line(store) == .init(
            identity: "lunch", values: "Deleted tracker: 100, Deleted tracker: 10"
        ))
    }

    @Test("A batch spanning groups lists its trackers rather than picking one")
    func lineForABatchSpanningGroups() throws {
        let calories = Tracker(name: "Calories", unit: "kcal", group: "Food")
        let weight = Tracker(name: "Weight", unit: "kg", decimals: 1, sortIndex: 1,
                             group: "Weight")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [calories, weight], entries: [
            Entry(trackerID: calories.id, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: weight.id, value: 78.4, date: time(10), batchID: batch),
        ]))

        #expect(try line(store) == .init(
            identity: "Calories, Weight", values: "100 kcal, 78.4 kg"
        ))
    }

    @Test("Members that disagree about the name still say so on the first line")
    func lineForMixedNames() throws {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [tracker], entries: [
            Entry(trackerID: tracker.id, value: 1, date: time(10), name: "rice", batchID: batch),
            Entry(trackerID: tracker.id, value: 2, date: time(20), name: "beans", batchID: batch),
        ]))

        #expect(try line(store).identity == "Mixed names")
    }

    @Test("Saving a batch does not restamp the members that did not change")
    func batchEditStampsOnlyWhatChanged() {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        let first = Entry(trackerID: calories.id, value: 100, date: time(10),
                          batchID: batch, modified: time(1))
        let second = Entry(trackerID: protein.id, value: 10, date: time(10),
                           batchID: batch, modified: time(1))
        let store = historyStore(
            StoreDocument(trackers: [calories, protein], entries: [first, second])
        )
        var edited = [first, second]
        edited[0].value = 200      // the batch editor always submits both members

        #expect(store.update(edited))

        let stamps = Dictionary(uniqueKeysWithValues: store.entries.map { ($0.id, $0.modified) })
        // A no-op rewrite of the protein entry must not outrank — and so
        // silently discard — a real edit to it made on another device.
        #expect(stamps[second.id] == time(1))
        #expect(stamps[first.id]! > time(1))
    }

    @Test("Deleting one tracker with its history leaves another tracker's undo alone")
    func deleteWithHistoryKeepsAnUnrelatedUndo() {
        let calories = Tracker(name: "Calories")
        let weight = Tracker(name: "Weight", kind: .measurement)
        let logged = Entry(trackerID: calories.id, value: 100, date: time(10))
        let reading = Entry(trackerID: weight.id, value: 78, date: time(20))
        let store = historyStore(
            StoreDocument(trackers: [calories, weight], entries: [logged, reading])
        )

        store.delete(logged)
        store.deleteWithHistory(weight)
        store.undoLastDeletion()

        // The weight deletion never touched the calories entry, so its undo
        // still stands; the weight reading stays gone.
        #expect(store.entries == [logged])
    }

    // MARK: - Logging a row again

    @Test("Repeating a batch writes a new batch and leaves the old one alone")
    func repeatBatchWritesRatherThanEdits() throws {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        let first = Entry(trackerID: calories.id, value: 100, date: time(10),
                          name: "chicken rice", batchID: batch)
        let second = Entry(trackerID: protein.id, value: 10, date: time(10),
                           name: "chicken rice", batchID: batch)
        let store = historyStore(
            StoreDocument(trackers: [calories, protein], entries: [first, second])
        )
        let before = Date()

        let item = try #require(store.historyItems.first)
        #expect(store.logAgain(item))

        // The row that was tapped is untouched — same ids, same values, same
        // date, same batch. Repeating is a write, never an edit.
        let originals = store.entries.filter { $0.batchID == batch }
        #expect(originals.map(\.id).sorted() == [first, second].map(\.id).sorted())
        #expect(originals.allSatisfy { $0.date == time(10) })

        let written = store.entries.filter { $0.batchID != batch }
        #expect(written.count == 2)
        // One new batch, shared by both members, and not the old one's.
        let newBatch = try #require(written.first?.batchID)
        #expect(newBatch != batch)
        #expect(written.allSatisfy { $0.batchID == newBatch })
        #expect(written.allSatisfy { $0.date >= before.canonicalized })
        #expect(written.allSatisfy { $0.name == "chicken rice" })
        #expect(Set(written.map(\.trackerID)) == [calories.id, protein.id])
        #expect(written.map(\.value).sorted() == [10, 100])
        // Values land in the totals index, not just the entry list: a repeat
        // that does not move the number on the home screen has not logged
        // anything as far as the user is concerned.
        #expect(store.total(for: calories.id, on: store.today) == 100)
    }

    @Test("Repeating a single entry takes the same path as repeating a batch")
    func repeatSingleEntry() throws {
        let calories = Tracker(name: "Calories")
        let loose = Entry(trackerID: calories.id, value: 250, date: time(10), name: "apple")
        let store = historyStore(StoreDocument(trackers: [calories], entries: [loose]))

        let item = try #require(store.historyItems.first)
        #expect(store.logAgain(item))

        let written = try #require(store.entries.first { $0.id != loose.id })
        #expect(written.value == 250)
        #expect(written.name == "apple")
        // A one-member row still gets a batch id. What was logged together is a
        // property of the log, not of how many trackers it touched — and it is
        // what makes the new row deletable and editable as one thing.
        #expect(written.batchID != nil)
        #expect(store.lastLoggedAgain == Store.LoggedAgain(count: 1, skipped: 0))
    }

    @Test("Undoing a repeat removes exactly what it wrote, and no tombstone")
    func undoRepeat() throws {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        let entries = [
            Entry(trackerID: calories.id, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch),
        ]
        let store = historyStore(
            StoreDocument(trackers: [calories, protein], entries: entries)
        )

        let item = try #require(store.historyItems.first)
        #expect(store.logAgain(item))
        #expect(store.entries.count == 4)

        store.undoLastLog()

        #expect(store.entries.map(\.id).sorted() == entries.map(\.id).sorted())
        #expect(store.total(for: calories.id, on: store.today) == 0)
        // Unmade, not deleted: a tombstone would carry "never allow this id
        // again" into every future merge for a log that lasted two seconds.
        #expect(store.tombstones.isEmpty)
        #expect(store.lastLoggedAgain == nil)
        // And it is not repeatable: a second undo must not eat the original.
        store.undoLastLog()
        #expect(store.entries.count == 2)
    }

    @Test("One undo slot: a repeat displaces a pending deletion undo")
    func repeatTakesTheUndoSlot() throws {
        let calories = Tracker(name: "Calories")
        let older = Entry(trackerID: calories.id, value: 100, date: time(10))
        let newer = Entry(trackerID: calories.id, value: 200, date: time(20))
        let store = historyStore(StoreDocument(trackers: [calories], entries: [older, newer]))

        store.delete(older)
        #expect(store.lastDeletion == older)

        let item = try #require(store.historyItems.first { $0.entries.first?.id == newer.id })
        #expect(store.logAgain(item))

        // The deletion stops being offered rather than sitting behind the same
        // Undo button with a second meaning.
        #expect(store.lastDeletion == nil)
        #expect(store.lastLoggedAgain?.count == 1)

        store.undoLastLog()
        // Undoing the repeat does not resurrect the deleted entry either.
        #expect(store.entries == [newer])
    }

    @Test("A row whose trackers are all gone or archived cannot be repeated")
    func repeatRefusesAnUnrepeatableRow() throws {
        let deleted = Tracker(name: "Calories")
        let archived = Tracker(name: "Protein", isArchived: true)
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [deleted, archived], entries: [
            Entry(trackerID: deleted.id, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: archived.id, value: 10, date: time(10), batchID: batch),
        ]))
        // Deleted with its history kept, which is a supported choice and leaves
        // entries behind pointing at nothing.
        store.delete(deleted)

        let item = try #require(store.historyItems.first)
        #expect(store.repeatableEntries(of: item).isEmpty)
        #expect(store.logAgain(item) == false)
        #expect(store.entries.count == 2)
        // A refused repeat writes nothing, so it must not claim the undo slot.
        #expect(store.lastLoggedAgain == nil)
    }

    @Test("A batch mixing live and deleted trackers repeats the live part and says so")
    func repeatPartialBatch() throws {
        let live = Tracker(name: "Calories")
        let gone = Tracker(name: "Protein")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [live, gone], entries: [
            Entry(trackerID: live.id, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: gone.id, value: 10, date: time(10), batchID: batch),
        ]))
        store.delete(gone)

        let item = try #require(store.historyItems.first)
        #expect(store.logAgain(item))

        let written = store.entries.filter { $0.batchID != batch }
        #expect(written.map(\.value) == [100])
        #expect(written.allSatisfy { $0.trackerID == live.id })
        // The count is the honest part: the tap promised the row and wrote less
        // than the row, so the screen has to be able to say which.
        #expect(store.lastLoggedAgain == Store.LoggedAgain(count: 1, skipped: 1))
    }

    @Test("Deleting a tracker with its history withdraws a repeat's undo for it")
    func deleteWithHistoryInvalidatesRepeatUndo() throws {
        let calories = Tracker(name: "Calories")
        let weight = Tracker(name: "Weight", kind: .measurement)
        let logged = Entry(trackerID: calories.id, value: 100, date: time(10))
        let reading = Entry(trackerID: weight.id, value: 78, date: time(20))
        let store = historyStore(
            StoreDocument(trackers: [calories, weight], entries: [logged, reading])
        )

        let item = try #require(store.historyItems.first { $0.entries.first?.id == reading.id })
        #expect(store.logAgain(item))
        store.deleteWithHistory(weight)
        store.undoLastLog()

        // Nothing left to take back, and nothing else disturbed.
        #expect(store.lastLoggedAgain == nil)
        #expect(store.entries == [logged])
    }

    @Test("A repeat's undo survives a deletion that never touched its trackers")
    func deleteWithHistoryKeepsAnUnrelatedRepeatUndo() throws {
        let calories = Tracker(name: "Calories")
        let weight = Tracker(name: "Weight", kind: .measurement)
        let logged = Entry(trackerID: calories.id, value: 100, date: time(10))
        let reading = Entry(trackerID: weight.id, value: 78, date: time(20))
        let store = historyStore(
            StoreDocument(trackers: [calories, weight], entries: [logged, reading])
        )

        let item = try #require(store.historyItems.first { $0.entries.first?.id == logged.id })
        #expect(store.logAgain(item))
        store.deleteWithHistory(weight)
        store.undoLastLog()

        #expect(store.entries == [logged])
    }

    @Test("Logging through the sheet ends the offer to undo an earlier repeat")
    func aLaterLogWithdrawsTheRepeatUndo() throws {
        let calories = Tracker(name: "Calories")
        let source = Entry(trackerID: calories.id, value: 100, date: time(10), name: "rice")
        let store = historyStore(StoreDocument(trackers: [calories], entries: [source]))

        #expect(store.logAgain(try #require(store.historyItems.first)))
        let repeated = try #require(store.entries.first { $0.id != source.id })
        store.add(values: [calories.id: 700], name: "dinner")

        // The bar cannot go on saying "Logged again" over a screen whose newest
        // row is the log just made: tapping it would delete the repeat, with no
        // tombstone and nothing to recover it from.
        #expect(store.lastLoggedAgain == nil)
        store.undoLastLog()
        #expect(store.entries.count == 3)
        #expect(store.entries.contains { $0.id == repeated.id })
    }

    @Test("A later log does not withdraw a pending deletion undo")
    func aLaterLogKeepsTheDeletionUndo() {
        let calories = Tracker(name: "Calories")
        let entry = Entry(trackerID: calories.id, value: 100, date: time(10))
        let store = historyStore(StoreDocument(trackers: [calories], entries: [entry]))

        store.delete(entry)
        store.add(values: [calories.id: 700])

        // The two slots are not symmetric. Undoing a deletion only puts records
        // back, so it costs nothing to leave standing — and tracker detail's
        // undo row surviving a log made while it is on screen is the forgiving
        // behaviour that already shipped.
        #expect(store.lastDeletion == entry)
        store.undoLastDeletion()
        #expect(store.entries.count == 2)
        #expect(store.entries.contains { $0.id == entry.id })
    }

    @Test("Editing the batch a repeat wrote ends the offer to undo it")
    func editingARepeatWithdrawsItsUndo() throws {
        let calories = Tracker(name: "Calories")
        let source = Entry(trackerID: calories.id, value: 100, date: time(10))
        let store = historyStore(StoreDocument(trackers: [calories], entries: [source]))

        #expect(store.logAgain(try #require(store.historyItems.first)))
        var repeated = try #require(store.entries.first { $0.id != source.id })
        repeated.value = 350
        #expect(store.update([repeated]))

        // Undo removes by id, so a surviving offer would take the edit away
        // with the entry it was made on.
        #expect(store.lastLoggedAgain == nil)
        store.undoLastLog()
        #expect(store.entries.first { $0.id == repeated.id }?.value == 350)
    }

    @Test("Saving a batch without changing it keeps the offer to undo a repeat")
    func aNoOpSaveKeepsTheRepeatUndo() throws {
        let calories = Tracker(name: "Calories")
        let source = Entry(trackerID: calories.id, value: 100, date: time(10))
        let store = historyStore(StoreDocument(trackers: [calories], entries: [source]))

        #expect(store.logAgain(try #require(store.historyItems.first)))
        let repeated = try #require(store.entries.first { $0.id != source.id })
        // Opening the row a repeat wrote to check the number and closing it
        // again is not a newer write, by the same test that decides whether a
        // member gets a fresh stamp.
        #expect(store.update([repeated]))

        #expect(store.lastLoggedAgain == Store.LoggedAgain(count: 1, skipped: 0))
        store.undoLastLog()
        #expect(store.entries.map(\.id) == [source.id])
    }

    @Test("Deleting the row a repeat came from leaves the repeat, and undoes the deletion")
    func deletingTheSourceRowAfterARepeat() throws {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        let sources = [
            Entry(trackerID: calories.id, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch),
        ]
        let store = historyStore(
            StoreDocument(trackers: [calories, protein], entries: sources)
        )

        #expect(store.logAgain(try #require(store.historyItems.first)))
        let written = store.entries.filter { $0.batchID != batch }
        #expect(written.count == 2)

        // Swiping the row that was tapped: a deletion is the newer write, so it
        // takes the slot, and undoing it puts that row back rather than
        // unmaking the repeat.
        store.deleteBatch(containing: sources[0])
        #expect(store.lastLoggedAgain == nil)
        #expect(store.lastDeletionCount == 2)
        store.undoLastDeletion()

        #expect(store.entries.count == 4)
        #expect(Set(store.entries.map(\.id)) ==
                Set(sources.map(\.id) + written.map(\.id)))
        #expect(store.tombstones.isEmpty)
    }

    @Test("A repeat that loses one member to a tracker deletion drops its undo whole")
    func partiallyGuttedRepeatDropsItsUndo() throws {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [calories, protein], entries: [
            Entry(trackerID: calories.id, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch),
        ]))

        #expect(store.logAgain(try #require(store.historyItems.first)))
        #expect(store.lastLoggedAgain == Store.LoggedAgain(count: 2, skipped: 0))
        store.deleteWithHistory(protein)

        // Half the write is gone, and there is no honest way to restate the two
        // numbers the bar shows — so it stops offering rather than describing a
        // row that never existed.
        #expect(store.lastLoggedAgain == nil)
        // What it wrote to the surviving tracker stays written — withdrawing
        // the offer is not undoing the repeat.
        #expect(store.entries.count == 2)
        #expect(store.entries.allSatisfy { $0.trackerID == calories.id })
    }

    @Test("A repeat is one history row, not one row per value")
    func repeatIsOneRow() throws {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let batch = UUID()
        let store = historyStore(StoreDocument(trackers: [calories, protein], entries: [
            Entry(trackerID: calories.id, value: 100, date: time(10), batchID: batch),
            Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch),
        ]))

        #expect(store.logAgain(try #require(store.historyItems.first)))

        #expect(store.historyItems.count == 2)
        #expect(store.historyItems.allSatisfy { $0.entries.count == 2 })
    }
}
