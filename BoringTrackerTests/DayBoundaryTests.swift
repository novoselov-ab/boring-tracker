import Foundation
import Testing
@testable import BoringTracker

/// The most bug-prone part of the app, per docs/TECH.md. A day is derived in
/// the calendar the user is currently living in, never stored — which is a
/// deliberate choice with consequences worth pinning down.
@Suite("Day boundaries")
struct DayBoundaryTests {

    let newYork = calendar("America/New_York")
    let santiago = calendar("America/Santiago")
    let tokyo = calendar("Asia/Tokyo")

    // MARK: - Midnight

    @Test("One second before midnight and midnight itself are different days")
    func midnightSplitsTheDay() {
        let lastMoment = date(2026, 3, 14, 23, 59, 59, in: newYork)
        let firstMoment = date(2026, 3, 15, 0, 0, 0, in: newYork)

        #expect(DayKey(lastMoment, calendar: newYork) == DayKey(year: 2026, month: 3, day: 14))
        #expect(DayKey(firstMoment, calendar: newYork) == DayKey(year: 2026, month: 3, day: 15))
    }

    @Test("New Year's Eve rolls the year, not just the day")
    func yearBoundary() {
        let before = date(2026, 12, 31, 23, 59, 59, in: newYork)
        let after = date(2027, 1, 1, 0, 0, 0, in: newYork)

        #expect(DayKey(before, calendar: newYork) == DayKey(year: 2026, month: 12, day: 31))
        #expect(DayKey(after, calendar: newYork) == DayKey(year: 2027, month: 1, day: 1))
        #expect(DayKey(before, calendar: newYork).adding(days: 1, calendar: newYork)
            == DayKey(after, calendar: newYork))
    }

    // MARK: - Daylight saving

    @Test("A day that has no midnight still has a start")
    func dayWithoutMidnight() {
        // Chile moved clocks from 00:00 to 01:00 on 8 September 2019, so that
        // date's 00:00 never happened. Assuming midnight exists is the classic
        // way to get this wrong.
        let day = DayKey(year: 2019, month: 9, day: 8)
        let start = day.startOfDay(calendar: santiago)

        #expect(santiago.dateComponents([.hour], from: start).hour == 1)
        #expect(DayKey(start, calendar: santiago) == day)
    }

    @Test("The 23-hour day is one day, not a fraction of two")
    func springForward() {
        // US clocks went 02:00 → 03:00 on 10 March 2019.
        let day = DayKey(year: 2019, month: 3, day: 10)
        let start = day.startOfDay(calendar: newYork)
        let next = day.adding(days: 1, calendar: newYork).startOfDay(calendar: newYork)

        #expect(next.timeIntervalSince(start) == 23 * 3_600)
        #expect(DayKey(start.addingTimeInterval(22 * 3_600), calendar: newYork) == day)
        #expect(DayKey(next, calendar: newYork) == DayKey(year: 2019, month: 3, day: 11))
    }

    @Test("Both passes through 01:30 on the 25-hour day count as the same day")
    func fallBack() {
        // US clocks went 02:00 → 01:00 on 3 November 2019, so 01:30 happens
        // twice, an hour apart in absolute time.
        let day = DayKey(year: 2019, month: 11, day: 3)
        let start = day.startOfDay(calendar: newYork)
        let firstPass = start.addingTimeInterval(1.5 * 3_600)
        let secondPass = start.addingTimeInterval(2.5 * 3_600)

        #expect(DayKey(firstPass, calendar: newYork) == day)
        #expect(DayKey(secondPass, calendar: newYork) == day)
        #expect(day.adding(days: 1, calendar: newYork).startOfDay(calendar: newYork)
            .timeIntervalSince(start) == 25 * 3_600)
    }

    @Test("Stepping a day at a time over a DST change never skips or repeats a date")
    func walkingAcrossDST() {
        var day = DayKey(year: 2019, month: 3, day: 8)
        var seen: [Int] = []
        for _ in 0..<5 {
            seen.append(day.day)
            day = day.adding(days: 1, calendar: newYork)
        }
        #expect(seen == [8, 9, 10, 11, 12])
    }

    // MARK: - Time zone travel

    @Test("The same moment is a different date depending on where you are")
    func sameMomentDifferentDay() {
        // 22:00 in New York is already tomorrow in Tokyo.
        let moment = date(2026, 3, 14, 22, 0, 0, in: newYork)

        #expect(DayKey(moment, calendar: newYork) == DayKey(year: 2026, month: 3, day: 14))
        #expect(DayKey(moment, calendar: tokyo) == DayKey(year: 2026, month: 3, day: 15))
    }

    @Test("Flying east moves last night's dinner into today's total")
    @MainActor
    func travellingRecomputesTotals() async {
        let tracker = Tracker(name: "Calories", kind: .dailyTotal)
        let dinner = Entry(
            trackerID: tracker.id, value: 800,
            date: date(2026, 3, 14, 22, 0, 0, in: newYork), modified: time(1)
        )
        let store = Store(
            document: StoreDocument(trackers: [tracker], entries: [dinner]),
            file: temporaryStoreFile(),
            calendar: newYork
        )

        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 800)
        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 15)) == 0)

        store.travel(to: tokyo)

        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 0)
        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 15)) == 800)
    }

    @Test("Totals for a 25-hour day include every hour of it")
    @MainActor
    func totalsCoverTheLongDay() {
        let tracker = Tracker(name: "Coffee", kind: .dailyTotal)
        let day = DayKey(year: 2019, month: 11, day: 3)
        let start = day.startOfDay(calendar: newYork)
        let entries = (0..<25).map { hour in
            Entry(
                trackerID: tracker.id, value: 1,
                date: start.addingTimeInterval(Double(hour) * 3_600), modified: time(1)
            )
        }
        let store = Store(
            document: StoreDocument(trackers: [tracker], entries: entries),
            file: temporaryStoreFile(),
            calendar: newYork
        )

        #expect(store.total(for: tracker.id, on: day) == 25)
        #expect(store.total(for: tracker.id, on: day.adding(days: 1, calendar: newYork)) == 0)
    }

    // MARK: - A day that does not start at midnight (docs/TODO.md)

    @Test("A 4am start puts the small hours on the day before")
    func lateNightBelongsToYesterday() {
        let start = 4
        // The three moments either side of the cut, on an ordinary day.
        let lateNight = date(2026, 3, 15, 1, 30, in: newYork)
        let justBefore = date(2026, 3, 15, 3, 59, 59, in: newYork)
        let justAfter = date(2026, 3, 15, 4, 0, 0, in: newYork)

        #expect(DayKey(lateNight, calendar: newYork, dayStartHour: start)
            == DayKey(year: 2026, month: 3, day: 14))
        #expect(DayKey(justBefore, calendar: newYork, dayStartHour: start)
            == DayKey(year: 2026, month: 3, day: 14))
        #expect(DayKey(justAfter, calendar: newYork, dayStartHour: start)
            == DayKey(year: 2026, month: 3, day: 15))
        // And midnight itself still splits the day when nobody has moved it.
        #expect(DayKey(lateNight, calendar: newYork) == DayKey(year: 2026, month: 3, day: 15))
    }

    @Test("An offset day rolls the month and the year backwards too")
    func offsetCrossesTheYear() {
        let newYearsSupper = date(2027, 1, 1, 2, 0, in: newYork)

        #expect(DayKey(newYearsSupper, calendar: newYork, dayStartHour: 4)
            == DayKey(year: 2026, month: 12, day: 31))
        #expect(DayKey(date(2026, 3, 1, 2, 0, in: newYork), calendar: newYork, dayStartHour: 4)
            == DayKey(year: 2026, month: 2, day: 28))
    }

    @Test("A day that starts after the missing hour begins when the clock says it can")
    func offsetOnTheSpringForwardDay() {
        // US clocks went 02:00 -> 03:00 on 10 March 2019, so a day cut at 2am
        // has no 2am to be cut at that morning.
        let day = DayKey(year: 2019, month: 3, day: 10)
        let start = day.startOfDay(calendar: newYork, dayStartHour: 2)

        #expect(newYork.dateComponents([.hour], from: start).hour == 3)
        // And the moment the day starts is inside the day it starts, which is
        // what a seconds-based offset gets wrong here.
        #expect(DayKey(start, calendar: newYork, dayStartHour: 2) == day)
    }

    @Test("Subtracting hours instead of reading the clock would lose the morning")
    func offsetSurvivesTheMissingHour() {
        // 04:30 on the spring-forward morning, with the day cut at 4am. It
        // belongs to the 10th: the clock says half past four.
        let day = DayKey(year: 2019, month: 3, day: 10)
        let morning = date(2019, 3, 10, 4, 30, in: newYork)

        #expect(DayKey(morning, calendar: newYork, dayStartHour: 4) == day)
        // The version this test exists to rule out: four *absolute* hours
        // earlier is 23:30 the previous evening, because one of those hours
        // never happened — so it would file this under the 9th.
        #expect(DayKey(morning.addingTimeInterval(-4 * 3_600), calendar: newYork)
            == DayKey(year: 2019, month: 3, day: 9))
    }

    @Test("Both passes through 01:30 on the 25-hour day land on the day before")
    func offsetOnTheFallBackDay() {
        // 3 November 2019: 01:30 happens twice, an hour apart in absolute time.
        // With a 4am start both are still last night.
        let day = DayKey(year: 2019, month: 11, day: 3)
        let midnight = day.startOfDay(calendar: newYork)
        let firstPass = midnight.addingTimeInterval(1.5 * 3_600)
        let secondPass = midnight.addingTimeInterval(2.5 * 3_600)
        let yesterday = DayKey(year: 2019, month: 11, day: 2)

        #expect(DayKey(firstPass, calendar: newYork, dayStartHour: 4) == yesterday)
        #expect(DayKey(secondPass, calendar: newYork, dayStartHour: 4) == yesterday)

        // **The 25-hour day moves with the boundary.** Cut at 4am, the repeated
        // hour falls inside the *2nd*, so that is the long day and the 3rd is
        // an ordinary 24. This assertion used to read 25 for the 3rd and it
        // passed — because `startOfDay` was adding absolute hours and landing
        // an hour early, so the bug and the expectation agreed with each other.
        let start = day.startOfDay(calendar: newYork, dayStartHour: 4)
        let next = day.adding(days: 1, calendar: newYork)
            .startOfDay(calendar: newYork, dayStartHour: 4)
        let previous = yesterday.startOfDay(calendar: newYork, dayStartHour: 4)
        #expect(start.timeIntervalSince(previous) == 25 * 3_600)
        #expect(next.timeIntervalSince(start) == 24 * 3_600)
    }

    @Test("A day's own start belongs to that day, on the day the clocks go back")
    func offsetStartRoundTripsAcrossFallBack() {
        // The round trip the test above did not make. With `startOfDay` adding
        // absolute hours, every start from 2am to 5am on this date came back as
        // the 2nd — so the chart drew the bar an hour before the day began, the
        // measurement range pulled in an hour that belonged to yesterday, and
        // the counting window sat an hour wide of the boundary.
        let day = DayKey(year: 2019, month: 11, day: 3)
        for hour in DayStart.hours {
            let start = day.startOfDay(calendar: newYork, dayStartHour: hour)
            #expect(DayKey(start, calendar: newYork, dayStartHour: hour) == day)
        }
    }

    @Test("Every hour of an offset day belongs to it, and none of the next one does")
    func offsetDaysTileTheClock() {
        let start = 4
        for day in [DayKey(year: 2026, month: 6, day: 10),
                    // And the two days a year the arithmetic is interesting: a
                    // June-only version of this test is where the fall-back bug
                    // hid.
                    DayKey(year: 2019, month: 3, day: 10),
                    DayKey(year: 2019, month: 11, day: 3)] {
            let dayStart = day.startOfDay(calendar: newYork, dayStartHour: start)
            let nextStart = day.adding(days: 1, calendar: newYork)
                .startOfDay(calendar: newYork, dayStartHour: start)
            // Every whole hour from this day's start up to the next one, which
            // is 23, 24 or 25 of them depending on the day.
            var moment = dayStart
            while moment < nextStart {
                #expect(DayKey(moment, calendar: newYork, dayStartHour: start) == day)
                moment = moment.addingTimeInterval(3_600)
            }
            #expect(DayKey(nextStart, calendar: newYork, dayStartHour: start)
                == day.adding(days: 1, calendar: newYork))
        }
    }

    @Test("Last night's supper moves into yesterday's total when the day start moves")
    @MainActor
    func movingTheDayStartRebuildsTotals() {
        let tracker = Tracker(name: "Calories", kind: .dailyTotal)
        let supper = Entry(
            trackerID: tracker.id, value: 700,
            date: date(2026, 3, 15, 1, 0, 0, in: newYork), modified: time(1)
        )
        let store = Store(
            document: StoreDocument(trackers: [tracker], entries: [supper]),
            file: temporaryStoreFile(),
            calendar: newYork,
            now: date(2026, 3, 15, 12, in: newYork),
            dayStartHour: 0
        )

        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 15)) == 700)
        #expect(store.today == DayKey(year: 2026, month: 3, day: 15))

        store.setDayStartHour(4)

        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 15)) == 0)
        #expect(store.total(for: tracker.id, on: DayKey(year: 2026, month: 3, day: 14)) == 700)
        // Noon is after 4am, so today is unchanged — the offset moved the
        // entry, not the calendar.
        #expect(store.today == DayKey(year: 2026, month: 3, day: 15))
        #expect(store.day(of: supper) == DayKey(year: 2026, month: 3, day: 14))

        // Put it back. No other test reads the key — the designated init takes
        // the hour and only the app's convenience init consults `UserDefaults`
        // — but a unit test is hosted *by the app*, so leaving 4 here means the
        // next person to launch Boring Tracker on this simulator finds their
        // day starting at four in the morning.
        store.setDayStartHour(DayStart.midnight)
    }

    @Test("Before the cut, the store is still on yesterday")
    @MainActor
    func todayIsYesterdayBeforeTheCut() {
        let store = Store(
            document: StoreDocument(trackers: [Tracker(name: "Calories")]),
            file: temporaryStoreFile(),
            calendar: newYork,
            now: date(2026, 3, 15, 2, 0, in: newYork),
            dayStartHour: 4
        )

        #expect(store.today == DayKey(year: 2026, month: 3, day: 14))
    }

    @Test("Putting the day start back re-derives exactly what was there before")
    @MainActor
    func theOffsetIsReversible() {
        let tracker = Tracker(name: "Calories", kind: .dailyTotal)
        let entries = (0..<24).map { hour in
            Entry(
                trackerID: tracker.id, value: 10,
                date: date(2026, 6, 10, hour, 0, in: newYork), modified: time(1)
            )
        }
        let store = Store(
            document: StoreDocument(trackers: [tracker], entries: entries),
            file: temporaryStoreFile(),
            calendar: newYork,
            now: date(2026, 6, 11, 12, in: newYork),
            dayStartHour: 0
        )
        let day = DayKey(year: 2026, month: 6, day: 10)
        #expect(store.total(for: tracker.id, on: day) == 240)

        store.setDayStartHour(6)
        #expect(store.total(for: tracker.id, on: day) == 180)
        #expect(store.total(for: tracker.id, on: day.adding(days: -1, calendar: newYork)) == 60)

        // Nothing was written down, so this is a re-derivation and not a
        // migration back.
        store.setDayStartHour(0)
        #expect(store.total(for: tracker.id, on: day) == 240)
        #expect(store.total(for: tracker.id, on: day.adding(days: -1, calendar: newYork)) == 0)
    }

    @Test("An hour a day cannot start at falls back to midnight")
    func dayStartIsClamped() {
        #expect(DayStart.hour(-1) == 0)
        #expect(DayStart.hour(24) == 0)
        #expect(DayStart.hour(0) == 0)
        #expect(DayStart.hour(23) == 23)
    }

    @Test("Midnight is called Midnight, and every other hour is a time")
    func dayStartLabels() {
        #expect(DayStart.label(0, calendar: newYork) == "Midnight")
        // Formatted off 1 February, the one month with no DST transition in
        // either hemisphere — so no region ever labels 2am as 3am. And in the
        // zone that was asked for: without that, a date built at 2am in
        // Santiago came back as "9:00 PM" from the machine running the test.
        //
        // Compared with the separators normalised: iOS puts a narrow no-break
        // space (U+202F) in front of AM, so a literal " AM" here is a test that
        // fails on a character nobody can see in the diff.
        #expect(plainSpaces(DayStart.label(2, calendar: santiago)) == "2:00 AM")
        #expect(plainSpaces(DayStart.label(16, calendar: newYork)) == "4:00 PM")
        #expect(DayStart.hours.count == 24)
    }

    /// The same string with every kind of space written as one, so an
    /// expectation can be read.
    private func plainSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    // MARK: - DayKey itself

    @Test("Days sort chronologically, not lexicographically")
    func dayKeysCompare() {
        #expect(DayKey(year: 2026, month: 1, day: 2) < DayKey(year: 2026, month: 10, day: 1))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
        #expect(!(DayKey(year: 2026, month: 3, day: 9) < DayKey(year: 2026, month: 3, day: 9)))
    }

    @Test("Going forward a day and back again returns to where it started")
    func dayArithmeticRoundTrips() {
        for start in [DayKey(year: 2019, month: 3, day: 10), DayKey(year: 2019, month: 11, day: 3),
                      DayKey(year: 2026, month: 12, day: 31), DayKey(year: 2024, month: 2, day: 29)] {
            let there = start.adding(days: 1, calendar: newYork)
            #expect(there.adding(days: -1, calendar: newYork) == start)
        }
    }
}
