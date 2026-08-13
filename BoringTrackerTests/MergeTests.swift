import Foundation
import Testing
@testable import BoringTracker

/// The merge is the only genuinely subtle code in the app, and its bugs eat
/// data quietly instead of crashing. Hence the weight of this file.
@Suite("Merge")
struct MergeTests {

    let tracker = UUID()

    // MARK: - Union

    @Test("Two devices logging different meals is a plain union")
    func unionOfDisjointEntries() {
        let mine = StoreDocument(entries: [
            Entry(trackerID: tracker, value: 600, date: time(10), modified: time(10))
        ])
        let theirs = StoreDocument(entries: [
            Entry(trackerID: tracker, value: 250, date: time(20), modified: time(20))
        ])

        let merged = mine.merged(with: theirs)

        #expect(merged.entries.count == 2)
        #expect(merged.entries.map(\.value) == [600, 250])
    }

    @Test("Nothing is duplicated when both sides hold the same record")
    func identicalRecordsCollapse() {
        let entry = Entry(trackerID: tracker, value: 600, date: time(10), modified: time(10))
        let document = StoreDocument(entries: [entry])

        #expect(document.merged(with: document).entries == [entry])
    }

    @Test("The newer edit of the same record wins")
    func newerEditWins() {
        let id = UUID()
        let older = Entry(id: id, trackerID: tracker, value: 600, date: time(10), modified: time(10))
        let newer = Entry(id: id, trackerID: tracker, value: 650, date: time(10), modified: time(11))

        #expect(StoreDocument(entries: [older]).merged(with: .init(entries: [newer]))
            .entries.map(\.value) == [650])
        #expect(StoreDocument(entries: [newer]).merged(with: .init(entries: [older]))
            .entries.map(\.value) == [650])
    }

    @Test("A conflict stamped in the same millisecond still resolves the same way both ways round")
    func simultaneousEditsResolveDeterministically() {
        let id = UUID()
        let stamp = time(10)
        let one = Entry(id: id, trackerID: tracker, value: 600, date: time(10), modified: stamp)
        let two = Entry(id: id, trackerID: tracker, value: 650, date: time(10), modified: stamp)

        let forward = StoreDocument(entries: [one]).merged(with: .init(entries: [two]))
        let backward = StoreDocument(entries: [two]).merged(with: .init(entries: [one]))

        #expect(forward == backward)
        #expect(forward.entries.count == 1)
    }

    // MARK: - Tombstones

    @Test("A deletion on one device is not undone by the other still having the record")
    func tombstoneBeatsResurrection() {
        let entry = Entry(trackerID: tracker, value: 600, date: time(10), modified: time(10))
        var deleter = StoreDocument(entries: [entry])
        deleter.delete(id: entry.id, at: time(15))
        let keeper = StoreDocument(entries: [entry])

        #expect(deleter.merged(with: keeper).entries.isEmpty)
        #expect(keeper.merged(with: deleter).entries.isEmpty)
    }

    @Test("A delete beats an edit made later on the other device")
    func tombstoneBeatsNewerEdit() {
        let id = UUID()
        let original = Entry(id: id, trackerID: tracker, value: 600, date: time(10), modified: time(10))
        var deleter = StoreDocument(entries: [original])
        deleter.delete(id: id, at: time(11))

        let edited = Entry(id: id, trackerID: tracker, value: 999, date: time(10), modified: time(30))
        let editor = StoreDocument(entries: [edited])

        #expect(deleter.merged(with: editor).entries.isEmpty)
        #expect(editor.merged(with: deleter).entries.isEmpty)
    }

    @Test("Deleting keeps the record's id rather than dropping the row")
    func deleteLeavesATombstone() {
        let entry = Entry(trackerID: tracker, value: 600, date: time(10), modified: time(10))
        var document = StoreDocument(entries: [entry])
        document.delete(id: entry.id, at: time(15))

        #expect(document.entries.isEmpty)
        #expect(document.tombstones == [Tombstone(id: entry.id, deleted: time(15))])
    }

    @Test("Deleting twice keeps the later time, so the tombstone lives longer")
    func repeatedDeletionKeepsLaterTime() {
        let id = UUID()
        var earlier = StoreDocument()
        earlier.delete(id: id, at: time(10))
        var later = StoreDocument()
        later.delete(id: id, at: time(40))

        #expect(earlier.merged(with: later).deletions[id] == time(40))
        #expect(later.merged(with: earlier).deletions[id] == time(40))
    }

    @Test("A tombstone in the document also removes a record the same document still holds")
    func documentIsMadeSelfConsistent() {
        let entry = Entry(trackerID: tracker, value: 600, date: time(10), modified: time(10))
        let inconsistent = StoreDocument(
            entries: [entry],
            tombstones: [Tombstone(id: entry.id, deleted: time(20))]
        )

        #expect(inconsistent.merged(with: .init()).entries.isEmpty)
    }

    @Test("Trackers are tombstoned by the same rules as entries")
    func tombstonesCoverEveryRecordKind() {
        let trackerRecord = Tracker(name: "Calories", modified: time(5))
        let entry = Entry(trackerID: trackerRecord.id, value: 600, date: time(10), modified: time(5))
        var mine = StoreDocument(trackers: [trackerRecord], entries: [entry])
        mine.delete(id: trackerRecord.id, at: time(10))
        mine.delete(id: entry.id, at: time(10))

        let theirs = StoreDocument(trackers: [trackerRecord], entries: [entry])
        let merged = mine.merged(with: theirs)

        #expect(merged.trackers.isEmpty)
        #expect(merged.entries.isEmpty)
    }

    // MARK: - Compaction

    @Test("Tombstones are forgotten after the compaction window, not before")
    func compactionDropsOnlyOldTombstones() {
        let now = date(2026, 8, 10)
        let fresh = Tombstone(id: UUID(), deleted: now.addingTimeInterval(-179 * 86_400))
        let stale = Tombstone(id: UUID(), deleted: now.addingTimeInterval(-181 * 86_400))
        let document = StoreDocument(tombstones: [fresh, stale])

        let compacted = document.compactingTombstones(now: now)

        #expect(compacted.tombstones == [fresh])
    }

    @Test("A device offline longer than the window resurrects its records — the accepted price")
    func compactionEventuallyAllowsResurrection() {
        let now = date(2026, 8, 10)
        let entry = Entry(trackerID: tracker, value: 600, date: time(10), modified: time(10))
        var deleter = StoreDocument(entries: [entry])
        deleter.delete(id: entry.id, at: now.addingTimeInterval(-200 * 86_400))

        let stillDeleted = deleter.merged(with: .init(entries: [entry]))
        let afterCompaction = deleter.compactingTombstones(now: now).merged(with: .init(entries: [entry]))

        #expect(stillDeleted.entries.isEmpty)
        #expect(afterCompaction.entries == [entry])
    }

    // MARK: - Ordering

    @Test("Merged entries come out oldest first regardless of input order")
    func mergeSortsEntries() {
        let late = Entry(trackerID: tracker, value: 1, date: time(90), modified: time(1))
        let early = Entry(trackerID: tracker, value: 2, date: time(10), modified: time(1))
        let middle = Entry(trackerID: tracker, value: 3, date: time(50), modified: time(1))

        let merged = StoreDocument(entries: [late, early]).merged(with: .init(entries: [middle]))

        #expect(merged.entries.map(\.date) == [time(10), time(50), time(90)])
    }

    @Test("Two entries in the same millisecond still land in the same order on both devices")
    func simultaneousEntriesOrderStably() {
        let stamp = time(10)
        let one = Entry(trackerID: tracker, value: 1, date: stamp, modified: stamp)
        let two = Entry(trackerID: tracker, value: 2, date: stamp, modified: stamp)

        let forward = StoreDocument(entries: [one]).merged(with: .init(entries: [two]))
        let backward = StoreDocument(entries: [two]).merged(with: .init(entries: [one]))

        #expect(forward.entries == backward.entries)
    }

    // MARK: - Algebra
    //
    // These are the properties that make merge safe to run at any time, in any
    // order, as many times as you like — which is exactly how import, and later
    // sync, will use it.

    private func documents(seed: UInt64, count: Int) -> [StoreDocument] {
        let trackerIDs = (0..<4).map { _ in UUID() }
        let entryIDs = (0..<24).map { _ in UUID() }
        return (0..<count).map {
            .random(seed: seed &+ UInt64($0), trackerIDs: trackerIDs, entryIDs: entryIDs)
        }
    }

    @Test("Merge is commutative", arguments: 1...400 as ClosedRange<UInt64>)
    func commutative(seed: UInt64) {
        let pair = documents(seed: seed &* 977, count: 2)
        #expect(pair[0].merged(with: pair[1]) == pair[1].merged(with: pair[0]))
    }

    @Test("Merge is associative", arguments: 1...400 as ClosedRange<UInt64>)
    func associative(seed: UInt64) {
        let triple = documents(seed: seed &* 613, count: 3)
        let left = triple[0].merged(with: triple[1]).merged(with: triple[2])
        let right = triple[0].merged(with: triple[1].merged(with: triple[2]))
        #expect(left == right)
    }

    @Test("Importing the same file twice changes nothing the second time",
          arguments: 1...400 as ClosedRange<UInt64>)
    func idempotent(seed: UInt64) {
        let pair = documents(seed: seed &* 331, count: 2)
        let once = pair[0].merged(with: pair[1])
        #expect(once.merged(with: pair[1]) == once)
        #expect(once.merged(with: once) == once)
    }

    @Test("Merging loses no record that neither side deleted",
          arguments: 1...400 as ClosedRange<UInt64>)
    func nothingVanishes(seed: UInt64) {
        let pair = documents(seed: seed &* 89, count: 2)
        let merged = pair[0].merged(with: pair[1])
        let deleted = Set(merged.deletions.keys)

        let expected = Set((pair[0].entries + pair[1].entries).map(\.id)).subtracting(deleted)
        #expect(Set(merged.entries.map(\.id)) == expected)

        let expectedTrackers = Set((pair[0].trackers + pair[1].trackers).map(\.id))
            .subtracting(deleted)
        #expect(Set(merged.trackers.map(\.id)) == expectedTrackers)
    }

    @Test("Every surviving record is the newest version either side had",
          arguments: 1...400 as ClosedRange<UInt64>)
    func survivorsAreTheNewestVersion(seed: UInt64) {
        let pair = documents(seed: seed &* 47, count: 2)
        let merged = pair[0].merged(with: pair[1])

        for entry in merged.entries {
            let candidates = (pair[0].entries + pair[1].entries).filter { $0.id == entry.id }
            #expect(entry.modified == candidates.map(\.modified).max())
        }
    }
}
