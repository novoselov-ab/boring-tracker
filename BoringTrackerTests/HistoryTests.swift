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
    func replaceImportInvalidatesUndo() throws {
        let tracker = Tracker(name: "Calories")
        let entry = Entry(trackerID: tracker.id, value: 100, date: time(10))
        let store = historyStore(StoreDocument(trackers: [tracker], entries: [entry]))
        store.delete(entry)
        let replacement = StoreDocument(trackers: [tracker], entries: [entry])

        try store.importData(StoreCoding.encode(replacement), mode: .replace)
        store.undoLastDeletion()

        #expect(store.entries == [entry])
        #expect(store.lastDeletion == nil)
    }
}
