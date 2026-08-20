import Foundation

/// What an export is called when it lands in a folder.
enum ExportName {

    /// `boring-tracker-2026-08-16`, **with no extension**: the one caller,
    /// `ExportFile.filename`, appends the one its format names, and a name
    /// carrying `.json` twice is what happens if this adds one too.
    ///
    /// Year-month-day with padding, rather than anything the user's locale would
    /// write: a filename cannot hold the slashes half the world puts in a date,
    /// and this is the order that sorts a folder into the order the exports were
    /// taken.
    ///
    /// The day comes from `DayKey`, so it is the day the *device's* calendar says
    /// it is. Taken from a UTC clock instead, an evening export in California
    /// would be dated tomorrow.
    static func dated(_ stem: String, on date: Date = .now) -> String {
        let day = DayKey(date)
        return String(format: "%@-%04d-%02d-%02d", stem, day.year, day.month, day.day)
    }
}
