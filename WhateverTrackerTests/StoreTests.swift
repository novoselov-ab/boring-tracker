import Foundation
import Testing
@testable import WhateverTracker

@MainActor
@Suite("Store")
struct StoreTests {

    let utc = calendar("UTC")

    private func makeStore(
        _ document: StoreDocument = StoreDocument(),
        file: StoreFile? = nil,
        window: Duration = .milliseconds(10)
    ) -> Store {
        Store(
            document: document,
            file: file ?? temporaryStoreFile(),
            calendar: utc,
            saveWindow: window
        )
    }

    // MARK: - The totals index

    @Test("Logging a number adds it to today's total")
    func addingUpdatesTotals() {
        let tracker = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [tracker]))
        let day = DayKey(year: 2026, month: 3, day: 14)

        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        store.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))

        #expect(store.total(for: tracker.id, on: day) == 850)
    }

    @Test("Editing an entry's date moves its value to the other day")
    func editingMovesValueBetweenDays() {
        let tracker = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [tracker]))
        let dinner = Entry(trackerID: tracker.id, value: 800, date: date(2026, 3, 14, 20))
        store.add(dinner)

        var corrected = dinner
        corrected.date = date(2026, 3, 13, 20)
        store.update(corrected)

        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 0)
        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 13)) == 800)
    }

    @Test("Editing the value updates the total by the difference")
    func editingValueUpdatesTotal() {
        let tracker = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [tracker]))
        var entry = Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8))
        store.add(entry)
        store.add(Entry(trackerID: tracker.id, value: 100, date: date(2026, 3, 14, 9)))

        entry.value = 650
        store.update(entry)

        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 750)
    }

    @Test("Deleting takes the value back out and remembers the deletion")
    func deletingUpdatesTotalsAndTombstones() {
        let tracker = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [tracker]))
        let entry = Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8))
        store.add(entry)

        store.delete(entry)

        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 0)
        #expect(store.entries.isEmpty)
        #expect(store.tombstones.map(\.id) == [entry.id])
    }

    @Test("The incremental index always agrees with a full recount",
          arguments: 1...25 as ClosedRange<UInt64>)
    func indexMatchesRecount(seed: UInt64) {
        var random = SeededRandom(seed: seed)
        let trackers = (0..<3).map { Tracker(name: "T\($0)", decimals: 1) }
        let store = makeStore(StoreDocument(trackers: trackers))

        // Deliberately includes zero and fractional values: a day that adds up
        // to zero must still count as a day with entries in it, and decimals
        // are what make an exact comparison of running sums impossible.
        func value() -> Double { Double(Int.random(in: -1_000...9_000, using: &random)) / 10 }
        func moment() -> Date {
            date(2026, 3, Int.random(in: 10...16, using: &random),
                 Int.random(in: 0...23, using: &random))
        }

        for _ in 0..<60 {
            switch Int.random(in: 0...3, using: &random) {
            case 0 where !store.entries.isEmpty:
                store.delete(store.entries.randomElement(using: &random)!)
            case 1 where !store.entries.isEmpty:
                var entry = store.entries.randomElement(using: &random)!
                entry.value = value()
                entry.date = moment()
                store.update(entry)
            default:
                store.add(Entry(
                    trackerID: trackers.randomElement(using: &random)!.id,
                    value: Bool.random(using: &random) ? 0 : value(),
                    date: moment()
                ))
            }
        }

        let incremental = store.totals
        store.rebuildTotals()

        #expect(Set(incremental.keys) == Set(store.totals.keys))
        for (key, recounted) in store.totals {
            // Running sums of decimals drift; the index is rebuilt at every
            // launch, so what matters is that a session's worth of arithmetic
            // stays far below anything a formatted number could show.
            #expect(abs((incremental[key] ?? .nan) - recounted) < 1e-9)
        }
    }

    @Test("Entries stay in chronological order however they arrive")
    func entriesStaySorted() {
        let tracker = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [tracker]))

        for day in [14, 11, 16, 12, 15, 13] {
            store.add(Entry(trackerID: tracker.id, value: 1, date: date(2026, 3, day, 12)))
        }

        #expect(store.entries.map { DayKey($0.date, calendar: utc).day } == [11, 12, 13, 14, 15, 16])
    }

    // MARK: - Trackers

    @Test("One meal logs against several trackers at the same moment")
    func multiTrackerEntry() {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let store = makeStore(StoreDocument(trackers: [calories, protein]))

        store.add(values: [calories.id: 450, protein.id: 30], at: date(2026, 3, 14, 8), note: "eggs")

        #expect(store.entries.count == 2)
        #expect(Set(store.entries.map(\.date)).count == 1)
        #expect(store.total(for: calories.id, on: DayKey(year: 2026, month: 3, day: 14)) == 450)
        #expect(store.total(for: protein.id, on: DayKey(year: 2026, month: 3, day: 14)) == 30)
        #expect(store.entries.allSatisfy { $0.note == "eggs" })
    }

    @Test("Deleting a tracker keeps its history by default")
    func deletingTrackerKeepsEntries() {
        let tracker = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [tracker]))
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))

        store.delete(tracker)

        #expect(store.trackers.isEmpty)
        #expect(store.entries.count == 1)
    }

    @Test("Deleting with history tombstones every entry too")
    func deletingWithHistory() {
        let tracker = Tracker(name: "Calories")
        let other = Tracker(name: "Protein")
        let store = makeStore(StoreDocument(trackers: [tracker, other]))
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        store.add(Entry(trackerID: other.id, value: 30, date: date(2026, 3, 14, 8)))

        store.deleteWithHistory(tracker)

        #expect(store.trackers.map(\.name) == ["Protein"])
        #expect(store.entries.count == 1)
        #expect(store.tombstones.count == 2)
        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 0)
    }

    @Test("Reordering renumbers the trackers and stamps the ones that moved")
    func reordering() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "A", sortIndex: 0, modified: time(1)),
            Tracker(name: "B", sortIndex: 1, modified: time(1)),
            Tracker(name: "C", sortIndex: 2, modified: time(1)),
        ]))

        store.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(store.trackers.map(\.name) == ["C", "A", "B"])
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2])
        #expect(store.trackers.allSatisfy { $0.modified > time(1) })
    }

    @Test("Measurement trackers show the last reading")
    func latestReading() {
        let weight = Tracker(name: "Weight", kind: .measurement, decimals: 1)
        let other = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [weight, other]))
        store.add(Entry(trackerID: weight.id, value: 79.1, date: date(2026, 3, 12, 8)))
        store.add(Entry(trackerID: weight.id, value: 78.4, date: date(2026, 3, 14, 8)))
        store.add(Entry(trackerID: other.id, value: 600, date: date(2026, 3, 15, 8)))

        #expect(store.latestEntry(for: weight.id)?.value == 78.4)
    }

    // MARK: - Export and import

    @Test("Export then import into an empty store reproduces it exactly")
    func exportImportRoundTrip() throws {
        let calories = Tracker(name: "Calories", unit: "kcal", modified: time(1))
        let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
                             modified: time(1))
        let source = makeStore(StoreDocument(trackers: [calories, weight]))
        source.add(Entry(trackerID: calories.id, value: 600, date: date(2026, 3, 14, 8),
                         note: "breakfast"))
        source.add(Entry(trackerID: weight.id, value: 78.4, date: date(2026, 3, 14, 7)))
        source.delete(source.entries[0])
        source.add(Entry(trackerID: calories.id, value: 250, date: date(2026, 3, 14, 13)))

        let exported = try source.exportData()
        let destination = makeStore()
        try destination.importData(exported, mode: .replace)

        #expect(destination.document == source.document)
        #expect(destination.totals == source.totals)
    }

    @Test("Importing an old backup does not resurrect what you have since deleted")
    func mergeImportRespectsDeletions() throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let old = makeStore(StoreDocument(trackers: [tracker]))
        old.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        old.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))
        let backup = try old.exportData()

        // The same store, later: one of those was a mistake and got deleted.
        old.delete(old.entries[0])
        #expect(old.entries.count == 1)

        let summary = try old.importData(backup, mode: .merge)

        #expect(old.entries.count == 1)
        #expect(summary == Store.ImportSummary(trackersAdded: 0, entriesAdded: 0, entriesRemoved: 0))
    }

    @Test("Merging a second device's export adds its entries and keeps yours")
    func mergeImportUnionsTwoDevices() throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let phone = makeStore(StoreDocument(trackers: [tracker]))
        phone.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))

        let tablet = makeStore(StoreDocument(trackers: [tracker]))
        tablet.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))

        let summary = try phone.importData(try tablet.exportData(), mode: .merge)

        #expect(phone.entries.count == 2)
        #expect(phone.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 850)
        #expect(summary == Store.ImportSummary(trackersAdded: 0, entriesAdded: 1, entriesRemoved: 0))
    }

    @Test("Replace really replaces, and says how much it removed")
    func replaceImport() throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let incoming = makeStore(StoreDocument(trackers: [tracker]))
        incoming.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))
        let file = try incoming.exportData()

        let store = makeStore(StoreDocument(trackers: [tracker]))
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        store.add(Entry(trackerID: tracker.id, value: 700, date: date(2026, 3, 14, 9)))

        let summary = try store.importData(file, mode: .replace)

        #expect(store.entries.map(\.value) == [250])
        #expect(summary == Store.ImportSummary(trackersAdded: 0, entriesAdded: 1, entriesRemoved: 2))
    }

    @Test("A junk file is refused without touching what is already there")
    func importRejectsJunk() throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]))
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        let before = store.document

        #expect(throws: (any Error).self) {
            try store.importData(Data("nope".utf8), mode: .replace)
        }
        #expect(store.document == before)
    }

    // MARK: - Saving

    @Test("A change reaches disk on its own, shortly")
    func changesAreSavedWithoutBeingAskedTo() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]), file: file)

        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))

        try await confirmEventually("the store is written") {
            (try? file.read(file.url))?.entries.count == 1
        }
    }

    @Test("Flushing writes immediately, so backgrounding cannot lose the last edit")
    func flushWritesAtOnce() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        // A window long enough that only the flush can explain the file existing.
        let store = makeStore(StoreDocument(trackers: [tracker]), file: file, window: .seconds(60))

        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        await store.flush()

        #expect(try file.read(file.url) == store.document)
        #expect(store.saveError == nil)
    }

    @Test("A burst of edits is coalesced into one document, and the last one wins")
    func rapidEditsCoalesce() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]), file: file, window: .seconds(60))

        for index in 0..<50 {
            store.add(Entry(trackerID: tracker.id, value: Double(index),
                            date: date(2026, 3, 14, 8, index)))
        }
        await store.flush()

        #expect(try file.read(file.url).entries.count == 50)
    }

    @Test("A store reloaded from its own file is the same store")
    func saveThenReload() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]), file: file)
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        store.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))
        await store.flush()

        let reloaded = Store(document: file.load().document, file: file, calendar: utc)

        #expect(reloaded.document == store.document)
        #expect(reloaded.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 850)
    }
}

/// Polls until the condition holds, rather than sleeping for a guessed
/// interval. Background writes are the one thing here that genuinely happens on
/// another executor, and a fixed sleep would be either slow or flaky.
func confirmEventually(
    _ description: Comment,
    within limit: Duration = .seconds(5),
    _ condition: @Sendable () async -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: limit)
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("timed out waiting for \(description)")
}
