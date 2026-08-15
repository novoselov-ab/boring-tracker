import Foundation
import Testing
@testable import BoringTracker

@Suite("CSV export")
struct CSVExportTests {
    @Test("CSV is one row per entry and exposes the batch that reconstructs a log")
    func oneRowPerEntry() throws {
        let tracker = Tracker(name: "Calories", unit: "kcal", group: "Food")
        let batch = UUID()
        let first = Entry(trackerID: tracker.id, value: 100, date: time(10),
                          name: "chicken rice", batchID: batch)
        let second = Entry(trackerID: tracker.id, value: 200, date: time(20))
        let document = StoreDocument(trackers: [tracker], entries: [first, second])

        let rows = try #require(String(data: CSVExport.data(document: document), encoding: .utf8))
            .split(separator: "\r\n", omittingEmptySubsequences: true)

        #expect(rows.count == 3)
        #expect(rows[0] == "entry_id,batch_id,date,tracker_id,tracker_name,tracker_unit,tracker_kind,value,name")
        #expect(rows[1].contains(batch.uuidString))
        #expect(rows[1].contains("chicken rice"))
        #expect(rows[2].contains(",,"))
    }

    @Test("Commas, quotes, and newlines follow ordinary CSV escaping")
    func escaping() throws {
        let tracker = Tracker(name: "Food, \"home\"", unit: "g")
        let entry = Entry(trackerID: tracker.id, value: 1.5, date: time(10), name: "one\nline")
        let text = try #require(String(
            data: CSVExport.data(document: StoreDocument(trackers: [tracker], entries: [entry])),
            encoding: .utf8
        ))

        #expect(text.contains("\"Food, \"\"home\"\"\""))
        #expect(text.contains("\"one\nline\""))
        #expect(text.hasSuffix("\r\n"))
    }

    @Test("An entry survives tracker deletion with its tracker id and blank metadata")
    func deletedTracker() throws {
        let trackerID = UUID()
        let entry = Entry(trackerID: trackerID, value: 42, date: time(10))
        let text = try #require(String(
            data: CSVExport.data(document: StoreDocument(entries: [entry])), encoding: .utf8
        ))

        #expect(text.contains(",\(trackerID.uuidString),,,,42.0,"))
    }
}
