import Foundation
import Testing
@testable import BoringTracker

/// The third kind, where the date is the data: one tap writes it, the reading is
/// how long it has been, and the `0` in `Entry.value` must never reach a screen.
@MainActor
@Suite("Last time")
struct LastTimeTests {

    private let utc = calendar("UTC")

    private func makeStore(
        _ document: StoreDocument, now: Date? = nil, file: StoreFile? = nil
    ) -> Store {
        Store(
            document: document, file: file ?? temporaryStoreFile(),
            calendar: utc, now: now, saveWindow: .milliseconds(10)
        )
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> DayKey {
        DayKey(year: year, month: month, day: day)
    }

    // MARK: - How long it has been

    /// The whole ladder in one test, because the boundaries are the feature: the
    /// wording comes from the system, and this pins the day it changes on.
    @Test("Elapsed reads in whole days, then months, then years")
    func elapsedLadder() {
        let today = day(2026, 8, 20)
        let english = Locale(identifier: "en_US")
        func label(_ daysAgo: Int) -> String {
            let start = today.startOfDay(calendar: utc)
            let then = utc.date(byAdding: .day, value: -daysAgo, to: start)!
            return Elapsed.label(
                from: DayKey(then, calendar: utc), to: today, calendar: utc, locale: english
            )
        }

        #expect(label(0) == "today")
        #expect(label(1) == "yesterday")
        #expect(label(2) == "2 days ago")
        #expect(label(3) == "3 days ago")
        #expect(label(30) == "30 days ago")
        #expect(label(31) == "last month")
        #expect(label(60) == "2 months ago")
        #expect(label(365) == "last year")
        #expect(label(730) == "2 years ago")
    }

    @Test("A day either side of a DST change is still yesterday")
    func elapsedAcrossDST() {
        // Whole calendar days, not 24-hour blocks: on these two mornings the day
        // before is 23 and 25 hours long, which is where an arithmetic answer
        // rounds to "today" or "2 days ago".
        let zone = calendar("America/New_York")
        let english = Locale(identifier: "en_US")
        for (today, yesterday) in [
            (day(2026, 3, 9), day(2026, 3, 8)),
            (day(2026, 11, 2), day(2026, 11, 1)),
        ] {
            #expect(
                Elapsed.label(from: yesterday, to: today, calendar: zone, locale: english)
                    == "yesterday"
            )
        }
    }

    @Test("The day start moves the boundary, because both ends come from DayKey")
    func elapsedFollowsTheDayStart() {
        // Logged at 01:00 with a 4am day start, read at 10:00 the same morning:
        // the entry belongs to yesterday, so it reads "yesterday" rather than
        // "today" — the same answer History's headings give it.
        let tracker = Tracker(name: "Tyres", kind: .lastTime)
        let entry = Entry(trackerID: tracker.id, value: 0, date: date(2026, 3, 14, 1))
        let store = Store(
            document: StoreDocument(trackers: [tracker], entries: [entry]),
            file: temporaryStoreFile(), calendar: utc, now: date(2026, 3, 14, 10),
            dayStartHour: 4, saveWindow: .milliseconds(10)
        )

        #expect(store.day(of: entry) == day(2026, 3, 13))
        #expect(store.today == day(2026, 3, 14))
        #expect(
            Elapsed.label(
                from: store.day(of: entry), to: store.today,
                calendar: store.calendar, locale: Locale(identifier: "en_US")
            ) == "yesterday"
        )
    }

    // MARK: - One tap

    @Test("Logging one writes exactly one entry, and its only content is the date")
    func oneTapWritesOneEntry() throws {
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let store = makeStore(StoreDocument(trackers: [tyres]))
        let before = Date().canonicalized

        let written = store.logNow(tyres)

        #expect(store.entries.count == 1)
        let entry = try #require(store.entries.first)
        // What it returns is what it wrote, and home hangs its haptic on that id:
        // two taps a moment apart have to be two different values.
        #expect(written == entry)
        #expect(entry.trackerID == tyres.id)
        #expect(entry.value == 0)
        #expect(entry.name == nil)
        #expect(entry.date >= before)
        // A batch id like every other log: what was written together is a
        // property of the log, not of how many trackers it touched.
        #expect(entry.batchID != nil)
    }

    @Test("Two taps are two entries, not one edited twice")
    func twoTapsAreTwoEntries() {
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let store = makeStore(StoreDocument(trackers: [tyres]))

        let first = store.logNow(tyres)
        let second = store.logNow(tyres)

        #expect(store.entries.count == 2)
        #expect(Set(store.entries.map(\.batchID)).count == 2)
        #expect(first?.id != second?.id)
    }

    @Test("The zero adds nothing to a total")
    func zeroAddsNothingToATotal() {
        // The totals index takes every entry without asking the kind, so this one
        // is in there — worth 0, which is what makes the shared `Entry.value`
        // affordable. Nothing reads that key: only a daily-total card asks.
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let store = makeStore(StoreDocument(trackers: [tyres]), now: date(2026, 3, 14, 9))
        store.add(Entry(trackerID: tyres.id, value: 0, date: date(2026, 3, 14, 9)))

        #expect(store.total(for: tyres.id, on: day(2026, 3, 14)) == 0)
        #expect(store.latestEntry(for: tyres.id)?.value == 0)
    }

    // MARK: - What the screens read

    @Test("Nothing draws the stored zero")
    func theZeroIsNeverText() {
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1)

        #expect(tyres.entryText(0) == "Logged")
        #expect(weight.entryText(78.4) == "78.4 kg")
        // Even with a unit and decimals left over from being another kind
        // earlier: the editor hides those fields, it does not erase them.
        var wasAMeasurement = Tracker(name: "Tyres", unit: "km", kind: .lastTime, decimals: 2)
        wasAMeasurement.kind = .lastTime
        #expect(wasAMeasurement.entryText(0) == "Logged")
    }

    @Test("A history row says what it is, never a number")
    func historyRowSaysLogged() {
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let entry = Entry(trackerID: tyres.id, value: 0, date: time(10))
        let item = try! #require(HistoryItem(entries: [entry]))

        let line = item.line(trackers: [tyres.id: tyres])

        #expect(line.identity == "Tyres")
        #expect(line.values == "Logged")
    }

    @Test("A named one keeps the name on top and still names its tracker")
    func namedHistoryRow() {
        // With a unit left over from being a measurement, which is the case the
        // row's unit test used to get wrong: "Logged" carries no unit, so the unit
        // is no evidence that the row has said which tracker it is.
        let tyres = Tracker(name: "Tyres", unit: "km", kind: .lastTime)
        let entry = Entry(trackerID: tyres.id, value: 0, date: time(10), name: "front pair")
        let item = try! #require(HistoryItem(entries: [entry]))

        let line = item.line(trackers: [tyres.id: tyres])

        #expect(line.identity == "front pair")
        // The tracker's name moves down to the values line, by the rule every
        // other kind follows: once you have named a row, nothing else has said
        // which tracker it landed on.
        #expect(line.values == "Tyres: Logged")
    }

    // MARK: - Log again

    @Test("A last-time row is not offered for repeat, and says why")
    func repeatRefusesIt() {
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let store = makeStore(StoreDocument(trackers: [tyres]))
        store.logNow(tyres)
        let item = try! #require(store.historyItems.first)

        #expect(store.repeatableEntries(of: item).isEmpty)
        #expect(store.repeatItems.isEmpty)
        #expect(item.repeatBlockedReason(trackers: [tyres.id: tyres]) == "Last time")
    }

    @Test("It does not take a daily total's row down with it")
    func repeatKeepsTheTotalHalf() {
        // Only an imported file makes this batch — the log sheet cannot — but a
        // row that mixes them must still write the half that means something.
        let calories = Tracker(name: "Calories", unit: "kcal")
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let batch = UUID()
        let store = makeStore(StoreDocument(
            trackers: [calories, tyres],
            entries: [
                Entry(trackerID: calories.id, value: 450, date: time(10), batchID: batch),
                Entry(trackerID: tyres.id, value: 0, date: time(10), batchID: batch),
            ]
        ))
        let item = try! #require(store.historyItems.first)

        #expect(store.repeatableEntries(of: item).map(\.value) == [450])
        #expect(store.logAgain(item))
        #expect(store.lastLoggedAgain == Store.LoggedAgain(count: 1, skipped: 1))
    }

    // MARK: - Where the keypad can go

    @Test("The log sheet has no field for one, and no group made only of them")
    func theSheetLeavesItOut() {
        let calories = Tracker(name: "Calories", unit: "kcal", sortIndex: 0, group: "Car")
        let tyres = Tracker(name: "Tyres", kind: .lastTime, sortIndex: 1, group: "Car")
        let filter = Tracker(name: "Water filter", kind: .lastTime, sortIndex: 2)
        let store = makeStore(StoreDocument(trackers: [calories, tyres, filter]))

        // Home still draws both blocks: a group of last-time trackers is a block
        // on the home screen, just not a keypad.
        #expect(store.activeTrackerRuns.map { $0.map(\.name) }
            == [["Calories", "Tyres"], ["Water filter"]])
        #expect(store.amountTrackers(in: .group("Car")).map(\.name) == ["Calories"])
        #expect(store.loggableGroups == [.group("Car")])
        #expect(store.groupToLog(preferring: LogGroup(of: filter).rawValue) == .group("Car"))
    }

    @Test("With nothing but last-time trackers there is nowhere for the keypad to open")
    func nothingToLog() {
        let tyres = Tracker(name: "Tyres", kind: .lastTime, sortIndex: 0)
        let filter = Tracker(name: "Water filter", kind: .lastTime, sortIndex: 1)
        let store = makeStore(StoreDocument(trackers: [tyres, filter]))

        #expect(store.loggableGroups.isEmpty)
        #expect(store.groupToLog(preferring: "") == nil)
        #expect(store.activeTrackers.count == 2)
    }

    // MARK: - Out of the app and back

    @Test("The kind, and an entry that is only a date, survive the file")
    func roundTripThroughTheFile() throws {
        let tyres = Tracker(name: "Tyres", kind: .lastTime, sortIndex: 0, modified: time(1))
        let document = StoreDocument(
            trackers: [tyres],
            entries: [Entry(trackerID: tyres.id, value: 0, date: time(10), modified: time(10))]
        )

        let decoded = try StoreCoding.decode(StoreCoding.encode(document))

        #expect(decoded == document)
        #expect(decoded.trackers.first?.kind == .lastTime)
        #expect(decoded.trackers.first?.kindRaw == "lastTime")
    }

    @Test("A store loads it back as the kind it was saved as")
    func roundTripThroughTheStore() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let store = makeStore(StoreDocument(trackers: [tyres]), file: file)
        store.logNow(tyres)
        await store.flush()

        let reloaded = file.load().document

        #expect(reloaded.trackers.first?.kind == .lastTime)
        #expect(reloaded.entries.count == 1)
        #expect(reloaded.entries.first?.value == 0)
    }

    @Test("CSV carries the kind and the date, and a zero in the value column")
    func csvRow() throws {
        // The zero is in the file on purpose: `value` is not optional, and a
        // column that is blank for one kind is a column every reader has to
        // special-case. The date column is the data for these rows.
        let tyres = Tracker(name: "Tyres", kind: .lastTime)
        let entry = Entry(trackerID: tyres.id, value: 0, date: time(10))
        let text = try #require(String(
            data: CSVExport.data(document: StoreDocument(trackers: [tyres], entries: [entry])),
            encoding: .utf8
        ))

        #expect(text.contains(",Tyres,,lastTime,0.0,"))
        #expect(text.contains("2026-01-01T00:10:00Z"))
    }

    @Test("An import merges these entries like any others")
    func mergeKeepsThem() {
        let tyres = Tracker(name: "Tyres", kind: .lastTime, modified: time(1))
        let mine = StoreDocument(
            trackers: [tyres],
            entries: [Entry(trackerID: tyres.id, value: 0, date: time(10), modified: time(10))]
        )
        let theirs = StoreDocument(
            trackers: [tyres],
            entries: [Entry(trackerID: tyres.id, value: 0, date: time(20), modified: time(20))]
        )

        let merged = mine.merged(with: theirs)

        #expect(merged.trackers.count == 1)
        #expect(merged.trackers.first?.kind == .lastTime)
        #expect(merged.entries.count == 2)
        #expect(merged == theirs.merged(with: mine))
    }
}
