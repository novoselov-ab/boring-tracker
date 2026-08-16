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

    @Test("Free-text names survive the round trip a spreadsheet parser makes")
    func adversarialNames() throws {
        // Names are typed by a person, so they contain whatever people type.
        // Every one of these must come back byte-identical through RFC 4180
        // parsing, which is what docs/TECH.md promises the file does.
        let names = [
            "rice, beans", "she said \"hi\"", "two\nlines", "carriage\r\nreturn",
            "=1+1", "+41 chicken", "-5 leftovers", "@SUM(A1:A2)", "\tleading tab",
        ]
        let tracker = Tracker(name: "Calories", unit: "kcal")
        let entries = names.enumerated().map { index, name in
            Entry(trackerID: tracker.id, value: Double(index), date: time(index), name: name)
        }
        let text = try #require(String(
            data: CSVExport.data(document: StoreDocument(trackers: [tracker], entries: entries)),
            encoding: .utf8
        ))

        let rows = parseCSV(text)
        // Structure first: a name that breaks the row apart shifts every column
        // after it, which is worse than losing the name.
        #expect(rows.count == names.count + 1)
        #expect(rows.allSatisfy { $0.count == CSVExport.columns.count })
        #expect(rows.dropFirst().map { $0[8] } == names)
    }
}

/// A minimal RFC 4180 reader, so the escaping is checked by parsing rather than
/// by asserting on the exact bytes the writer happened to produce.
///
/// Over unicode scalars, not characters: Swift treats CRLF as a single
/// `Character`, so a character-wise reader never sees the `\r` that ends a row.
private func parseCSV(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var field = String.UnicodeScalarView()
    var quoted = false
    let scalars = Array(text.unicodeScalars)
    var index = 0
    while index < scalars.count {
        let scalar = scalars[index]
        if quoted {
            if scalar == "\"" {
                if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    quoted = false
                }
            } else {
                field.append(scalar)
            }
        } else if scalar == "\"" {
            quoted = true
        } else if scalar == "," {
            row.append(String(field))
            field = String.UnicodeScalarView()
        } else if scalar == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" {
            row.append(String(field))
            rows.append(row)
            row = []
            field = String.UnicodeScalarView()
            index += 1
        } else {
            field.append(scalar)
        }
        index += 1
    }
    if !field.isEmpty || !row.isEmpty {
        row.append(String(field))
        rows.append(row)
    }
    return rows
}
