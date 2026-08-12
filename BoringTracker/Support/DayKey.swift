import Foundation

/// A calendar day, with no time and no time zone attached.
///
/// Entries store an absolute `Date`. The day an entry belongs to is *derived*
/// in the device's current calendar and time zone, never stored. See
/// docs/TECH.md — flying across time zones can shift a day's totals, and that
/// is the deliberate choice: your totals should agree with the calendar you
/// are currently living in.
struct DayKey: Codable, Hashable, Comparable, Sendable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year ?? 0
        self.month = parts.month ?? 0
        self.day = parts.day ?? 0
    }

    static var today: DayKey { DayKey(Date()) }

    /// Midnight at the start of this day, in the given calendar.
    ///
    /// On a DST spring-forward day some regions have no 00:00, so this asks
    /// the calendar for the real start of the day rather than assuming it.
    func startOfDay(calendar: Calendar = .current) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        guard let date = calendar.date(from: parts) else { return .distantPast }
        return calendar.startOfDay(for: date)
    }

    func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        let base = startOfDay(calendar: calendar)
        guard let moved = calendar.date(byAdding: .day, value: days, to: base) else {
            return self
        }
        return DayKey(moved, calendar: calendar)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
