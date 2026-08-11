import Foundation

/// A number, a tracker, a time. Optionally a short note. That is all an entry
/// ever gets to be — no categories, no tags, no meal types, no photos.
struct Entry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var trackerID: UUID
    var value: Double
    /// When the entry happened — editable, and often backdated.
    var date: Date = .stamp()
    var note: String?
    /// When the record last changed. Distinct from `date`: editing last
    /// Tuesday's dinner today moves `modified`, not `date`.
    var modified: Date = .stamp()
}

/// A deleted record, remembered rather than dropped.
///
/// Without this, merging two devices resurrects everything you deleted on one
/// of them — the other device never learned it was gone. Tombstones are
/// compacted away once they're older than any plausible offline period.
struct Tombstone: Codable, Hashable, Sendable {
    var id: UUID
    var deleted: Date
}

/// A saved value you can log with one tap. Presets are not created, they are
/// *kept*: recents show up on their own and pinning one makes it stay.
///
/// A pin can cover several trackers at once, because "usual breakfast" is
/// 450 kcal and 30 g of protein together, not two separate taps.
struct Pin: Codable, Identifiable, Hashable, Sendable {
    struct Amount: Codable, Hashable, Sendable {
        var trackerID: UUID
        var value: Double
    }

    var id: UUID = UUID()
    var label: String
    var amounts: [Amount]
    var sortIndex: Int = 0
    var modified: Date = .stamp()
}
