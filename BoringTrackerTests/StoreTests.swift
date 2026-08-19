import Foundation
// For `move(fromOffsets:toOffset:)`, which is SwiftUI's, not the stdlib's.
// These tests build the order a `List` would have produced and hand it to
// `reorder`; without the import they compile only by borrowing the module
// through another one, which a future language mode stops allowing.
import SwiftUI
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

        var order = store.activeTrackers
        order.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        store.reorder(order)

        #expect(store.trackers.map(\.name) == ["C", "A", "B"])
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2])
        // All three moved, so all three carry a new position stamp — but none
        // of them was edited, so `modified` is untouched and cannot outrank
        // a real edit made on another device.
        #expect(store.trackers.allSatisfy { $0.orderModified > time(1) })
        #expect(store.trackers.allSatisfy { $0.modified == time(1) })
    }

    @Test("Saving a tracker nobody edited does not restamp it")
    func noOpTrackerSaveKeepsItsStamp() {
        let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
                             sortIndex: 0, modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [weight]))

        // `TrackerEditor` hands back exactly what it was given when Save is
        // tapped with nothing typed — the button is enabled on a non-empty
        // name, not on a change.
        store.update(store.trackers[0])

        #expect(store.trackers[0].modified == time(1))
    }

    @Test("Opening a tracker and saving it cannot discard a rename made elsewhere")
    func noOpTrackerSaveDoesNotOutrankARename() {
        let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
                             sortIndex: 0, modified: time(1), orderModified: time(1))
        let phone = makeStore(StoreDocument(trackers: [weight]))

        // The iPad renamed it at 10:02 and the phone opened the editor at
        // 10:05 and tapped Save without typing anything.
        var renamed = weight
        renamed.name = "Bodyweight"
        renamed.unit = "lb"
        renamed.modified = time(2)
        let tablet = StoreDocument(trackers: [renamed])

        phone.update(phone.trackers[0])

        let merged = phone.document.merged(with: tablet)
        // Exactly the rule `update(_ updatedEntries:)` already follows for a
        // batch's members: a rewrite that changed nothing is not a newer write,
        // so it must not beat a real edit made earlier on another device.
        #expect(merged.trackers.first?.name == "Bodyweight")
        #expect(merged.trackers.first?.unit == "lb")
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
        var order = phone.activeTrackers
        order.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        phone.reorder(order)
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

        var order = phone.activeTrackers
        order.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        phone.reorder(order)
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

        var order = store.activeTrackers
        order.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        store.reorder(order)

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

    @Test("What a drop says it will carry is what it carries")
    func carriedMatchesWhatTheMoveActuallyMoves() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, group: "Food",
                              modified: time(1), orderModified: time(1))
        let weight = Tracker(name: "Weight", sortIndex: 2, group: "Weight",
                             modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [calories, protein, weight]))

        // Settings dims these rows while the finger is down, so a preview that
        // disagreed with the drop would be a promise the release breaks.
        #expect(store.trackersCarried(moving: calories.id, onto: protein.id) == [calories.id])
        #expect(store.trackersCarried(moving: calories.id, onto: weight.id) == [calories.id, protein.id])
        #expect(store.trackersCarried(moving: weight.id, onto: protein.id) == [weight.id])
        // Nothing moves onto itself, and nothing moves onto a row that is gone.
        #expect(store.trackersCarried(moving: calories.id, onto: calories.id).isEmpty)
        #expect(store.trackersCarried(moving: calories.id, onto: UUID()).isEmpty)
    }

    @Test("A group with only archived members is not drawn and is not reordered")
    func anEntirelyArchivedGroupStaysOutOfTheWay() {
        let steps = Tracker(name: "Steps", sortIndex: 0,
                            modified: time(1), orderModified: time(1))
        let weight = Tracker(name: "Weight", sortIndex: 3, group: "Weight",
                             modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [
            steps,
            Tracker(name: "Calories", sortIndex: 1, isArchived: true, group: "Food",
                    modified: time(1), orderModified: time(1)),
            Tracker(name: "Protein", sortIndex: 2, isArchived: true, group: "Food",
                    modified: time(1), orderModified: time(1)),
            weight,
        ]))

        // Food is drawn nowhere, so it is not one of the runs a drop counts.
        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [["Steps"], ["Weight"]])

        // A drag straight across it: Weight is dropped on Steps, above Food.
        store.move(weight.id, onto: steps.id)

        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [["Weight"], ["Steps"]])
        // Food kept its slot between them rather than being shuffled by a move
        // nobody could see it take part in, and its two members stayed adjacent.
        #expect(store.trackers.map(\.name) == ["Weight", "Calories", "Protein", "Steps"])
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2, 3])
    }

    @Test("A group anchored by an archived member still moves by what is drawn")
    func aGroupAnchoredByAnArchivedMemberFollowsTheDrawnOrder() {
        // Stored, Food comes first — but its first member is archived, so the
        // first thing *drawn* is Steps. The blocks and the runs are therefore
        // in different orders, and a drop has to follow the drawn one.
        let steps = Tracker(name: "Steps", sortIndex: 1,
                            modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 2, group: "Food",
                              modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, isArchived: true, group: "Food",
                    modified: time(1), orderModified: time(1)),
            steps,
            protein,
        ]))

        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [["Steps"], ["Protein"]])

        store.move(steps.id, onto: protein.id)

        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [["Protein"], ["Steps"]])
        #expect(store.trackers.map(\.name) == ["Calories", "Protein", "Steps"])
    }

    @Test("Unarchiving a group's last member brings it back where it was left")
    func anEntirelyArchivedGroupComesBackInPlace() {
        let steps = Tracker(name: "Steps", sortIndex: 0,
                            modified: time(1), orderModified: time(1))
        let calories = Tracker(name: "Calories", sortIndex: 1, isArchived: true, group: "Food",
                               modified: time(1), orderModified: time(1))
        let weight = Tracker(name: "Weight", sortIndex: 2, group: "Weight",
                             modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [steps, calories, weight]))

        store.move(weight.id, onto: steps.id)

        var restored = store.trackers.first { $0.id == calories.id }!
        restored.isArchived = false
        store.update(restored)

        // Food sat between the two blocks and stays between them: a block that
        // took no part in the drag has no reason to come back somewhere else.
        #expect(store.activeTrackerRuns.map { $0.map(\.name) } == [
            ["Weight"], ["Calories"], ["Steps"],
        ])
    }

    @Test("Dropping where a tracker already sits does not claim a new order")
    func reorderingNoOpDoesNotStamp() {
        let calories = Tracker(name: "Calories", sortIndex: 0, group: "Food",
                               modified: time(1), orderModified: time(1))
        let protein = Tracker(name: "Protein", sortIndex: 1, group: "Food",
                              modified: time(1), orderModified: time(1))
        let store = makeStore(StoreDocument(trackers: [calories, protein]))

        var order = store.activeTrackerRuns[0]
        order.move(fromOffsets: IndexSet(integer: 0), toOffset: 1)
        store.reorder(order)
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
    func exportImportRoundTrip() async throws {
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
        try await destination.importData(exported, mode: .replace)

        #expect(destination.document == source.document)
        #expect(destination.totals == source.totals)
    }

    @Test("Importing an old backup does not resurrect what you have since deleted")
    func mergeImportRespectsDeletions() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let old = makeStore(StoreDocument(trackers: [tracker]))
        old.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        old.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))
        let backup = try old.exportData()

        // The same store, later: one of those was a mistake and got deleted.
        old.delete(old.entries[0])
        #expect(old.entries.count == 1)

        let summary = try await old.importData(backup, mode: .merge)

        #expect(old.entries.count == 1)
        #expect(summary == Store.ImportSummary(trackersAdded: 0, trackersRemoved: 0, entriesAdded: 0, entriesRemoved: 0))
    }

    @Test("A deletion recorded in an imported document removes the matching local entry")
    func mergeImportAppliesIncomingDeletions() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let entry = Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))
        let phone = makeStore(StoreDocument(trackers: [tracker], entries: [entry]))
        var imported = StoreDocument(trackers: [tracker], entries: [entry])
        imported.delete(id: entry.id, at: time(20))

        let summary = try await phone.importData(StoreCoding.encode(imported), mode: .merge)

        #expect(phone.entries.isEmpty)
        #expect(summary == Store.ImportSummary(trackersAdded: 0, trackersRemoved: 0, entriesAdded: 0, entriesRemoved: 1, keptBackup: true))
    }

    @Test("Merging a second device's export adds its entries and keeps yours")
    func mergeImportUnionsTwoDevices() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let phone = makeStore(StoreDocument(trackers: [tracker]))
        phone.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))

        let tablet = makeStore(StoreDocument(trackers: [tracker]))
        tablet.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))

        let summary = try await phone.importData(try tablet.exportData(), mode: .merge)

        #expect(phone.entries.count == 2)
        #expect(phone.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 850)
        #expect(summary == Store.ImportSummary(trackersAdded: 0, trackersRemoved: 0, entriesAdded: 1, entriesRemoved: 0, keptBackup: true))
    }

    @Test("Import grouping does not change equal-stamp tracker ordering")
    func mergeImportIsAssociative() async throws {
        func id(_ suffix: String) -> UUID {
            UUID(uuidString: "00000000-0000-0000-0000-0000000000\(suffix)")!
        }
        let stamp = time(1)
        let a = Tracker(id: id("01"), name: "A", sortIndex: 0,
                        modified: stamp, orderModified: stamp)
        let b = Tracker(id: id("02"), name: "B", sortIndex: 1,
                        modified: stamp, orderModified: stamp)
        let c = Tracker(id: id("03"), name: "C", sortIndex: 2,
                        modified: stamp, orderModified: stamp)
        let abc = StoreDocument(trackers: [a, b, c])
        var movedC = c
        movedC.sortIndex = 0
        var movedA = a
        movedA.sortIndex = 1
        var movedB = b
        movedB.sortIndex = 2
        let cab = StoreDocument(trackers: [movedC, movedA, movedB])

        let left = makeStore(abc)
        try await left.importData(StoreCoding.encode(abc), mode: .merge)
        try await left.importData(StoreCoding.encode(cab), mode: .merge)

        let grouped = makeStore(abc)
        try await grouped.importData(StoreCoding.encode(cab), mode: .merge)
        let right = makeStore(abc)
        try await right.importData(try grouped.exportData(), mode: .merge)

        #expect(left.document == right.document)
    }

    @Test("Replace really replaces, and says how much it removed")
    func replaceImport() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let incoming = makeStore(StoreDocument(trackers: [tracker]))
        incoming.add(Entry(trackerID: tracker.id, value: 250, date: date(2026, 3, 14, 13)))
        let file = try incoming.exportData()

        let store = makeStore(StoreDocument(trackers: [tracker]))
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        store.add(Entry(trackerID: tracker.id, value: 700, date: date(2026, 3, 14, 9)))

        let summary = try await store.importData(file, mode: .replace)

        #expect(store.entries.map(\.value) == [250])
        #expect(summary == Store.ImportSummary(trackersAdded: 0, trackersRemoved: 0, entriesAdded: 1, entriesRemoved: 2, keptBackup: true))
    }

    @Test("Replace keeps the exact current document in a separate backup first")
    func replaceImportKeepsBackup() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let current = StoreDocument(
            trackers: [tracker],
            entries: [Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))]
        )
        let store = makeStore(current, file: file)
        let incoming = StoreDocument(trackers: [tracker])

        try await store.importData(StoreCoding.encode(incoming), mode: .replace)

        #expect(try file.read(file.importBackupURL) == current)
        #expect(store.entries.isEmpty)
    }

    @Test("A merge keeps one too, because the file it takes in carries deletions")
    func mergeImportKeepsBackup() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let doomed = Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))
        let current = StoreDocument(trackers: [tracker], entries: [doomed])
        let store = makeStore(current, file: file, window: .seconds(60))
        // The additive-sounding mode, carrying a tombstone for an entry that
        // exists only here. Merge destroys it exactly as permanently as a
        // replace would, and with no confirmation in front of it — so it gets
        // the same recoverable copy.
        let incoming = StoreDocument(
            trackers: [tracker],
            tombstones: [Tombstone(id: doomed.id, deleted: time(20))]
        )

        try await store.importData(StoreCoding.encode(incoming), mode: .merge)

        #expect(store.entries.isEmpty)
        #expect(store.hasImportBackup)
        #expect(try file.read(file.importBackupURL) == current)

        // And the copy is worth having: the deleted entry comes back.
        try await store.restoreImportBackup()
        #expect(store.entries.map(\.id) == [doomed.id])
    }

    // MARK: - Clearing everything (docs/TODO.md item 24)

    @Test("Clearing everything leaves nothing, and leaves it recoverable")
    func clearAllKeepsBackup() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        // Explicit indices: `replaceState` sorts by (sortIndex, id), so two
        // trackers sharing index 0 come back in whichever order their random
        // ids fall in and the comparison below would pass about half the time.
        let tracker = Tracker(name: "Calories", sortIndex: 0, modified: time(1))
        let archived = Tracker(name: "Steps", sortIndex: 1, isArchived: true, modified: time(2))
        let current = StoreDocument(
            trackers: [tracker, archived],
            entries: [
                Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10)),
                Entry(trackerID: tracker.id, value: 250, date: time(20), modified: time(20)),
            ]
        )
        // A save window long enough that the debounced saver cannot have
        // written anything yet: the copy has to come from the flush the clear
        // itself performs, not from a write that happened to have landed.
        let store = makeStore(current, file: file, window: .seconds(60))

        try await store.clearAll()

        #expect(store.trackers.isEmpty)
        #expect(store.entries.isEmpty)
        #expect(store.hasImportBackup)
        // The archived tracker goes too. "Everything" is the whole document,
        // not the part of it home draws.
        #expect(try file.read(file.importBackupURL) == current)

        try await store.restoreImportBackup()
        #expect(store.document == current)
    }

    @Test("A clear says how much it removed")
    func clearAllSummary() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10)),
                    Entry(trackerID: tracker.id, value: 250, date: time(20), modified: time(20)),
                ]
            )
        )

        let summary = try await store.clearAll()

        #expect(
            summary == Store.ImportSummary(
                trackersAdded: 0, trackersRemoved: 1,
                entriesAdded: 0, entriesRemoved: 2,
                keptBackup: true
            )
        )
    }

    @Test("A clear writes no tombstones for what it removed")
    func clearAllLeavesNoTombstones() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(
            StoreDocument(
                trackers: [tracker],
                entries: (0..<5).map {
                    Entry(
                        trackerID: tracker.id, value: 100,
                        date: time(10 + $0), modified: time(10 + $0)
                    )
                }
            )
        )

        try await store.clearAll()

        // Deliberate, and the reason is size rather than tidiness: a tombstone
        // per record would leave "start over" holding a file as long as the
        // history it just removed, for the six months
        // `StoreDocument.tombstoneLifetime` keeps deletions. Clearing inherits
        // `replace`'s meaning instead — the document afterwards is the empty
        // one, and an older export merged back in returns the data
        // (docs/TODO.md item 24).
        #expect(store.document.tombstones.isEmpty)
        #expect(store.document.isEmpty)
    }

    @Test("A clear takes the undisclosed copy with it, not just the visible one")
    func clearAllDiscardsTheRollingBackup() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let current = StoreDocument(
            trackers: [tracker],
            entries: [Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))]
        )
        let store = makeStore(current, file: file, window: .seconds(60))
        // A save first, so the rolling backup exists and holds real history —
        // which is the state anybody who has used the app is in.
        try file.write(current)
        try file.write(current)
        #expect(try file.read(file.backupURL) == current)

        try await store.clearAll()

        // The recovery slot keeps the document, because the confirmation says
        // it will. `store.backup.json` does not, because nothing says it does:
        // `StoreFile.load` reads it whenever the main file will not decode, so
        // leaving it would let a cleared history come back on a later launch,
        // long after the copy the user was told about had been spent.
        #expect(try file.read(file.importBackupURL) == current)
        #expect(!FileManager.default.fileExists(atPath: file.backupURL.path))
        #expect(store.document.isEmpty)
    }

    @Test("A document Restore would refuse is not promised back")
    func restorabilityOfTheCurrentDocument() {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let ordinary = makeStore(
            StoreDocument(
                trackers: [tracker],
                entries: [Entry(trackerID: tracker.id, value: 600, date: time(10))]
            )
        )
        #expect(ordinary.currentDocumentIsRestorable)

        // A shape only a hand-edited or foreign file produces: `StoreFile.load`
        // runs no validation, so this opens — and `restoreImportBackup` runs
        // `validateImport`, so the copy taken before a clear could never be read
        // back. The confirmation has to say so rather than promise an undo that
        // is not there (docs/TODO.md item 24).
        let duplicated = UUID()
        let broken = makeStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(id: duplicated, trackerID: tracker.id, value: 600, date: time(10)),
                    Entry(id: duplicated, trackerID: tracker.id, value: 250, date: time(20)),
                ]
            )
        )
        #expect(!broken.currentDocumentIsRestorable)
    }

    @Test("Clearing an already empty document does not spend the recovery slot")
    func clearAllOnEmptyKeepsTheOlderBackup() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let original = StoreDocument(
            trackers: [tracker],
            entries: [Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))]
        )
        let store = makeStore(original, file: file)

        try await store.clearAll()
        #expect(try file.read(file.importBackupURL) == original)

        // The second clear removes nothing, so there is nothing to recover from
        // it — and spending the slot would destroy the copy that holds the
        // whole history. Same rule as a no-op import, inherited rather than
        // written again.
        let summary = try await store.clearAll()

        #expect(!summary.keptBackup)
        #expect(try file.read(file.importBackupURL) == original)
        try await store.restoreImportBackup()
        #expect(store.document == original)
    }

    @Test("An import that changes nothing does not spend the recovery slot")
    func noOpImportKeepsTheOlderBackup() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let original = StoreDocument(
            trackers: [tracker],
            entries: [Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))]
        )
        let store = makeStore(original, file: file, window: .seconds(60))
        // The replace they regret. The slot now holds the only copy of what
        // they had before it.
        let stripped = try StoreCoding.encode(StoreDocument(trackers: [tracker]))
        try await store.importData(stripped, mode: .replace)
        #expect(try file.read(file.importBackupURL) == original)

        // Merging a file they already have changes nothing — one unconfirmed
        // tap, and the one import people repeat. It must not burn the slot.
        try await store.importData(try store.exportData(), mode: .merge)

        #expect(try file.read(file.importBackupURL) == original)
        try await store.restoreImportBackup()
        #expect(store.document == original)
    }

    @Test("A failed import does not spend the recovery slot on the way down")
    func failedImportKeepsTheOlderBackup() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let original = StoreDocument(
            trackers: [tracker],
            entries: [Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))]
        )
        let store = makeStore(original, file: file, window: .seconds(60))
        // The replace they regret. The slot now holds the only copy of it.
        try await store.importData(
            try StoreCoding.encode(StoreDocument(trackers: [tracker])), mode: .replace
        )
        #expect(try file.read(file.importBackupURL) == original)
        let current = store.document
        // So the next import's own flush has nothing left to write. Without
        // this the saver fails first, and the import never reaches the two
        // writes this test is about.
        await store.flush()

        // A second import whose live write cannot land, while the staged copy
        // beside it still can — an occupied `store.json` path stands in for the
        // full disk, which is the realistic way to fail between those two
        // writes. Removing the directory would not do it: `write` recreates it.
        try FileManager.default.removeItem(at: file.url)
        try FileManager.default.createDirectory(at: file.url, withIntermediateDirectories: true)
        let incoming = StoreDocument(trackers: [Tracker(name: "Protein", modified: time(2))])
        await #expect(throws: (any Error).self) {
            try await store.importData(try StoreCoding.encode(incoming), mode: .merge)
        }

        // Nothing moved: not memory, and not the copy of the document they may
        // still want back. Writing the slot before the document meant this case
        // destroyed the pre-replace copy and then reported "Nothing was changed".
        #expect(store.document == current)
        #expect(try file.read(file.importBackupURL) == original)
        #expect(!FileManager.default.fileExists(atPath: file.importBackupStagingURL.path))
    }

    @Test("Two deletions in one second do not make a no-op merge burn the slot")
    func noOpMergeIsNotFooledByTombstoneOrder() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        // Pinned so the two orders provably disagree rather than disagreeing
        // about half the time: the entry deleted *second* has the smaller id,
        // so appending by deletion and sorting by (deleted, id) cannot agree.
        let first = Entry(id: UUID(uuidString: "FFFFFFFF-0000-4000-8000-000000000001")!,
                          trackerID: tracker.id, value: 100, date: time(10), modified: time(10))
        let second = Entry(id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
                           trackerID: tracker.id, value: 200, date: time(20), modified: time(20))
        let store = makeStore(
            StoreDocument(trackers: [tracker], entries: [first, second]),
            file: file, window: .seconds(60)
        )
        let original = store.document
        try await store.importData(
            try StoreCoding.encode(StoreDocument(trackers: [tracker])), mode: .replace
        )
        #expect(try file.read(file.importBackupURL) == original)

        // Deleted back to back, so `Date.stamp()` rounds both to the same
        // second and only the array order tells them apart. The store appends
        // in deletion order; a merge sorts by (deleted, id) — so whichever way
        // these two ids fall, re-merging our own export must still be a no-op.
        store.add(first)
        store.add(second)
        store.delete(first)
        store.delete(second)
        let exported = try store.exportData()

        try await store.importData(exported, mode: .merge)

        #expect(try file.read(file.importBackupURL) == original)
    }

    @Test(
        "No import happens when its safety backup cannot be written",
        arguments: Store.ImportMode.allCases
    )
    func importStopsWhenBackupFails(mode: Store.ImportMode) async throws {
        let base = temporaryStoreFile()
        defer { base.removeDirectory() }
        try base.prepareDirectory()
        let blocker = base.directory.appending(path: "not-a-directory")
        try Data("occupied".utf8).write(to: blocker)
        let file = StoreFile(directory: blocker)
        let tracker = Tracker(name: "Calories", modified: time(1))
        let current = StoreDocument(trackers: [tracker])
        let store = makeStore(current, file: file)
        // Something both modes would visibly do, so "nothing changed" is a real
        // assertion for the merge case and not a document that happened to
        // merge to itself.
        let incoming = StoreDocument(trackers: [Tracker(name: "Protein", modified: time(2))])

        await #expect(throws: (any Error).self) {
            try await store.importData(StoreCoding.encode(incoming), mode: mode)
        }
        #expect(store.document == current)
    }

    @Test("Restore is durable immediately, and the replaced data stays recoverable")
    func replaceBackupCanBeRestored() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        var second = Tracker(name: "Protein", sortIndex: 2, modified: time(1))
        second.orderModified = time(1)
        let original = StoreDocument(
            trackers: [tracker, second],
            entries: [Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))],
            tombstones: [Tombstone(id: UUID(), deleted: time(-400_000))]
        )
        let replacement = StoreDocument(trackers: [tracker])
        let store = makeStore(original, file: file, window: .seconds(60))
        try await store.importData(StoreCoding.encode(replacement), mode: .replace)
        store.add(Entry(trackerID: tracker.id, value: 250, date: time(20), modified: time(20)))
        let currentAtRestore = store.document
        // Exercise recovery bytes that an older replace could legitimately
        // contain: a safe ordering gap and a tombstone now old enough that a
        // normal import would compact it.
        try file.writeImportBackup(original)

        #expect(store.hasImportBackup)
        try await store.restoreImportBackup()

        #expect(store.document == original)
        #expect(try file.read(file.importBackupURL) == currentAtRestore)
        // No flush or debounce wait: the restore itself must make the recovered
        // document the durable main file before it reports success.
        #expect(file.load().document == original)
    }

    @Test("A damaged recovery file cannot disturb the current durable document")
    func damagedReplaceBackupCannotBeRestored() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let original = StoreDocument(trackers: [tracker])
        let replacement = StoreDocument(
            trackers: [tracker],
            entries: [Entry(trackerID: tracker.id, value: 250, date: time(20), modified: time(20))]
        )
        let store = makeStore(original, file: file, window: .seconds(60))
        try await store.importData(StoreCoding.encode(replacement), mode: .replace)
        await store.flush()
        try Data("damaged".utf8).write(to: file.importBackupURL, options: .atomic)

        await #expect(throws: (any Error).self) {
            try await store.restoreImportBackup()
        }

        #expect(store.document == replacement)
        #expect(file.load().document == replacement)
    }

    @Test("A junk file is refused without touching what is already there")
    func importRejectsJunk() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]))
        store.add(Entry(trackerID: tracker.id, value: 600, date: date(2026, 3, 14, 8)))
        let before = store.document

        await #expect(throws: (any Error).self) {
            try await store.importData(Data("nope".utf8), mode: .replace)
        }
        #expect(store.document == before)
    }

    @Test("A future-schema import is refused without touching current data")
    func importRejectsFutureSchema() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]))
        let before = store.document
        var future = StoreDocument()
        future.schemaVersion = StoreDocument.currentSchemaVersion + 1

        await #expect(throws: StoreError.futureSchema(
            found: future.schemaVersion,
            supported: StoreDocument.currentSchemaVersion
        )) {
            try await store.importData(StoreCoding.encode(future), mode: .replace)
        }
        #expect(store.document == before)
    }

    @Test("Import rejects duplicate live ids instead of double-counting them")
    func importRejectsDuplicateIDs() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let entry = Entry(trackerID: tracker.id, value: 100, date: time(10), modified: time(10))
        let store = makeStore(StoreDocument(trackers: [tracker]))
        let before = store.document
        let duplicate = StoreDocument(trackers: [tracker], entries: [entry, entry])

        await #expect(throws: StoreError.self) {
            try await store.importData(StoreCoding.encode(duplicate), mode: .replace)
        }
        #expect(store.document == before)
    }

    @Test("Import rejects an id that is both live and tombstoned so repeat imports converge")
    func importRejectsLiveDeletionCollision() async throws {
        let tracker = Tracker(name: "Calories", modified: time(1))
        let entry = Entry(trackerID: tracker.id, value: 100, date: time(10), modified: time(10))
        let store = makeStore(StoreDocument(trackers: [tracker]))
        let before = store.document
        let inconsistent = StoreDocument(
            trackers: [tracker], entries: [entry],
            tombstones: [Tombstone(id: entry.id, deleted: time(20))]
        )

        await #expect(throws: StoreError.self) {
            try await store.importData(StoreCoding.encode(inconsistent), mode: .replace)
        }
        #expect(store.document == before)
    }

    @Test("Import rejects tracker display precision that can crash formatting")
    func importRejectsInvalidDecimals() async throws {
        let current = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [current]))
        var malformed = Tracker(name: "Broken", modified: time(1))
        malformed.decimals = -1

        await #expect(throws: StoreError.self) {
            try await store.importData(
                StoreCoding.encode(StoreDocument(trackers: [malformed])), mode: .replace
            )
        }
        #expect(store.trackers == [current])
    }

    /// A blank name is not a decoding failure and not an inconsistency the
    /// merge can trip over, so nothing below this line would have stopped it:
    /// it decodes, merges and saves, and the first thing that goes wrong is a
    /// card on home with nothing written on it.
    @Test("Import rejects a tracker with no name rather than drawing a blank row")
    func importRejectsAnEmptyName() async throws {
        let current = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [current]))

        await #expect(throws: StoreError.self) {
            try await store.importData(
                StoreCoding.encode(StoreDocument(trackers: [Tracker(name: "", modified: time(1))])),
                mode: .replace
            )
        }
        #expect(store.trackers == [current])
    }

    /// Whitespace is the same blank row, and the app's own editor agrees: it
    /// trims before it saves, so "   " is a name this app can never write.
    @Test("Import rejects a name that is only whitespace")
    func importRejectsAWhitespaceOnlyName() async throws {
        let current = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [current]))

        await #expect(throws: StoreError.self) {
            try await store.importData(
                StoreCoding.encode(StoreDocument(trackers: [
                    Tracker(name: " \t\n ", modified: time(1)),
                ])),
                mode: .merge
            )
        }
        #expect(store.trackers == [current])
    }

    /// The recovery slot holds a document *this app* wrote out of its own
    /// memory, and loading a local file is deliberately tolerant, so a
    /// hand-edited store file can put a blank name in there. Refusing to
    /// restore it would disable the one action that undoes a destructive
    /// import, over a row that is only blank — so the name check is on the
    /// import path and not on this one.
    @Test("A name import refuses does not block the restore that undoes an import")
    func restoreAcceptsANameImportWouldRefuse() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let nameless = Tracker(name: "", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [Tracker(name: "Calories", modified: time(1))]),
                              file: file, window: .seconds(60))
        let recovery = StoreDocument(trackers: [nameless])
        try file.writeImportBackup(recovery)

        await #expect(throws: StoreError.self) {
            try await store.importData(StoreCoding.encode(recovery), mode: .replace)
        }
        try await store.restoreImportBackup()

        #expect(store.trackers == [nameless])
        #expect(file.load().document == recovery)
    }

    @Test("Import rejects an overflowing sort index and preserves safe positions")
    func importValidatesSortIndices() async throws {
        let store = makeStore()
        var unsafe = Tracker(name: "Unsafe", sortIndex: Int.max, modified: time(1))
        await #expect(throws: StoreError.self) {
            try await store.importData(
                StoreCoding.encode(StoreDocument(trackers: [unsafe])), mode: .replace
            )
        }

        unsafe.sortIndex = Int.max - 1
        let first = Tracker(name: "First", sortIndex: 20, modified: time(1))
        try await store.importData(
            StoreCoding.encode(StoreDocument(trackers: [unsafe, first])), mode: .replace
        )
        #expect(store.trackers.map(\.name) == ["First", "Unsafe"])
        #expect(store.trackers.map(\.sortIndex) == [20, Int.max - 1])

        store.add(Tracker(name: "Still safe"))
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2])
    }

    /// The value import refuses, arriving the way import cannot stop: in the
    /// store file itself. `validateImport` guards the boundary an *imported*
    /// document crosses, and nothing validates the file this device wrote — a
    /// file hand-edited on the Mac, or one written by a build that allowed
    /// something this one does not. Adding a tracker then computes
    /// `maximum + 1` on `Int.max`, which in Swift is a trap and not a wrap:
    /// the app would die on the Add Tracker button, every time, with the only
    /// way out being to delete it.
    @Test("A stored sort index of Int.max does not blow up the next tracker added")
    func addSurvivesAnOverflowingStoredSortIndex() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "First", sortIndex: 3, modified: time(1)),
            Tracker(name: "Absurd", sortIndex: .max, modified: time(1)),
        ]))

        store.add(Tracker(name: "Added"))

        // Renumbered from the top rather than appended, which is the only
        // answer that leaves room for the one after this.
        #expect(store.trackers.map(\.name) == ["First", "Absurd", "Added"])
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2])
        // And it stays survivable: a second add is ordinary arithmetic now.
        store.add(Tracker(name: "And another"))
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2, 3])
    }

    /// The same value, one field down: a tracker in a *group*, so `add` takes
    /// its insertion path instead of appending. That branch renumbers whatever
    /// it finds, so it never does the arithmetic — worth pinning, because the
    /// fix lives in the other branch and a later edit could easily give this
    /// one a `maximum + 1` of its own.
    @Test("An overflowing sort index survives an insertion beside its group too")
    func insertionSurvivesAnOverflowingStoredSortIndex() {
        let store = makeStore(StoreDocument(trackers: [
            Tracker(name: "Calories", sortIndex: 0, group: "Food", modified: time(1)),
            Tracker(name: "Absurd", sortIndex: .max, modified: time(1)),
        ]))

        store.add(Tracker(name: "Protein", group: "Food"))

        #expect(store.trackers.map(\.name) == ["Calories", "Protein", "Absurd"])
        #expect(store.trackers.map(\.sortIndex) == [0, 1, 2])
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

    @Test("An import is on disk before it says it worked")
    func importIsDurableWhenItReports() async throws {
        for mode in Store.ImportMode.allCases {
            let file = temporaryStoreFile()
            defer { file.removeDirectory() }
            let tracker = Tracker(name: "Calories", modified: time(1))
            let current = StoreDocument(
                trackers: [tracker],
                entries: [Entry(trackerID: tracker.id, value: 600, date: time(10), modified: time(10))]
            )
            let store = makeStore(current, file: file, window: .seconds(60))
            try file.write(current)
            let incoming = StoreDocument(
                trackers: [tracker],
                entries: [Entry(trackerID: tracker.id, value: 250, date: time(20), modified: time(20))]
            )

            try await store.importData(StoreCoding.encode(incoming), mode: mode)

            // No flush and no waiting out the debounce: force-quitting the app
            // while the "Import complete" alert is still up must not discard an
            // import the app has already announced.
            #expect(file.load().document == store.document, "\(mode)")
        }
    }

    @Test("An import cannot be overwritten by a write queued for the document it replaced")
    func importOutlivesAQueuedSave() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]), file: file, window: .seconds(60))
        // An edit still sitting in the save debounce when the import runs.
        store.add(Entry(trackerID: tracker.id, value: 600, date: time(10)))
        let incoming = StoreDocument(trackers: [tracker])

        try await store.importData(StoreCoding.encode(incoming), mode: .replace)
        await store.flush()

        #expect(store.entries.isEmpty)
        #expect(file.load().document.entries.isEmpty)
    }

    @Test("An entry logged while the import drains the save queue is not lost")
    func importKeepsAnEditMadeWhileItWasDraining() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tracker = Tracker(name: "Calories", modified: time(1))
        let store = makeStore(StoreDocument(trackers: [tracker]), file: file, window: .seconds(60))
        store.add(Entry(trackerID: tracker.id, value: 600, date: time(10)))
        let incoming = StoreDocument(
            trackers: [tracker],
            entries: [Entry(trackerID: tracker.id, value: 250, date: time(20), modified: time(20))]
        )

        // `importData` awaits the saver, and main-actor methods are reentrant at
        // `await` — so this runs in the middle of the import, on the snapshot it
        // has already taken. The store notices its revision moved and starts
        // again rather than merging onto a document that no longer exists.
        let concurrent = Task { @MainActor in
            store.add(Entry(trackerID: tracker.id, value: 999, date: time(30)))
        }
        try await store.importData(StoreCoding.encode(incoming), mode: .merge)
        await concurrent.value

        // True whichever side of the import the log lands on, which is the
        // point: a value typed during an import is never the one that vanishes.
        #expect(store.entries.map(\.value).sorted() == [250, 600, 999])
        await store.flush()
        #expect(file.load().document == store.document)
    }

    @Test("Importing your own export twice adds nothing the second time")
    func importingTheSameFileTwiceConverges() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let calories = Tracker(name: "Calories", unit: "kcal", group: "Food", modified: time(1))
        var protein = Tracker(name: "Protein", unit: "g", sortIndex: 1, group: "Food",
                              modified: time(1))
        protein.orderModified = time(1)
        let store = makeStore(StoreDocument(trackers: [calories, protein]), file: file)
        store.add(values: [calories.id: 100, protein.id: 10], at: time(10), name: "chicken rice")
        let exported = try store.exportData()
        let before = store.document

        let first = try await store.importData(exported, mode: .merge)
        let second = try await store.importData(exported, mode: .merge)

        // The whole point of the mergeable document: re-importing a file you
        // already have is a no-op, not a second copy of every entry.
        #expect(store.document == before)
        #expect(store.entries.count == 2)
        #expect(store.historyItems.count == 1)
        #expect(first == Store.ImportSummary(trackersAdded: 0, trackersRemoved: 0,
                                             entriesAdded: 0, entriesRemoved: 0))
        #expect(second == first)
    }

    @Test("Export, fresh install, import: what comes back is what left")
    func roundTripThroughAFreshInstall() async throws {
        let original = temporaryStoreFile()
        defer { original.removeDirectory() }
        let calories = Tracker(name: "Calories", unit: "kcal", group: "Food", modified: time(1))
        var protein = Tracker(name: "Protein", unit: "g", sortIndex: 1, group: "Food",
                              modified: time(1))
        protein.orderModified = time(1)
        let store = makeStore(StoreDocument(trackers: [calories, protein]), file: original)
        store.add(values: [calories.id: 100, protein.id: 10], at: time(10), name: "chicken rice")
        store.add(values: [calories.id: 620], at: time(20), name: "dinner, \"large\"")
        let exported = try store.exportData()
        let expected = store.document

        // A fresh install: a different container with nothing in it.
        let installed = temporaryStoreFile()
        defer { installed.removeDirectory() }
        let fresh = Store(document: .starter, file: installed, calendar: calendar("UTC"),
                          saveWindow: .seconds(60))
        try await fresh.importData(exported, mode: .replace)

        #expect(fresh.document == expected)
        #expect(fresh.historyItems.count == 2)
        #expect(fresh.historyItems.map(\.displayName) == ["dinner, \"large\"", "chicken rice"])
        // And it is durable, so relaunching that fresh install still has it.
        #expect(installed.load().document == expected)
    }

    @Test("A replace says how many trackers it removed, not only how many entries")
    func replaceReportsRemovedTrackers() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let kept = Tracker(name: "Calories", modified: time(1))
        var dropped = Tracker(name: "Protein", sortIndex: 1, modified: time(1))
        dropped.orderModified = time(1)
        let store = makeStore(StoreDocument(trackers: [kept, dropped]), file: file)

        let summary = try await store.importData(
            StoreCoding.encode(StoreDocument(trackers: [kept])), mode: .replace
        )

        #expect(summary.trackersRemoved == 1)
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
