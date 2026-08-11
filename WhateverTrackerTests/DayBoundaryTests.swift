import Foundation
import Testing
@testable import WhateverTracker

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
