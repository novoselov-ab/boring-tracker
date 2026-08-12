import Foundation

/// How the store document is written and read.
///
/// The store file *is* the export file (docs/TECH.md), so this is a published
/// format, not an implementation detail: pretty-printed, sorted keys, ISO 8601
/// dates. It should open in a text editor and diff cleanly.
enum StoreCoding {

    /// ISO 8601, whole seconds.
    ///
    /// Milliseconds were tried and rejected on measurement: the format is not
    /// a fixed point at that precision. `…:38.328Z` parses to a Double a hair
    /// below 38.328, which formats back as `…:38.327Z`, so a document stopped
    /// equalling itself after a save and a load. Whole seconds are exactly
    /// representable, so the file is lossless — and a tracker that logs meals
    /// has no use for a finer clock. Two edits to the same record in the same
    /// second on two devices are settled by the merge tie-break instead.
    static let dateStyle = Date.ISO8601FormatStyle()

    /// Fresh instances rather than shared ones: `JSONEncoder` is a
    /// non-`Sendable` class, and constructing one costs far less than the
    /// ceremony of safely sharing it. Encoding happens on save, not per frame.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try Date(text, strategy: dateStyle)
        }
        return decoder
    }

    static func encode(_ document: StoreDocument) throws -> Data {
        try encoder().encode(document)
    }

    static func decode(_ data: Data) throws -> StoreDocument {
        try decoder().decode(StoreDocument.self, from: data)
    }
}

extension Date {

    /// Now, at the precision the store file can actually hold.
    ///
    /// A timestamp finer than the file format survives in memory but changes
    /// the moment it is saved and loaded again. That turns "export then import"
    /// into a document that no longer equals the original, and it can flip a
    /// merge decision after a round trip. Canonicalising at the point of
    /// creation makes the file lossless by construction.
    static func stamp() -> Date { Date().canonicalized }

    /// This date as it will come back after a save/load cycle.
    var canonicalized: Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.rounded())
    }
}
