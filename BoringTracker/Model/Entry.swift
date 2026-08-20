import Foundation

struct Entry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var trackerID: UUID
    var value: Double
    var date: Date = .stamp()
    /// What you logged, said the way you'd say it: "porridge", not "calories".
    var name: String?
    /// The other entries written by the same log.
    var batchID: UUID?
    /// When the record last changed, not when the entry happened: editing last
    /// Tuesday's dinner today moves this and leaves `date` alone.
    var modified: Date = .stamp()
}

/// A deleted record, remembered rather than dropped: without this, merging two
/// devices resurrects everything deleted on one of them, because the other never
/// learned it was gone.
struct Tombstone: Codable, Hashable, Sendable {
    var id: UUID
    var deleted: Date
}
