import Foundation

/// What the graph draws, computed once per range change rather than per frame.
///
/// Kept apart from the view because it is arithmetic over days, which is where
/// this app's bugs live — and arithmetic is testable in a way that a chart is
/// not.
enum ChartRange: String, CaseIterable, Identifiable, Sendable {
    case week, month, year, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .all: "All"
        }
    }

    /// How far back the range reaches, or nil for everything there is.
    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .year: 365
        case .all: nil
        }
    }
}

struct ChartPoint: Identifiable, Hashable, Sendable {
    /// The start of the day for a total, the moment itself for a reading.
    var date: Date
    var value: Double

    var id: Date { date }
}

enum ChartData {

    /// The first day a range covers. Returns nil when there is nothing at all
    /// to draw.
    ///
    /// A fixed window is shown in full even when the data starts later, rather
    /// than being trimmed to the first entry. Trimming made every range look
    /// identical for anyone with a few days of history, and it hides the thing
    /// a gap is telling you — that nothing was logged then.
    static func start(
        of range: ChartRange, today: DayKey, earliest: DayKey?, calendar: Calendar
    ) -> DayKey? {
        guard let earliest else { return nil }
        guard let days = range.days else { return earliest }
        return today.adding(days: -(days - 1), calendar: calendar)
    }

    /// One bar per day, including the days with nothing in them — a gap in a
    /// calorie chart is information, and closing it up would draw a week of
    /// eating as if it were continuous.
    static func dailyTotals(
        from start: DayKey, to end: DayKey, calendar: Calendar, total: (DayKey) -> Double
    ) -> [ChartPoint] {
        var points: [ChartPoint] = []
        var day = start
        while day <= end {
            points.append(
                ChartPoint(date: day.startOfDay(calendar: calendar), value: total(day))
            )
            day = day.adding(days: 1, calendar: calendar)
        }
        return points
    }

    /// Measurements are points in time, not sums, so they are plotted where
    /// they happened rather than bucketed into days.
    static func readings(_ entries: [Entry], from start: Date) -> [ChartPoint] {
        entries
            .filter { $0.date >= start }
            .map { ChartPoint(date: $0.date, value: $0.value) }
    }

    /// A trailing moving average, which is what makes a weight chart readable —
    /// the day-to-day noise is water, not you.
    ///
    /// The window is plain days of seconds: an hour of DST slop either side
    /// changes a smoothed line by nothing anyone can see.
    static func movingAverage(_ points: [ChartPoint], days: Int = 7) -> [ChartPoint] {
        guard points.count > 1 else { return [] }
        let window = Double(days) * 86_400
        var result: [ChartPoint] = []
        result.reserveCapacity(points.count)
        var first = 0
        var sum = 0.0

        for (index, point) in points.enumerated() {
            sum += point.value
            let cutoff = point.date.addingTimeInterval(-window)
            while points[first].date < cutoff {
                sum -= points[first].value
                first += 1
            }
            result.append(ChartPoint(date: point.date, value: sum / Double(index - first + 1)))
        }
        return result
    }
}
