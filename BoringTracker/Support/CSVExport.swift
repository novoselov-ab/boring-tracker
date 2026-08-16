import Foundation

/// A spreadsheet-shaped view of the entry history.
///
/// JSON remains the complete, importable document. CSV is deliberately one
/// row per entry so ordinary spreadsheet tools can filter and chart it, with
/// `batch_id` carrying the fact that several rows were one log.
enum CSVExport {
    static let columns = [
        "entry_id", "batch_id", "date", "tracker_id", "tracker_name",
        "tracker_unit", "tracker_kind", "value", "name",
    ]

    static func data(document: StoreDocument) -> Data {
        let trackers = Dictionary(
            document.trackers.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var lines = [columns.joined(separator: ",")]
        lines.reserveCapacity(document.entries.count + 1)
        for entry in StoreDocument.sorted(document.entries) {
            let tracker = trackers[entry.trackerID]
            let fields = [
                entry.id.uuidString,
                entry.batchID?.uuidString ?? "",
                entry.date.formatted(StoreCoding.dateStyle),
                entry.trackerID.uuidString,
                tracker?.name ?? "",
                tracker?.unit ?? "",
                tracker?.kind.rawValue ?? "",
                String(entry.value),
                entry.name ?? "",
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    /// Asked of the scalars, not the characters. Swift treats CRLF as a single
    /// `Character`, so `contains("\r")` is *false* for a name holding one —
    /// which left a pasted Windows line break unquoted, split that row in two,
    /// and shifted every column of the remainder. A bare LF happened to be
    /// caught only because it is its own character.
    private static func escape(_ field: String) -> String {
        let needsQuoting = field.unicodeScalars.contains { scalar in
            scalar == "," || scalar == "\"" || scalar == "\r" || scalar == "\n"
        }
        guard needsQuoting else { return field }
        return "\"\(field.replacing("\"", with: "\"\""))\""
    }
}
