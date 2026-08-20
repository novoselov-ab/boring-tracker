import Foundation

/// How the store document is written and read. The store file is also the
/// export file, so the format is published rather than internal: pretty-printed,
/// sorted keys, ISO 8601 (docs/TECH.md).
enum StoreCoding {

    /// ISO 8601, whole seconds. Milliseconds do not round-trip: `…:38.328Z`
    /// parses to a Double a hair below 38.328, which formats back as `…:38.327Z`,
    /// so a document stopped equalling itself after a save and a load.
    static let dateStyle = Date.ISO8601FormatStyle()

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

    /// Now, at the precision the file can hold (`dateStyle`). A finer timestamp
    /// survives in memory but changes on the first save and load, which can flip
    /// a merge decision after a round trip.
    static func stamp() -> Date { Date().canonicalized }

    var canonicalized: Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.rounded())
    }
}
