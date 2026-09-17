import Foundation

/// A calendar day, with no time and no time zone attached.
///
/// Entries store an absolute `Date`. The day an entry belongs to is *derived* in
/// the device's current calendar and time zone, never stored — so flying across
/// time zones can shift a day's totals, which is the deliberate choice: your
/// totals should agree with the calendar you are currently living in.
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
    /// somebody whose day ends when they go to bed. It is a **displayed**
    /// decision: entries store absolute dates and nothing about the offset is
    /// written down, so changing it re-derives every total and migrates nothing.
    ///
    /// **The comparison is on the wall clock, not on seconds.** Subtracting
    /// `dayStartHour * 3600` from the date first is the obvious version and it is
    /// wrong across DST: on a spring-forward day an entry at 04:30 with a 4am
    /// start goes back four *absolute* hours, which is five wall-clock hours
    /// through the missing one, lands at 23:30 the previous evening and is filed
    /// under yesterday. Reading the hour and stepping a calendar day cannot do
    /// that.
    init(_ date: Date, calendar: Calendar = .current, dayStartHour: Int = 0) {
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        self.year = parts.year ?? 0
        self.month = parts.month ?? 0
        self.day = parts.day ?? 0
        if let hour = parts.hour, hour < dayStartHour {
            self = adding(days: -1, calendar: calendar)
        }
    }

    /// The moment this day begins, in the given calendar.
    ///
    /// **The offset is a wall-clock hour that gets *set*, not a number of hours
    /// that gets added**, and the difference is a whole hour once a year. Adding
    /// four hours to midnight on a fall-back day walks through the repeated hour
    /// and lands at 03:00, an hour before the day it claims to start — measured
    /// on `America/New_York`, 3 November 2019, where
    /// `DayKey(startOfDay(dayStartHour: 4), dayStartHour: 4)` then came back as
    /// the *2nd*. The init above reads the wall clock, so the two only agree if
    /// this does too. Spring forward is fine either way, which is why only a
    /// fall-back test catches it.
    ///
    /// **What it wants is this date's first moment at or after the hour**, which is
    /// not the same as "this date at `hour:00`": on a spring-forward morning that
    /// time can fail to happen at all. `date(bySettingHour:)` was here and answered
    /// the *following* date's — swept over every zone the system knows, every cut
    /// hour, 2024–2027, it landed outside the day it names in twelve places and a
    /// quarter of an hour inside it in three more.
    ///
    /// Asking each hour from the cut upward covers the first and the transition check
    /// below the second. A 2am cut on the morning whose whole 2am hour goes still
    /// begins at 3am, and where two 1ams happen the forward search still finds the
    /// first.
    func startOfDay(calendar: Calendar = .current, dayStartHour: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        guard let date = calendar.date(from: parts) else { return .distantPast }
        let midnight = calendar.startOfDay(for: date)
        guard dayStartHour != 0 else { return midnight }
        // Chile's 8 September 2019 has no midnight, so the date's first moment is
        // already 01:00 — past a 1am cut, and the answer. The search below starts
        // strictly after `midnight` and would step over it.
        guard calendar.component(.hour, from: midnight) < dayStartHour else { return midnight }
        for hour in dayStartHour...23 {
            guard let start = calendar.nextDate(
                after: midnight, matching: DateComponents(hour: hour),
                matchingPolicy: .nextTime, direction: .forward
            ), calendar.isDate(start, inSameDayAs: midnight) else { continue }
            // A clock that jumps forward by part of an hour leaves a sliver of the
            // cut hour standing, and the search above can only answer o'clock:
            // Chatham moves 02:45 to 03:45, so a 3am day begins at 03:45 and it
            // said 4.
            if let jump = calendar.timeZone.nextDaylightSavingTimeTransition(after: midnight),
               jump < start, calendar.component(.hour, from: jump) >= dayStartHour {
                return jump
            }
            return start
        }
        return calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: midnight) ?? midnight
        )
    }

    /// Shared by History's section headings and the Repeat screen's rows, which
    /// have to agree — the same day named two ways on two screens is its own kind
    /// of drift.
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

    /// Deliberately has no `dayStartHour`: this is arithmetic over year, month
    /// and day, and where the day is cut has nothing to say about which date
    /// follows which. Stepping through midnight keeps it DST-safe, which is what
    /// the day-boundary suite pins down.
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

    /// The day in `days` closest to `target` — the same day if it is there, so
    /// History's jump control lands on the nearest day with something on it
    /// rather than on an empty screen.
    ///
    /// **Order-independent, and it does not convert 1,700 days to dates.** The
    /// obvious version scans with a distance per candidate, which is a
    /// `DateComponents` round trip apiece. Comparing the keys themselves finds
    /// the closest day on each side in one pass, and only those two are
    /// converted.
    ///
    /// **The newer day wins a tie**, and only a tie. The list reads newest first,
    /// so landing above puts the other candidate below the fold in reading order
    /// rather than off the top of the screen.
    ///
    /// The distance is whole calendar days from the calendar, not seconds:
    /// subtracting dates gets a DST day wrong by an hour, which is only ever
    /// visible on a tie — and a tie is precisely what this has to decide.
    static func nearest(to target: DayKey, in days: [DayKey], calendar: Calendar) -> DayKey? {
        var above: DayKey?
        var below: DayKey?
        for day in days {
            if day >= target { above = above.map { min($0, day) } ?? day }
            if day <= target { below = below.map { max($0, day) } ?? day }
        }
        guard let above else { return below }
        guard let below else { return above }
        let base = target.startOfDay(calendar: calendar)
        let up = calendar.dateComponents(
            [.day], from: base, to: above.startOfDay(calendar: calendar)
        ).day ?? .max
        let down = calendar.dateComponents(
            [.day], from: below.startOfDay(calendar: calendar), to: base
        ).day ?? .max
        return up <= down ? above : below
    }
}
