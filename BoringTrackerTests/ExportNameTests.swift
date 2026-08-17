import Foundation
import Testing
@testable import BoringTracker

@Suite("Export name")
struct ExportNameTests {

    /// Noon in the device's own calendar, which is what the name is derived in:
    /// asked in UTC, an evening export in California would be dated tomorrow,
    /// and this test would pass or fail depending on where it ran.
    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year, month: month, day: day, hour: 12
        ))!
    }

    @Test("An export is named for the day it was taken")
    func dated() {
        #expect(ExportName.dated("boring-tracker", on: noon(2026, 8, 16))
            == "boring-tracker-2026-08-16")
        #expect(ExportName.dated("boring-tracker-entries", on: noon(2026, 8, 16))
            == "boring-tracker-entries-2026-08-16")
    }

    @Test("Single digits are padded, or the names stop sorting as text")
    func padded() {
        #expect(ExportName.dated("x", on: noon(2026, 1, 2)) == "x-2026-01-02")
        #expect(ExportName.dated("x", on: noon(2026, 12, 31)) == "x-2026-12-31")
    }

    @Test("No extension: the exporter appends that from the content type")
    func noExtension() {
        #expect(!ExportName.dated("boring-tracker", on: noon(2026, 8, 16)).contains("."))
    }
}
