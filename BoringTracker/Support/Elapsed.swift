import Foundation

/// How long ago something happened, in whole days: `today`, `yesterday`,
/// `3 days ago`, `2 months ago`.
///
/// Whole days rather than hours, because that is the granularity a `lastTime`
/// tracker is about — a filter changed this morning and one changed before
/// breakfast are both *today* — and because the app already decides which day a
/// moment belongs to, day-start offset included. Both ends come in as `DayKey`,
/// so the boundary is the same one History gives a day its heading by.
enum Elapsed {

    /// Days, then months, then years. Weeks are deliberately left out: with them
    /// allowed the ladder reads `last week` at 7 days and `2 weeks ago` at 13,
    /// which is vaguer than the day count it replaces, and months take over soon
    /// enough anyway. Measured across 0…1000 days — days up to 30, `last month`
    /// at 31, `2 months ago` at 60, `last year` at 364, `2 years ago` at 730.
    private static let fields: Set<Date.RelativeFormatStyle.Field> = [.day, .month, .year]

    /// **The anchor is the entry and the formatted date is today**, which is the
    /// reverse of how the call reads. Measured: anchoring on today and
    /// formatting a date three days earlier says "in 3 days".
    ///
    /// Midnight at both ends rather than the store's day start, since only the
    /// number of calendar days between them is being asked. That keeps it right
    /// across a DST boundary, where the same two days are 23 or 25 hours apart.
    static func label(
        from day: DayKey, to today: DayKey,
        calendar: Calendar, locale: Locale = .autoupdatingCurrent
    ) -> String {
        Date.AnchoredRelativeFormatStyle(
            anchor: day.startOfDay(calendar: calendar),
            allowedFields: fields,
            presentation: .named,
            unitsStyle: .wide,
            locale: locale,
            calendar: calendar
        )
        .format(today.startOfDay(calendar: calendar))
    }
}
