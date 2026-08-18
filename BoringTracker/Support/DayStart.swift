import Foundation

/// The hour the day is cut at, for people whose day does not end when the clock
/// says so.
///
/// **This reverses a decision recorded in docs/TECH.md** — "the day starts at
/// midnight, local. No configurable day start; it multiplies edge cases in
/// every aggregation for a minority want." The reason there was cost, not
/// principle, and the cost turned out to be lower than it was written to be:
/// entries store absolute dates, so this is a **displayed** decision computed
/// at read time. Nothing is stored, nothing is migrated, and turning it back to
/// midnight re-derives exactly what was there before. Somebody who eats at 1am
/// is also not a minority of one.
///
/// **UI state, so it lives in `UserDefaults` and not the document**, the same
/// place and for the same reason as `Appearance`: it says how this phone reads
/// the numbers, not what the numbers are, and a document that carried it would
/// export it, merge it, and change what the other device's totals mean.
enum DayStart {
    /// The `UserDefaults` key, named once so the store and the picker cannot
    /// disagree about it.
    static let key = "dayStartHour"

    /// Every hour a day may start at. Whole hours only: half past four is not
    /// a want anybody has expressed, and it would double the picker for it.
    static let hours = Array(0...23)

    static let midnight = 0

    /// Clamps whatever is in `UserDefaults` to something a day can start at.
    /// A key that has never been written reads 0, which is midnight, which is
    /// what the app did before this existed.
    static func hour(_ stored: Int) -> Int {
        hours.contains(stored) ? stored : midnight
    }

    /// How an hour is offered in the picker: "Midnight", or the time written
    /// the way this phone writes times, so a 24-hour region sees 04:00 and a
    /// 12-hour one sees 4:00 AM.
    ///
    /// Formatted off **1 February**, which is the one month with no daylight
    /// saving transition in either hemisphere. `calendar.date(from:)` answers a
    /// time that does not exist with the next one that does, so a date chosen
    /// carelessly would label 2am as "3:00 AM" once a year in whichever region
    /// was springing forward that day.
    ///
    /// **The style is given this calendar's zone and locale rather than
    /// inheriting the device's.** `Date.formatted` defaults to the current time
    /// zone, so a date built at 2am in one zone came back out as "9:00 PM" —
    /// the right instant, described from somewhere else. Nothing in the app hit
    /// that, because there the two zones are the same one; the test that pins
    /// a zone did, immediately.
    static func label(_ hour: Int, calendar: Calendar = .current) -> String {
        guard hour != midnight else { return "Midnight" }
        let parts = DateComponents(year: 2001, month: 2, day: 1, hour: hour)
        guard let date = calendar.date(from: parts) else { return "\(hour):00" }
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        if let locale = calendar.locale { style.locale = locale }
        return date.formatted(style)
    }
}
