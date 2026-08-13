import Foundation

/// A number, a tracker, a time, a name and the batch it was saved in. That is
/// all an entry ever gets to be — no categories, no tags, no meal types, no
/// photos.
struct Entry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var trackerID: UUID
    var value: Double
    /// When the entry happened — editable, and often backdated.
    var date: Date = .stamp()
    /// What you logged, said the way you'd say it: "porridge", not "calories".
    ///
    /// One field, doing three jobs — the label in the history, the thing search
    /// will look at, and the reason presets need no library of their own. You
    /// don't log protein, you log a food; naming it is what lets you find it
    /// again. See docs/PRODUCT.md.
    var name: String?
    /// The other entries written by the same save.
    ///
    /// One logged food is 100 kcal and 10 g of protein, and this is what makes
    /// those two rows a single thing to edit or delete rather than two that
    /// happen to share a timestamp.
    var batchID: UUID?
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

// There is deliberately no `Pin` type.
//
// Saved values used to be their own record: you logged something, starred it,
// and it stayed. Search-and-repeat replaces that with nothing at all — your
// named entries already are the library, so the feature arrives by *removing*
// a model type rather than adding one (docs/PRODUCT.md). A stored preset would
// have brought a merge case, a tombstone case and a way to drift out of step
// with the history it was copied from.
