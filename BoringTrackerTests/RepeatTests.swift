import Foundation
import Testing
@testable import BoringTracker

/// The Repeat screen's list, and the two questions it asks of a history row:
/// does it have a name, and does it match what was typed.
///
/// The writing half is item 14's `logAgain`, tested in `HistoryTests` — this
/// screen calls that and nothing else, which is the point of the item.
@MainActor
@Suite("Repeat")
struct RepeatTests {
    private func repeatStore(_ document: StoreDocument) -> Store {
        Store(
            document: document,
            file: StoreFile(directory: URL.temporaryDirectory.appending(path: "repeat-\(UUID())")),
            calendar: calendar("UTC"),
            saveWindow: .seconds(60)
        )
    }

    @Test("Only named rows are listed, newest first")
    func namedOnly() {
        let tracker = Tracker(name: "Calories")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 1, date: time(10), name: "porridge"),
                    Entry(trackerID: tracker.id, value: 2, date: time(20)),
                    Entry(trackerID: tracker.id, value: 3, date: time(30), name: "chicken rice"),
                    // An empty name is not a name. Nothing in the app writes
                    // one — the log sheet's field is optional and blank means
                    // absent — but an imported file can carry it.
                    Entry(trackerID: tracker.id, value: 4, date: time(40), name: ""),
                ]
            )
        )

        #expect(store.repeatItems.map(\.displayName) == ["chicken rice", "porridge"])
    }

    @Test("A batch is one row, and one named member is enough to list it")
    func batches() {
        let calories = Tracker(name: "Calories", unit: "kcal")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1)
        let batch = UUID()
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, protein],
                entries: [
                    Entry(
                        trackerID: calories.id, value: 100, date: time(10),
                        name: "chicken rice", batchID: batch
                    ),
                    // No name of its own: `displayName` is still "chicken rice",
                    // and the row is one row.
                    Entry(trackerID: protein.id, value: 10, date: time(10), batchID: batch),
                ]
            )
        )

        let items = store.repeatItems
        #expect(items.count == 1)
        #expect(items.first?.entries.count == 2)
        #expect(items.first?.displayName == "chicken rice")
    }

    @Test("A batch whose members were named apart is still one row, and listed")
    func mixedNames() {
        let calories = Tracker(name: "Calories", unit: "kcal")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1)
        let batch = UUID()
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, protein],
                entries: [
                    Entry(
                        trackerID: calories.id, value: 100, date: time(10),
                        name: "chicken", batchID: batch
                    ),
                    Entry(
                        trackerID: protein.id, value: 10, date: time(10),
                        name: "rice", batchID: batch
                    ),
                ]
            )
        )

        // "Mixed names" is what every other screen calls this row; the Repeat
        // screen does not get its own word for it.
        #expect(store.repeatItems.map(\.displayName) == ["Mixed names"])
    }

    @Test("A row whose trackers are all gone is listed, and cannot be repeated")
    func deletedTrackers() throws {
        let tracker = Tracker(name: "Calories")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 1, date: time(10), name: "porridge"),
                ]
            )
        )
        // The deletion that keeps the history — the supported choice that
        // leaves entries pointing at a tracker that is gone.
        store.delete(tracker)

        // Still a true statement about what was eaten, so it stays on the list;
        // the row draws its disc off, and the store refuses the write.
        #expect(store.repeatItems.count == 1)
        let item = try #require(store.repeatItems.first)
        #expect(store.repeatableEntries(of: item).isEmpty)
        #expect(store.logAgain(item) == false)
    }

    @Test("Search matches the names, not the tracker or the group")
    func search() {
        let tracker = Tracker(name: "Calories", group: "Food")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 1, date: time(10), name: "chicken rice"),
                    Entry(trackerID: tracker.id, value: 2, date: time(20), name: "Crème brûlée"),
                ]
            )
        )
        let items = store.repeatItems

        #expect(items.filter { $0.matches("rice") }.map(\.displayName) == ["chicken rice"])
        // Case- and diacritic-insensitive, which is what a name typed in a
        // hurry needs.
        #expect(items.filter { $0.matches("CREME") }.map(\.displayName) == ["Crème brûlée"])
        // The tracker is "Calories" in the group "Food" and neither is a name
        // anybody typed, so neither is searchable.
        #expect(items.filter { $0.matches("calories") }.isEmpty)
        #expect(items.filter { $0.matches("food") }.isEmpty)
        // An empty query, and one that is only spaces, are not a filter.
        #expect(items.filter { $0.matches("") }.count == 2)
        #expect(items.filter { $0.matches("  ") }.count == 2)
    }

    @Test("Repeating from this screen writes through the one code path")
    func repeatWrites() throws {
        let calories = Tracker(name: "Calories", unit: "kcal")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1)
        let batch = UUID()
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, protein],
                entries: [
                    Entry(
                        trackerID: calories.id, value: 100, date: time(10),
                        name: "chicken rice", batchID: batch
                    ),
                    Entry(
                        trackerID: protein.id, value: 10, date: time(10),
                        name: "chicken rice", batchID: batch
                    ),
                ]
            )
        )
        let before = store.entries

        #expect(store.logAgain(try #require(store.repeatItems.first)))

        // The original is untouched, values and names carry over, and the new
        // members share a batch id of their own.
        #expect(store.entries.count == 4)
        #expect(before.allSatisfy { old in store.entries.contains(old) })
        let written = store.entries.filter { entry in !before.contains { $0.id == entry.id } }
        #expect(written.map(\.value).sorted() == [10, 100])
        #expect(written.allSatisfy { $0.name == "chicken rice" })
        #expect(Set(written.compactMap(\.batchID)).count == 1)
        #expect(written.allSatisfy { $0.batchID != batch })
        #expect(store.lastLoggedAgain == Store.LoggedAgain(count: 2, skipped: 0))

        store.undoLastLog()
        #expect(store.entries.count == 2)
    }

    @Test("A day names itself the same way on both screens")
    func dayLabels() {
        let zone = calendar("UTC")
        let today = DayKey(date(2026, 8, 17), calendar: zone)

        #expect(today.label(today: today, calendar: zone) == "Today")
        #expect(
            DayKey(date(2026, 8, 16), calendar: zone).label(today: today, calendar: zone)
                == "Yesterday"
        )
        // Inside the current year the year is left off; outside it, it is the
        // only thing telling the two apart.
        let sameYear = DayKey(date(2026, 3, 14), calendar: zone)
            .label(today: today, calendar: zone)
        let otherYear = DayKey(date(2025, 3, 14), calendar: zone)
            .label(today: today, calendar: zone)
        #expect(!sameYear.contains("2026"))
        #expect(otherYear.contains("2025"))
    }
}
