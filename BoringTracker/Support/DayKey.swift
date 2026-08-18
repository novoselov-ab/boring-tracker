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

    /// The day a moment belongs to, in this calendar and with this day start.
    ///
    /// `dayStartHour` is the hour the day is cut at — 0 for midnight, 4 for
    /// somebody whose day ends when they go to bed rather than when the clock
    /// says so (docs/TODO.md). It is a **displayed** decision: entries store
    /// absolute dates and nothing about the offset is written down, so changing
    /// it re-derives every total and migrates nothing.
    ///
    /// **The comparison is on the wall clock, not on seconds.** Subtracting
    /// `dayStartHour * 3600` from the date first is the obvious version and it
    /// is wrong across DST: on a spring-forward day an entry at 04:30 with a
    /// 4am start goes back four *absolute* hours, which is five wall-clock
    /// hours through the missing one, lands at 23:30 the previous evening and
    /// is filed under yesterday. Reading the hour and stepping a calendar day
    /// cannot do that — and on a day whose 2am never happened, a 2am start
    /// simply begins at 3am, which is what the calendar says that morning.
    ///
    /// Costs nothing at the default: the branch is `hour < dayStartHour`, and
    /// at 0 no hour is. Above it, only entries inside the first few hours of a
    /// day pay for the extra step, on a walk `rebuildTotals` makes over every
    /// entry there is.
    init(_ date: Date, calendar: Calendar = .current, dayStartHour: Int = 0) {
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        self.year = parts.year ?? 0
        self.month = parts.month ?? 0
        self.day = parts.day ?? 0
        if let hour = parts.hour, hour < dayStartHour {
            self = adding(days: -1, calendar: calendar)
        }
    }

    static var today: DayKey { DayKey(Date()) }

    /// The moment this day begins, in the given calendar.
    ///
    /// Midnight by default. On a DST spring-forward day some regions have no
    /// 00:00, so this asks the calendar for the real start of the day rather
    /// than assuming it.
    ///
    /// **The offset is a wall-clock hour that gets *set*, not a number of hours
    /// that gets added**, and the difference is a whole hour once a year.
    /// Adding four hours to midnight on a fall-back day walks through the
    /// repeated hour and lands at 03:00, an hour before the day it claims to
    /// start — measured on `America/New_York`, 3 November 2019, where
    /// `DayKey(startOfDay(dayStartHour: 4), dayStartHour: 4)` then came back as
    /// the *2nd*. The init below reads the wall clock, so the two only agree if
    /// this does too. Spring forward happened to be fine either way, which is
    /// why only a fall-back test catches it.
    ///
    /// `.nextTime` is what answers an hour that does not exist — a 2am start on
    /// the morning that has no 2am begins at 3am — and on the morning that has
    /// two 1ams the search from midnight forward finds the first, which is
    /// where that day begins.
    func startOfDay(calendar: Calendar = .current, dayStartHour: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        guard let date = calendar.date(from: parts) else { return .distantPast }
        let midnight = calendar.startOfDay(for: date)
        guard dayStartHour != 0 else { return midnight }
        return calendar.date(
            bySettingHour: dayStartHour, minute: 0, second: 0, of: midnight,
            matchingPolicy: .nextTime, direction: .forward
        ) ?? midnight
    }

    /// What to call this day on screen: "Today", "Yesterday", or the date.
    ///
    /// Shared by History's section headings and the Repeat screen's rows, which
    /// have to agree — the same day named two ways on two screens is the
    /// complaint docs/TODO.md item 13 is named after. The year is left off
    /// inside the current one, where it says nothing on every row.
    func label(today: DayKey, calendar: Calendar = .current) -> String {
        if self == today { return "Today" }
        if self == today.adding(days: -1, calendar: calendar) { return "Yesterday" }
        let start = startOfDay(calendar: calendar)
        return if year == today.year {
            start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        } else {
            start.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }

    /// The day `days` away on the calendar.
    ///
    /// Deliberately has no `dayStartHour`: this is arithmetic over year, month
    /// and day, and where the day is cut has nothing to say about which date
    /// follows which. Stepping through midnight keeps it that way and keeps it
    /// DST-safe, which is what the day-boundary suite pins down.
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
