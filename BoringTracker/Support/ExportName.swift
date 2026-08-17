import Foundation

/// What an export is called when it lands in a folder.
///
/// Both exports used to be offered as `boring-tracker` and
/// `boring-tracker-entries`, so a second export of either was saved beside the
/// first as `boring-tracker 2` — a folder of them said nothing about when any
/// of them was taken, which is the one thing you want to know when you go
/// looking for the copy from before something went wrong.
enum ExportName {

    /// `boring-tracker-2026-08-16`, with no extension: `fileExporter` appends
    /// that from the content type, and a name carrying `.json` twice is what
    /// happens if this does it too.
    ///
    /// Year-month-day with padding, rather than anything the user's locale
    /// would write: a filename cannot hold the slashes half the world puts in a
    /// date, and this is the order that sorts a folder into the order the
    /// exports were taken.
    ///
    /// The day comes from `DayKey`, so it is the day the *device's* calendar
    /// says it is — the same rule the rest of the app derives a day by. Taken
    /// from a UTC clock instead, an evening export in California would be dated
    /// tomorrow.
    static func dated(_ stem: String, on date: Date = .now) -> String {
        let day = DayKey(date)
        return String(format: "%@-%04d-%02d-%02d", stem, day.year, day.month, day.day)
    }
}
