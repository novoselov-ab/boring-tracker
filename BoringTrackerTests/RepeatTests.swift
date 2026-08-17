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

    @Test("The same name at the same values is one row, a bigger portion is its own")
    func dedupesByNameAndValues() throws {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 100, date: time(10), name: "rice"),
                    Entry(trackerID: tracker.id, value: 160, date: time(20), name: "rice"),
                    Entry(trackerID: tracker.id, value: 100, date: time(30), name: "rice"),
                    Entry(trackerID: tracker.id, value: 100, date: time(40), name: "rice"),
                ]
            )
        )

        let items = store.repeatItems
        // Two things you ate, not four rows and not one: the bigger portion is
        // a separate row rather than something hidden behind the last log.
        #expect(items.map(\.displayName) == ["rice", "rice"])
        #expect(items.map { $0.entries.map(\.value) } == [[100], [160]])
        // The row kept is the newest of the ones it collapsed, so its date says
        // when you last ate that — 40, not the 10 or 30 it stands for.
        #expect(items.first?.date == time(40))
    }

    @Test("What you log most is first, and a one-off does not outrank it")
    func frequencyOrdering() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 320, date: time(10), name: "porridge"),
                    Entry(trackerID: tracker.id, value: 320, date: time(20), name: "porridge"),
                    Entry(trackerID: tracker.id, value: 320, date: time(30), name: "porridge"),
                    // Eaten once, and eaten last. On a recency list this would
                    // be the top row every time; here it sits under the thing
                    // actually eaten every day.
                    Entry(trackerID: tracker.id, value: 890, date: time(40), name: "pizza"),
                ]
            )
        )

        #expect(store.repeatItems.map(\.displayName) == ["porridge", "pizza"])
        // The frequent row still carries its own latest date, so the screen can
        // say when it was last eaten.
        #expect(store.repeatItems.first?.date == time(30))
    }

    @Test("With nothing to count, frequency is recency")
    func frequencyTiesBreakOnRecency() {
        let tracker = Tracker(name: "Calories", unit: "kcal", decimals: 1)
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    // Someone who weighs food to the gram: the same meal, never
                    // the same number, so nothing collapses and every count is
                    // 1. The ordering has to degrade into the recency list
                    // rather than into an arbitrary one.
                    Entry(trackerID: tracker.id, value: 618.4, date: time(10), name: "rice"),
                    Entry(trackerID: tracker.id, value: 621.1, date: time(20), name: "rice"),
                    Entry(trackerID: tracker.id, value: 619.7, date: time(30), name: "rice"),
                ]
            )
        )

        #expect(store.repeatItems.map { $0.entries.map(\.value) } == [[619.7], [621.1], [618.4]])
    }

    @Test("The same values under different names stay apart")
    func namesSeparateRows() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 300, date: time(10), name: "porridge"),
                    Entry(trackerID: tracker.id, value: 300, date: time(20), name: "toast"),
                ]
            )
        )

        #expect(store.repeatItems.map(\.displayName) == ["toast", "porridge"])
    }

    @Test("The same number on a different tracker is a different log")
    func trackersSeparateRows() {
        let calories = Tracker(name: "Calories", unit: "kcal")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1)
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, protein],
                entries: [
                    Entry(trackerID: calories.id, value: 20, date: time(10), name: "snack"),
                    Entry(trackerID: protein.id, value: 20, date: time(20), name: "snack"),
                ]
            )
        )

        // A value is a number *against a tracker*. Collapsing these would say
        // 20 kcal and 20 g are the same thing to log again.
        #expect(store.repeatItems.count == 2)
    }

    @Test("A batch collapses whatever order its members were written in")
    func batchMemberOrder() {
        let calories = Tracker(name: "Calories", unit: "kcal")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1)
        let first = UUID()
        let second = UUID()
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, protein],
                entries: [
                    Entry(
                        trackerID: calories.id, value: 100, date: time(10),
                        name: "chicken rice", batchID: first
                    ),
                    Entry(
                        trackerID: protein.id, value: 10, date: time(11),
                        name: "chicken rice", batchID: first
                    ),
                    // The same meal, its members stamped the other way round —
                    // which a repeat can produce, since it writes each member
                    // in the order the row happened to hold them.
                    Entry(
                        trackerID: protein.id, value: 10, date: time(20),
                        name: "chicken rice", batchID: second
                    ),
                    Entry(
                        trackerID: calories.id, value: 100, date: time(21),
                        name: "chicken rice", batchID: second
                    ),
                ]
            )
        )

        #expect(store.repeatItems.count == 1)
    }

    @Test("A batch is not the same row as one of its members logged alone")
    func partialBatch() {
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
                    // The day the protein went unlogged. Repeating this writes
                    // one number, and repeating the row above writes two, so
                    // the screen has to offer both.
                    Entry(trackerID: calories.id, value: 100, date: time(20), name: "chicken rice"),
                ]
            )
        )

        #expect(store.repeatItems.map { $0.entries.count } == [1, 2])
    }

    @Test("Deduplication does not collapse rows a search would match together")
    func exactNames() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 90, date: time(10), name: "Porridge"),
                    Entry(trackerID: tracker.id, value: 90, date: time(20), name: "porridge"),
                ]
            )
        )
        let items = store.repeatItems

        // Search folds case, and this does not: search decides what you are
        // shown, deduplication decides what is *hidden behind* a row, and a row
        // that swallowed the wrong one would be invisible from the screen.
        #expect(items.count == 2)
        #expect(items.filter { $0.matches("porridge") }.count == 2)
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
