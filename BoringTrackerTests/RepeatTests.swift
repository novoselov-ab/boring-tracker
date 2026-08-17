import Foundation
import Testing
@testable import BoringTracker

/// The Repeat screen's list, and the two questions it asks of a history row:
/// can this be logged again at all, and does it match what was typed.
///
/// The writing half is item 14's `logAgain`, tested in `HistoryTests` — this
/// screen calls that and nothing else, which is the point of the item.
@MainActor
@Suite("Repeat")
struct RepeatTests {
    /// The clock every store here runs on, a day after `time(_:)`'s epoch.
    ///
    /// Pinned because the count reaches back `Store.countingWindowDays` days
    /// from *today*: against the real clock these fixtures would drift out of
    /// the window as the months pass, and every ordering test would quietly
    /// become a test of the recency tie-break.
    private static let now = date(2026, 1, 2, 12)

    /// A moment `days` before the pinned now, at the same time of day. Whole
    /// days, so a test says how far outside the window it means to be.
    private func daysAgo(_ days: Int) -> Date {
        Self.now.addingTimeInterval(Double(-days * 86_400))
    }

    private func repeatStore(_ document: StoreDocument) -> Store {
        Store(
            document: document,
            file: StoreFile(directory: URL.temporaryDirectory.appending(path: "repeat-\(UUID())")),
            calendar: calendar("UTC"),
            now: Self.now,
            saveWindow: .seconds(60)
        )
    }

    @Test("A daily total is listed named or not, and the name decides nothing")
    func dailyTotalsAreListedWhateverTheyAreCalled() {
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
                    // absent — but an imported file can carry it. It is no
                    // longer the difference between listed and not.
                    Entry(trackerID: tracker.id, value: 4, date: time(40), name: ""),
                ]
            )
        )

        // All four, where the name filter listed two (docs/TODO.md item 21).
        // The unnamed ones have no `displayName`; the screen shows their
        // values, which is what identifies them.
        #expect(store.repeatItems.map { $0.entries.map(\.value) } == [[4], [3], [2], [1]])
        #expect(
            store.repeatItems.map(\.displayName) == [nil, "chicken rice", nil, "porridge"]
        )
    }

    @Test("A measurement is not listed, however carefully it was named")
    func measurementsAreNeverListed() {
        let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1)
        let calories = Tracker(name: "Calories", unit: "kcal", sortIndex: 1)
        let store = repeatStore(
            StoreDocument(
                trackers: [weight, calories],
                entries: [
                    Entry(trackerID: weight.id, value: 78.1, date: time(10)),
                    // Named, and still not a thing to log again: repeating this
                    // does not weigh you, it writes a reading nobody took.
                    Entry(trackerID: weight.id, value: 77.4, date: time(20), name: "morning"),
                    Entry(trackerID: calories.id, value: 320, date: time(30), name: "porridge"),
                ]
            )
        )

        #expect(store.repeatItems.map(\.displayName) == ["porridge"])
    }

    @Test("A batch mixing kinds is not listed, because one tap would write both")
    func mixedKindBatchesAreNotListed() {
        // The shape the app produces on its own: a measurement sharing a log
        // group with a daily total, so one sheet writes both.
        let calories = Tracker(name: "Calories", unit: "kcal", group: "Morning")
        let weight = Tracker(
            name: "Weight", unit: "kg", kind: .measurement, decimals: 1, sortIndex: 1,
            group: "Morning"
        )
        let batch = UUID()
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, weight],
                entries: [
                    Entry(
                        trackerID: calories.id, value: 200, date: time(10),
                        name: "weigh-in", batchID: batch
                    ),
                    Entry(
                        trackerID: weight.id, value: 79.2, date: time(10),
                        name: "weigh-in", batchID: batch
                    ),
                    Entry(trackerID: calories.id, value: 320, date: time(20), name: "porridge"),
                ]
            )
        )

        // Listing it would put a false weight in the history to save retyping
        // 200 kcal. The row is still in History, which is where a row you want
        // to act on one member of lives.
        #expect(store.repeatItems.map(\.displayName) == ["porridge"])
    }

    @Test("Archiving a tracker changes where a row sorts, never whether it is listed")
    func archivingDoesNotChangeMembership() {
        let calories = Tracker(name: "Calories", unit: "kcal", group: "Morning")
        let weight = Tracker(
            name: "Weight", unit: "kg", kind: .measurement, decimals: 1, sortIndex: 1,
            group: "Morning"
        )
        let batch = UUID()
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, weight],
                entries: [
                    Entry(trackerID: calories.id, value: 200, date: time(10), batchID: batch),
                    Entry(trackerID: weight.id, value: 79.2, date: time(10), batchID: batch),
                    Entry(trackerID: calories.id, value: 320, date: time(20), name: "porridge"),
                ]
            )
        )
        #expect(store.repeatItems.map(\.displayName) == ["porridge"])

        var archived = weight
        archived.isArchived = true
        store.update(archived)

        // The kind is a property of the tracker, not of what a tap would
        // manage to write. Deciding membership on the latter would mean
        // archiving your scale silently added weigh-in batches to this list.
        #expect(store.repeatItems.map(\.displayName) == ["porridge"])
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

    @Test("A row whose trackers are all gone drops out; a partial one stays")
    func deletedTrackers() throws {
        let calories = Tracker(name: "Calories", unit: "kcal")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1)
        let batch = UUID()
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, protein],
                entries: [
                    Entry(trackerID: protein.id, value: 12, date: time(10), name: "porridge"),
                    Entry(
                        trackerID: calories.id, value: 620, date: time(20),
                        name: "chicken rice", batchID: batch
                    ),
                    Entry(
                        trackerID: protein.id, value: 41, date: time(20),
                        name: "chicken rice", batchID: batch
                    ),
                ]
            )
        )
        // The deletion that keeps the history — the supported choice that
        // leaves entries pointing at a tracker that is gone.
        store.delete(protein)

        // A deleted tracker has no kind left to read, so it can neither
        // qualify a row nor veto one (docs/TODO.md item 21). The lone porridge
        // row therefore has nothing to qualify it and goes; the batch still
        // has its calories and stays, writing what it can.
        #expect(store.repeatItems.map(\.displayName) == ["chicken rice"])
        let item = try #require(store.repeatItems.first)
        #expect(store.repeatableEntries(of: item).map(\.value) == [620])
        #expect(store.logAgain(item))

        store.delete(calories)

        // With nothing left to write and no kind to read, the list is empty —
        // where item 16's name filter kept the row greyed out forever. It is
        // still in History, which is the screen for what you did.
        #expect(store.repeatItems.isEmpty)
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

    @Test("Unnamed rows collapse on values alone, and take their place in the order")
    func unnamedRowsDedupeAndSortWithEveryoneElse() {
        let calories = Tracker(name: "Calories", unit: "kcal")
        let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1)
        let dinner = (1...4).map { _ in UUID() }
        let store = repeatStore(
            StoreDocument(
                trackers: [calories, protein],
                entries:
                    // The same unnamed dinner four times, on four days.
                    dinner.enumerated().flatMap { day, batch in
                        [
                            Entry(
                                trackerID: calories.id, value: 450, date: daysAgo(day + 1),
                                batchID: batch
                            ),
                            Entry(
                                trackerID: protein.id, value: 30, date: daysAgo(day + 1),
                                batchID: batch
                            ),
                        ]
                    }
                    + [
                        // Named, and eaten twice: fewer logs than the unnamed
                        // dinner, so it sorts under it. Unnamed rows join the
                        // ordering rather than getting a bucket of their own.
                        Entry(trackerID: calories.id, value: 320, date: daysAgo(1), name: "porridge"),
                        Entry(trackerID: calories.id, value: 320, date: daysAgo(2), name: "porridge"),
                    ]
            )
        )

        let items = store.repeatItems
        #expect(items.map(\.displayName) == [nil, "porridge"])
        #expect(items.map { $0.entries.map(\.value).sorted() } == [[30, 450], [320]])
        // Four logs became one row: with no name, the values are the whole key,
        // which is `RepeatKey`'s other half doing the work on its own.
        #expect(items.first?.date == daysAgo(1))
    }

    @Test("A query empties the unnamed rows out, because the field searches names")
    func unnamedRowsCannotBeSearchedFor() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 450, date: time(10)),
                    Entry(trackerID: tracker.id, value: 320, date: time(20), name: "porridge"),
                ]
            )
        )
        let items = store.repeatItems

        #expect(items.count == 2)
        // Not a gap to fill: falling back to the tracker's name would answer a
        // different question from the one the field asks, and would return
        // every unnamed calorie row for the query "calories".
        #expect(items.filter { $0.matches("porridge") }.map(\.displayName) == ["porridge"])
        #expect(items.filter { $0.matches("calories") }.isEmpty)
        #expect(items.filter { $0.matches("450") }.isEmpty)
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

    @Test("A row that cannot be written sorts below every row that can")
    func unrepeatableRowsSinkHoweverOftenTheyWereLogged() throws {
        // A daily total, because item 21 keeps measurements off this list
        // entirely — the row that has to sink is one that could be written if
        // the tracker were still active.
        let archived = Tracker(name: "Old water bottle", unit: "ml")
        let calories = Tracker(name: "Calories", unit: "kcal", sortIndex: 1)
        let store = repeatStore(
            StoreDocument(
                trackers: [archived, calories],
                entries: [
                    Entry(trackerID: archived.id, value: 750, date: time(10), name: "morning"),
                    Entry(trackerID: archived.id, value: 750, date: time(20), name: "morning"),
                    Entry(trackerID: archived.id, value: 750, date: time(30), name: "morning"),
                    Entry(trackerID: calories.id, value: 320, date: time(40), name: "porridge"),
                ]
            )
        )
        var bottle = archived
        bottle.isArchived = true
        store.update(bottle)

        // Three logs against one log: on count alone the archived row wins, and
        // it would hold the top of the screen greyed out for as long as the
        // counting window still reaches its logs, which is months. Recency used
        // to sink such rows on its own.
        let items = store.repeatItems
        #expect(items.map(\.displayName) == ["porridge", "morning"])
        #expect(store.repeatableEntries(of: try #require(items.last)).isEmpty)
    }

    @Test("Last year's staple stops outranking this month's, and still lists")
    func countingWindowDropsTheMuseumEffect() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries:
                    // Eaten every morning, and given up three months ago. Six
                    // logs against three: on a lifetime count this owns the top
                    // of the screen for good.
                    (90...95).map {
                        Entry(trackerID: tracker.id, value: 320, date: daysAgo($0), name: "porridge")
                    }
                    + (1...3).map {
                        Entry(trackerID: tracker.id, value: 290, date: daysAgo($0), name: "oats")
                    }
            )
        )

        let items = store.repeatItems
        // What you actually eat now is first...
        #expect(items.map(\.displayName) == ["oats", "porridge"])
        // ...and what you used to eat is still here, one tap away, with the
        // date that says when you last ate it. A count is not a filter.
        #expect(items.last?.date == daysAgo(90))
    }

    @Test("The window is 60 days counting today, and the edge is a whole day")
    func countingWindowEdge() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    // Three logs, every one of them a day too old to count.
                    Entry(trackerID: tracker.id, value: 320, date: daysAgo(60), name: "porridge"),
                    Entry(trackerID: tracker.id, value: 320, date: daysAgo(61), name: "porridge"),
                    Entry(trackerID: tracker.id, value: 320, date: daysAgo(62), name: "porridge"),
                    // One log, on the oldest day the window still reaches.
                    Entry(trackerID: tracker.id, value: 890, date: daysAgo(59), name: "pizza"),
                ]
            )
        )

        // 1 beats 0, so the single log inside the window leads three outside it.
        #expect(store.repeatItems.map(\.displayName) == ["pizza", "porridge"])
    }

    @Test("With nothing inside the window, the list is lifetime count then recency")
    func countingWindowEmpty() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries: [
                    Entry(trackerID: tracker.id, value: 320, date: daysAgo(300), name: "porridge"),
                    Entry(trackerID: tracker.id, value: 320, date: daysAgo(299), name: "porridge"),
                    Entry(trackerID: tracker.id, value: 890, date: daysAgo(200), name: "pizza"),
                    Entry(trackerID: tracker.id, value: 450, date: daysAgo(100), name: "soup"),
                ]
            )
        )

        // Come back after three months away and the screen is not empty: every
        // windowed count is 0, so the ordering falls through to the tie-breaks
        // under it rather than to nothing. Porridge leads on two logs against
        // one apiece even though it is the oldest row here — before item 16d
        // this read soup, pizza, porridge, purely by date. Recency still sorts
        // the two rows the lifetime count leaves tied.
        #expect(store.repeatItems.map(\.displayName) == ["porridge", "soup", "pizza"])
    }

    @Test("Tied inside the window, the thing eaten more over its life leads")
    func lifetimeCountBreaksWindowTies() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries:
                    // A staple in a quiet spell: eaten all through last year,
                    // twice in the past fortnight.
                    (100...199).map {
                        Entry(trackerID: tracker.id, value: 320, date: daysAgo($0), name: "porridge")
                    }
                    + [
                        Entry(trackerID: tracker.id, value: 320, date: daysAgo(14), name: "porridge"),
                        Entry(trackerID: tracker.id, value: 320, date: daysAgo(9), name: "porridge"),
                        // Tried twice this month and never before. Tied with the
                        // staple on the window's count, and eaten more recently,
                        // so the date alone used to put it first.
                        Entry(trackerID: tracker.id, value: 640, date: daysAgo(6), name: "pizza"),
                        Entry(trackerID: tracker.id, value: 640, date: daysAgo(2), name: "pizza"),
                    ]
            )
        )

        #expect(store.repeatItems.map(\.displayName) == ["porridge", "pizza"])
    }

    @Test("The window still decides first, however long the lifetime count is")
    func lifetimeCountNeverOutranksTheWindow() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let store = repeatStore(
            StoreDocument(
                trackers: [tracker],
                entries:
                    // Two hundred logs, every one of them outside the window:
                    // given up, and the window is the whole reason it stopped
                    // owning the top of the screen. A second tie-break must not
                    // hand that back.
                    (61...260).map {
                        Entry(trackerID: tracker.id, value: 320, date: daysAgo($0), name: "porridge")
                    }
                    + [
                        Entry(trackerID: tracker.id, value: 290, date: daysAgo(3), name: "oats")
                    ]
            )
        )

        // 1 beats 0 on the first comparison, so the lifetime count is never
        // asked. Both rows are still listed.
        #expect(store.repeatItems.map(\.displayName) == ["oats", "porridge"])
    }

    @Test("Rows tied on both counts and the date fall back to the row id")
    func orderIsStableWhenEverythingTies() {
        let tracker = Tracker(name: "Calories", unit: "kcal")
        // Six rows at one shared instant, each logged once, distinguishable only
        // by their values. Both counts tie, the date ties, and the row id is all
        // that is left — so the list must not shuffle between openings.
        let entries = (1...6).map {
            Entry(
                trackerID: tracker.id, value: Double($0) * 100, date: daysAgo(5), name: "leftovers"
            )
        }
        let store = repeatStore(StoreDocument(trackers: [tracker], entries: entries))

        // Asserted against the order the comparator promises, not against a
        // second reading of the same list: `sorted` is deterministic for a fixed
        // input, so comparing two calls to each other passes whatever the last
        // tie-break does — including nothing at all.
        //
        // **What this pins is the order, not the `sortID` line.** Deleting that
        // line leaves every test here green, because `historyItems` already
        // sorts by `sortID` within a shared date and `sorted` keeps that order
        // at any size this was tried at — so the line is a guard against
        // `historyItems` changing rather than something reachable from here. It
        // does fail if the direction is reversed, which is the part a reader
        // could get wrong.
        let expected =
            entries
            .sorted { "entry:\($0.id.uuidString)" > "entry:\($1.id.uuidString)" }
            .map { HistoryItem.ID.entry($0.id) }
        #expect(store.repeatItems.map(\.id) == expected)
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
