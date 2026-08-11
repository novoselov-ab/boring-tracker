import Foundation
import Testing
@testable import WhateverTracker

@Suite("Chart data")
struct ChartDataTests {

    let newYork = calendar("America/New_York")
    let today = DayKey(year: 2026, month: 3, day: 20)

    // MARK: - Ranges

    @Test("A week is seven days including today, not seven days before it")
    func weekRange() {
        let start = ChartData.start(
            of: .week, today: today,
            earliest: DayKey(year: 2020, month: 1, day: 1), calendar: newYork
        )
        #expect(start == DayKey(year: 2026, month: 3, day: 14))
    }

    @Test("A fixed window is shown in full, so a short history reads as gaps")
    func fixedWindowIsNotTrimmed() {
        let first = DayKey(year: 2026, month: 3, day: 18)
        #expect(ChartData.start(of: .week, today: today, earliest: first, calendar: newYork)
            == DayKey(year: 2026, month: 3, day: 14))
    }

    @Test("All starts at the first entry, because there is no window to fill")
    func allStartsAtTheFirstEntry() {
        let first = DayKey(year: 2026, month: 3, day: 18)
        #expect(ChartData.start(of: .all, today: today, earliest: first, calendar: newYork) == first)
    }

    @Test("Nothing logged means nothing to draw")
    func emptyRange() {
        #expect(ChartData.start(of: .all, today: today, earliest: nil, calendar: newYork) == nil)
    }

    // MARK: - Daily totals

    @Test("Every day in the range gets a bar, including the empty ones")
    func gapsAreKept() {
        let start = DayKey(year: 2026, month: 3, day: 18)
        let totals: [DayKey: Double] = [start: 2_000, today: 1_500]

        let points = ChartData.dailyTotals(from: start, to: today, calendar: newYork) {
            totals[$0] ?? 0
        }

        #expect(points.map(\.value) == [2_000, 0, 1_500])
        #expect(points.map { DayKey($0.date, calendar: newYork).day } == [18, 19, 20])
    }

    @Test("Bars land on the real start of each day, even the one without a midnight")
    func barsUseTheRealStartOfDay() {
        let santiago = calendar("America/Santiago")
        let start = DayKey(year: 2019, month: 9, day: 7)
        let end = DayKey(year: 2019, month: 9, day: 9)

        let points = ChartData.dailyTotals(from: start, to: end, calendar: santiago) { _ in 1 }

        #expect(points.count == 3)
        // 8 September 2019 began at 01:00 in Chile; anchoring to a computed
        // midnight would put this bar on the wrong day.
        #expect(santiago.dateComponents([.hour], from: points[1].date).hour == 1)
        #expect(points.map { DayKey($0.date, calendar: santiago).day } == [7, 8, 9])
    }

    @Test("A range that crosses a DST change has the right number of bars")
    func barCountAcrossDST() {
        // 8 to 12 March 2019 spans the US spring forward.
        let points = ChartData.dailyTotals(
            from: DayKey(year: 2019, month: 3, day: 8),
            to: DayKey(year: 2019, month: 3, day: 12),
            calendar: newYork
        ) { _ in 1 }

        #expect(points.count == 5)
    }

    @Test("A single day is one bar")
    func singleDay() {
        let points = ChartData.dailyTotals(from: today, to: today, calendar: newYork) { _ in 7 }
        #expect(points.map(\.value) == [7])
    }

    // MARK: - Measurements

    @Test("Readings before the range are left out")
    func readingsAreFiltered() {
        let tracker = UUID()
        let entries = [
            Entry(trackerID: tracker, value: 80, date: date(2026, 3, 1), modified: time(1)),
            Entry(trackerID: tracker, value: 79, date: date(2026, 3, 18), modified: time(1)),
        ]

        let points = ChartData.readings(entries, from: date(2026, 3, 14))

        #expect(points.map(\.value) == [79])
    }

    @Test("The moving average smooths, and starts before it has a full window")
    func movingAverage() {
        let points = (0..<4).map {
            ChartPoint(date: date(2026, 3, 1).addingTimeInterval(Double($0) * 86_400),
                       value: [10.0, 20, 30, 40][$0])
        }

        let average = ChartData.movingAverage(points, days: 7)

        #expect(average.map(\.value) == [10, 15, 20, 25])
        #expect(average.map(\.date) == points.map(\.date))
    }

    @Test("The window drops readings that have fallen out of it")
    func movingAverageWindow() {
        let start = date(2026, 3, 1)
        let points = [
            ChartPoint(date: start, value: 100),
            ChartPoint(date: start.addingTimeInterval(8 * 86_400), value: 50),
            ChartPoint(date: start.addingTimeInterval(9 * 86_400), value: 60),
        ]

        let average = ChartData.movingAverage(points, days: 7)

        // The first reading is more than seven days behind the others.
        #expect(average.map(\.value) == [100, 50, 55])
    }

    @Test("One reading is not a trend")
    func movingAverageNeedsTwoPoints() {
        let single = [ChartPoint(date: date(2026, 3, 1), value: 78)]
        #expect(ChartData.movingAverage(single).isEmpty)
        #expect(ChartData.movingAverage([]).isEmpty)
    }
}
