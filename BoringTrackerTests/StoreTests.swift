import Foundation
import Testing
@testable import BoringTracker

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

    @Test("Undoing a delete puts the entry back, tombstone and all")
    func undoDelete() {
        let tracker = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [tracker]))
        let entry = Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8))
        store.add(entry)
        store.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))
        let before = store.document

        store.delete(store.entries[0])
        store.undoLastDeletion()

        #expect(store.document == before)
        #expect(store.tombstones.isEmpty)
        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 850)
        #expect(store.lastDeletion == nil)
    }

    @Test("Undo with nothing to undo does nothing")
    func undoWithoutDelete() {
        let tracker = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [tracker]))
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        let before = store.document

        store.undoLastDeletion()

        #expect(store.document == before)
    }

    // MARK: - Trackers

    @Test("One meal logs against several trackers at the same moment")
    func multiTrackerEntry() {
        let calories = Tracker(name: "Calories")
        let protein = Tracker(name: "Protein")
        let store = makeStore(StoreDocument(trackers: [calories, protein]))

        store.add(values: [calories.id: 450, protein.id: 30], at: date(2026, 3, 14, 8), name: "eggs")

        #expect(store.entries.count == 2)
        #expect(Set(store.entries.map(\.date)).count == 1)
        #expect(store.total(for: calories.id, on: DayKey(year: 2026, month: 3, day: 14)) == 450)
        #expect(store.total(for: protein.id, on: DayKey(year: 2026, month: 3, day: 14)) == 30)
        #expect(store.entries.allSatisfy { $0.name == "eggs" })
        // One logged food, so one batch — that is what makes these two rows a
        // single thing to edit or delete later rather than two coincidences.
        #expect(Set(store.entries.map(\.batchID)).count == 1)
        #expect(store.entries.allSatisfy { $0.batchID != nil })
    }

    @Test("Two separate logs are two separate batches")
    func batchesAreNotShared() {
        let calories = Tracker(name: "Calories")
        let store = makeStore(StoreDocument(trackers: [calories]))

        store.add(values: [calories.id: 450], at: date(2026, 3, 14, 8), name: "eggs")
        store.add(values: [calories.id: 200], at: date(2026, 3, 14, 8), name: "toast")

        #expect(Set(store.entries.compactMap(\.batchID)).count == 2)
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

    @Test("Reordering renumbers the trackers and stamps the move, not the record")
    func reordering() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "A", sortIndex: 0, modified: time(1), orderModified: time(1)),
            Tracker(name: "B", sortIndex: 1, modified: time(1), orderModified: time(1)),
            Tracker(name: "C", sortIndex: 2, modified: time(1), orderModified: time(1)),
        ]))

        store.move(store.activeTrackers, fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(store.trackers.map(\.name) == ["C", "A", "B"])
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2])
        // All three moved, so all three carry a new position stamp — but none
        // of them was edited, so `modified` is untouched and cannot outrank
        // a real edit made on another device.
        #expect(store.trackers.allSatisfy { $0.orderModified > time(1) })
        #expect(store.trackers.allSatisfy { $0.modified == time(1) })
    }

    @Test("A drag on one device and a rename on another both survive the merge")
    func reorderAndRenameDoNotCompete() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, group: "Food",
                              modified: time(1), orderModified: time(1))
        let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, sortIndex: 2,
                             group: "Weight", modified: time(1), orderModified: time(1))
        let phone = makeStore(StoreDocument(trackers: [calories, protein, weight]))

        // The iPad renamed Weight at 10:00 and moved nothing.
        var renamed = weight
        renamed.name = "Bodyweight"
        renamed.unit = "lb"
        renamed.modified = time(2)
        let tablet = StoreDocument(trackers: [calories, protein, renamed])

        // At 10:05 the phone dragged Weight to the top and renamed nothing.
        phone.move(phone.activeTrackers, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        let merged = phone.document.merged(with: tablet)
        let result = merged.trackers.first { $0.id == weight.id }

        // The edit is not lost to the drag, and the drag is not lost to the
        // edit. This is the entire reason `orderModified` exists.
        #expect(result?.name == "Bodyweight")
        #expect(result?.unit == "lb")
        #expect(merged.trackers.map(\.name) == ["Bodyweight", "Calories", "Protein"])
    }

    @Test("Two devices that each reorder: the later drag wins the whole list")
    func concurrentReordersResolveWhole() {
        let x = Tracker(name: "X", modified: time(1))
        let y = Tracker(name: "Y", modified: time(1))
        let z = Tracker(name: "Z", modified: time(1))

        // Both devices started from X, Y, Z. The phone pulled Y to the top, and
        // the iPad — separately, five minutes later — pulled Z above Y. Each
        // drag settles the whole list, so it stamps every row, which is what
        // lets the later one win outright instead of the two interleaving.
        let phone = StoreDocument(trackers: [
            placed(y, 0, at: time(10)), placed(x, 1, at: time(10)), placed(z, 2, at: time(10)),
        ])
        let tablet = StoreDocument(trackers: [
            placed(x, 0, at: time(20)), placed(z, 1, at: time(20)), placed(y, 2, at: time(20)),
        ])

        let merged = phone.merged(with: tablet)

        // Stamping only the rows whose number changed left the rest carrying an
        // older stamp, so a merge took some rows from one device and some from
        // the other — two trackers at one index, in an order neither had shown.
        #expect(Set(merged.trackers.map(\.sortIndex)).count == merged.trackers.count)
        #expect(merged.trackers.map(\.name) == ["X", "Z", "Y"])
        #expect(phone.merged(with: tablet) == tablet.merged(with: phone))
    }

    /// A tracker as a reorder leaves it: at this index, stamped at this moment.
    private func placed(_ tracker: Tracker, _ index: Int, at time: Date) -> Tracker {
        var copy = tracker
        copy.sortIndex = index
        copy.orderModified = time
        return copy
    }

    @Test("A reorder merged against an untouched copy keeps the positions distinct")
    func mergeKeepsPositionsDistinct() {
        let calories = Tracker(name: "Calories", sortIndex: 0, modified: time(1),
                               orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, modified: time(1),
                              orderModified: time(1))
        let weight = Tracker(name: "Weight", sortIndex: 2, modified: time(1),
                             orderModified: time(1))
        let phone = makeStore(StoreDocument(trackers: [calories, protein, weight]))
        let tablet = StoreDocument(trackers: [calories, protein, weight])

        phone.move(phone.activeTrackers, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        let merged = phone.document.merged(with: tablet)

        // Resolving position per record rather than per field is what used to
        // produce two trackers at index 2, and an order neither device had ever
        // seen. Two devices that each add a tracker can still land on the same
        // index — nothing renumbers across a merge — and the `(sortIndex, id)`
        // sort settles that deterministically; this is the case that used to
        // break for trackers both sides already had.
        #expect(Set(merged.trackers.map(\.sortIndex)).count == merged.trackers.count)
        #expect(merged.trackers.map(\.name) == ["Weight", "Calories", "Protein"])
    }

    @Test("Adding a grouped tracker slots it beside its group without editing other records")
    func addingATrackerSlotsItBesideItsGroup() {
        // `orderModified` is set explicitly: left to default it would be now,
        // and every assertion below that a position was restamped would pass
        // whether or not `add` stamped anything.
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food",
                    modified: time(1), orderModified: time(1)),
            Tracker(name: "Weight", sortIndex: 1, group: "Weight",
                    modified: time(1), orderModified: time(1)),
        ]))
        let beforeModified = store.trackers.map(\.modified)

        store.add(Tracker(name: "Fiber", group: "Food"))

        // Renumbering stamps ordering, not content, so the insertion cannot
        // outrank an edit made on another device.
        #expect(store.trackers.map(\.name) == ["Calories", "Fiber", "Weight"])
        #expect([store.trackers[0].modified, store.trackers[2].modified] == beforeModified)
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2])
        // Weight was pushed down, so its position genuinely changed and has to
        // be stamped, or the other device keeps the index this one just took.
        #expect(store.trackers[2].orderModified > time(1))
    }

    @Test("A new tracker sits beside the visible part of its group, not an archived one")
    func addingATrackerIgnoresArchivedGroupMembers() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1)),
            Tracker(name: "Weight", sortIndex: 1, group: "Weight", modified: time(1)),
            Tracker(name: "Old protein", sortIndex: 2, isArchived: true, group: "Food",
                    modified: time(1)),
        ]))

        // Slotting beside the archived row would drop Fiber at the very end,
        // past the whole group it was supposed to sit next to.
        store.add(Tracker(name: "Fiber", group: "Food"))

        #expect(store.activeTrackers.map(\.name) == ["Calories", "Fiber", "Weight"])
    }

    @Test("Appending a tracker cannot discard a drag made on another device")
    func addingATrackerDoesNotClobberARemoteReorder() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, group: "Food",
                              modified: time(1), orderModified: time(1))
        let phone = makeStore(StoreDocument(trackers: [calories, protein]))

        // The iPad dragged Protein above Calories and told nobody yet.
        var movedProtein = protein
        movedProtein.sortIndex = 0
        movedProtein.orderModified = time(2)
        var movedCalories = calories
        movedCalories.sortIndex = 1
        movedCalories.orderModified = time(2)
        let tablet = StoreDocument(trackers: [movedProtein, movedCalories])

        // The phone only appended. Nothing already in the list moved, so it has
        // expressed no opinion about their order — restamping them here would
        // let this add outrank the drag and quietly undo it.
        phone.add(Tracker(name: "Steps"))
        #expect(phone.trackers.filter { $0.name != "Steps" }
            .allSatisfy { $0.orderModified == time(1) })

        let merged = phone.document.merged(with: tablet)
        #expect(merged.trackers.map(\.name) == ["Protein", "Calories", "Steps"])
    }

    @Test("Adding a tracker on one device cannot undo an edit made on another")
    func addingATrackerDoesNotClobberARemoteEdit() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1))
        let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, sortIndex: 1,
                             group: "Weight", modified: time(1))
        let phone = makeStore(StoreDocument(trackers: [calories, weight]))

        // The iPad renamed Weight first; the phone then merely added something.
        var renamed = weight
        renamed.name = "Bodyweight"
        renamed.unit = "lb"
        renamed.modified = time(2)
        let tablet = StoreDocument(trackers: [calories, renamed])

        phone.add(Tracker(name: "Steps"))
        let merged = phone.document.merged(with: tablet)

        #expect(merged.trackers.first { $0.id == weight.id }?.name == "Bodyweight")
        #expect(merged.trackers.first { $0.id == weight.id }?.unit == "lb")
        #expect(merged.trackers.map(\.name).contains("Steps"))
    }

    @Test("Dragging a row moves that row, even with archived trackers in between")
    func reorderingIgnoresHiddenTrackers() {
        // The list only drew A, C and D, so offset 2 means D — not the third
        // element of `trackers`, which is the archived one nobody can see.
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "A", sortIndex: 0, modified: time(1)),
            Tracker(name: "B", sortIndex: 1, isArchived: true, modified: time(1)),
            Tracker(name: "C", sortIndex: 2, modified: time(1)),
            Tracker(name: "D", sortIndex: 3, modified: time(1)),
        ]))

        store.move(store.activeTrackers, fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(store.activeTrackers.map(\.name) == ["D", "A", "C"])
        // The archived one keeps the slot it had rather than being dragged along.
        #expect(store.trackers.map(\.name) == ["D", "B", "A", "C"])
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2, 3])
    }

    @Test("Dragging within a run reorders its members without changing membership")
    func reorderingWithinAGroup() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 2, group: "Food",
                              modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [
            calories,
            Tracker(name: "Steps", sortIndex: 1,
                    modified: time(1), orderModified: time(1)),
            protein,
            Tracker(name: "Weight", sortIndex: 3, group: "Weight",
                    modified: time(1), orderModified: time(1)),
        ]))

        store.move(protein.id, onto: calories.id)

        #expect(store.trackers.map(\.name) == ["Protein", "Steps", "Calories", "Weight"])
        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [
            ["Protein", "Calories"], ["Steps"], ["Weight"],
        ])
        #expect(store.trackers.map(\.group) == ["Food", "", "Food", "Weight"])
        // Nothing moved groups, so nothing counts as edited.
        #expect(store.trackers.allSatisfy { $0.modified == time(1) })
        #expect(store.trackers.allSatisfy { $0.orderModified > time(1) })
    }

    @Test("Dragging a multi-member group downward keeps every member together")
    func movingAGroupDownAsAUnit() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, group: "Food",
                              modified: time(1), orderModified: time(1))
        let weight = Tracker(name: "Weight", sortIndex: 2, group: "Weight",
                             modified: time(1), orderModified: time(1))
        let cat = Tracker(name: "Cat weight", sortIndex: 3, group: "Weight",
                          modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [calories, protein, weight, cat]))

        store.move(calories.id, onto: weight.id)

        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [
            ["Weight", "Cat weight"], ["Calories", "Protein"],
        ])
        #expect(store.trackers.map(\.group) == ["Weight", "Weight", "Food", "Food"])
        #expect(store.trackers.allSatisfy { $0.modified == time(1) })
        #expect(store.trackers.allSatisfy { $0.orderModified > time(1) })
    }

    @Test("Dragging between runs moves a whole group past archived members")
    func movingAGroupAsAUnit() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 3, group: "Food",
                              modified: time(1), orderModified: time(1))
        let weight = Tracker(name: "Weight", sortIndex: 4, group: "Weight",
                             modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [
            calories,
            Tracker(name: "Old", sortIndex: 1, isArchived: true, group: "Food",
                    modified: time(1), orderModified: time(1)),
            Tracker(name: "Steps", sortIndex: 2,
                    modified: time(1), orderModified: time(1)),
            protein,
            weight,
        ]))

        // This is the old visible no-op: Weight is dropped on a member of Food.
        // It cannot split Food now, so the Weight block moves before it.
        store.move(weight.id, onto: protein.id)

        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [
            ["Weight"], ["Calories", "Protein"], ["Steps"],
        ])
        #expect(store.trackers.map(\.name) == ["Weight", "Calories", "Old", "Protein", "Steps"])
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2, 3, 4])
        #expect(store.trackers.allSatisfy { $0.modified == time(1) })
        #expect(store.trackers.allSatisfy { $0.orderModified > time(1) })
    }

    @Test("A downward group move follows displayed order when the target is split in storage")
    func movingDownOntoASplitGroupDoesNotSkipTheNextRun() {
        let weight = Tracker(name: "Weight", sortIndex: 0, group: "Weight",
                             modified: time(1), orderModified: time(1))
        let calories = Tracker(name: "Calories", sortIndex: 1, group: "Food",
                               modified: time(1), orderModified: time(1))
        let steps = Tracker(name: "Steps", sortIndex: 2,
                            modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 3, group: "Food",
                              modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [weight, calories, steps, protein]))

        store.move(weight.id, onto: calories.id)

        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [
            ["Calories", "Protein"], ["Weight"], ["Steps"],
        ])
        #expect(store.trackers.map(\.name) == ["Calories", "Protein", "Weight", "Steps"])
    }

    @Test("An archived member cannot re-anchor a group after the group moves")
    func movingAGroupCarriesItsArchivedMembers() {
        let calories = Tracker(name: "Calories", sortIndex: 0, isArchived: true, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, group: "Food",
                              modified: time(1), orderModified: time(1))
        let weight = Tracker(name: "Weight", sortIndex: 2, group: "Weight",
                             modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [calories, protein, weight]))

        store.move(protein.id, onto: weight.id)

        #expect(store.trackers.map(\.name) == ["Weight", "Calories", "Protein"])
        var restored = store.trackers.first { $0.id == calories.id }!
        restored.isArchived = false
        store.update(restored)

        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [
            ["Weight"], ["Calories", "Protein"],
        ])
    }

    @Test("Dropping where a tracker already sits does not claim a new order")
    func reorderingNoOpDoesNotStamp() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, group: "Food",
                              modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [calories, protein]))

        store.move(store.activeTrackerRuns[0], fromOffsets: IndexSet(integer: 0), toOffset: 1)
        store.move(calories.id, onto: calories.id)

        #expect(store.revision == 0)
        #expect(store.trackers.map(\.orderModified) == [time(1), time(1)])
    }

    @Test("A group move and a rename on another device both survive the merge")
    func groupMoveAndRenameDoNotCompete() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, group: "Food",
                              modified: time(1), orderModified: time(1))
        let weight = Tracker(name: "Weight", sortIndex: 2, group: "Weight",
                             modified: time(1), orderModified: time(1))
        let phone = makeStore(StoreDocument(trackers: [calories, protein, weight]))
        var renamed = protein
        renamed.name = "Protein grams"
        renamed.modified = time(2)
        let tablet = StoreDocument(trackers: [calories, renamed, weight])

        phone.move(weight.id, onto: protein.id)
        let merged = phone.document.merged(with: tablet)

        #expect(merged.trackers.map(\.name) == ["Weight", "Calories", "Protein grams"])
        #expect(merged.trackers.first { $0.id == protein.id }?.group == "Food")
    }

    @Test("Editing a tracker is the only operation that changes its group")
    func updateChangesGroup() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1)),
            Tracker(name: "Weight", sortIndex: 1, group: "Weight", modified: time(1)),
        ]))

        // Membership is content edited in the tracker editor, independent of
        // where the row happens to sit in settings.
        var moved = store.trackers[1]
        moved.group = "Food"
        store.update(moved)

        #expect(store.trackers.map(\.group) == ["Food", "Food"])
        #expect(store.trackers[0].modified == time(1))
        #expect(store.trackers[1].modified > time(1))
    }

    @Test("Reorder ignores changed content supplied by its caller")
    func reorderCannotChangeMembership() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1)),
            Tracker(name: "Weight", sortIndex: 1, group: "Weight", modified: time(1)),
        ]))
        var stale = store.trackers[1]
        stale.group = "Food"
        stale.name = "Not Weight"

        store.reorder([stale, store.trackers[0]])

        #expect(store.trackers.map(\.name) == ["Weight", "Calories"])
        #expect(store.trackers.map(\.group) == ["Weight", "Food"])
        #expect(store.trackers.allSatisfy { $0.modified == time(1) })
    }

    @Test("Groups are whatever the trackers say they are, in order, without repeats")
    func groupsAreDerived() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1)),
            Tracker(name: "Protein", sortIndex: 1, group: "Food", modified: time(1)),
            Tracker(name: "Cigarettes", sortIndex: 2, modified: time(1)),
            Tracker(name: "Weight", sortIndex: 3, isArchived: true, group: "Weight",
                    modified: time(1)),
        ]))

        // No empty string for the ungrouped tracker, and the archived one's
        // group is still offered — unarchiving it must not invent a new one.
        #expect(store.groups == ["Food", "Weight"])
    }

    @Test("Reading a group excludes archived trackers and keeps loose trackers separate")
    func trackersInGroup() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1)),
            Tracker(name: "Cigarettes", sortIndex: 1, modified: time(1)),
            Tracker(name: "Protein", sortIndex: 2, group: "Food", modified: time(1)),
            Tracker(name: "Weight", sortIndex: 3, group: "Weight", modified: time(1)),
            Tracker(name: "Cat weight", sortIndex: 4, isArchived: true, group: "Cat",
                    modified: time(1)),
        ]))

        #expect(store.trackers(inGroup: "Food").map(\.name) == ["Calories", "Protein"])
        #expect(store.trackers(inGroup: "").map(\.name) == ["Cigarettes"])
        #expect(store.trackers(inGroup: "Cat").isEmpty)
    }

    @Test("A loose tracker is logged on its own, not lumped in with the other loose ones")
    func logGroups() {
        let cigarettes = Tracker(name: "Cigarettes", sortIndex: 1, modified: time(1))
        let pushups = Tracker(name: "Pushups", sortIndex: 4, modified: time(1))
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1)),
            cigarettes,
            Tracker(name: "Protein", sortIndex: 2, group: "Food", modified: time(1)),
            Tracker(name: "Weight", sortIndex: 3, group: "Weight", modified: time(1)),
            pushups,
            Tracker(name: "Cat weight", sortIndex: 5, isArchived: true, modified: time(1)),
        ]))

        // Home order, each group once, and every ungrouped tracker as itself.
        // Cigarettes and Pushups share no group, so they share no sheet.
        #expect(store.logGroups == [
            .group("Food"),
            .tracker(cigarettes.id),
            .group("Weight"),
            .tracker(pushups.id),
        ])
        #expect(store.trackers(in: .group("Food")).map(\.name) == ["Calories", "Protein"])
        #expect(store.trackers(in: .tracker(cigarettes.id)).map(\.name) == ["Cigarettes"])
    }

    @Test("+ opens what you logged last, or the first group if it is gone")
    func groupToLog() {
        let cigarettes = Tracker(name: "Cigarettes", sortIndex: 1, modified: time(1))
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1)),
            cigarettes,
        ]))

        #expect(store.groupToLog(preferring: LogGroup.tracker(cigarettes.id).rawValue)
            == .tracker(cigarettes.id))
        // Nothing remembered yet, a group since renamed or emptied, and a
        // tracker since deleted: land on the first group rather than asking.
        #expect(store.groupToLog(preferring: "") == .group("Food"))
        #expect(store.groupToLog(preferring: "group:Cat") == .group("Food"))
        #expect(store.groupToLog(preferring: "tracker:\(UUID())") == .group("Food"))

        // Dropped into a group, it stops being a group of its own.
        var grouped = cigarettes
        grouped.group = "Food"
        store.update(grouped)
        #expect(store.logGroups == [.group("Food")])
        #expect(store.groupToLog(preferring: LogGroup.tracker(cigarettes.id).rawValue)
            == .group("Food"))

        var archived = store.trackers[0]
        archived.isArchived = true
        store.update(archived)
        var alsoArchived = store.trackers[1]
        alsoArchived.isArchived = true
        store.update(alsoArchived)
        #expect(store.groupToLog(preferring: "group:Food") == nil)
    }

    @Test("A log group survives the round trip through UserDefaults")
    func logGroupRawValues() {
        let id = UUID()
        for group in [LogGroup.group("Food"), .group("tracker:odd"), .tracker(id)] {
            #expect(LogGroup(rawValue: group.rawValue) == group)
        }
        // Anything else is not a group, and callers treat that as "no memory".
        #expect(LogGroup(rawValue: "") == nil)
        #expect(LogGroup(rawValue: "Food") == nil)
        #expect(LogGroup(rawValue: "group:") == nil)
        #expect(LogGroup(rawValue: "tracker:not-a-uuid") == nil)
    }

    @Test("Archiving hides a tracker without touching what was logged against it")
    func archiving() {
        var tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]))
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))

        tracker.isArchived = true
        store.update(tracker)

        #expect(store.activeTrackers.isEmpty)
        #expect(store.archivedTrackers.map(\.name) == ["Calories"])
        #expect(store.entries.count == 1)
        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 600)
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
                         name: "breakfast"))
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
