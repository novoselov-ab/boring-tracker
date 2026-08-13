import Foundation

/// A thing you track. See docs/PRODUCT.md — there are exactly two kinds, and
/// that is the only real decision the user makes.
struct Tracker: Codable, Identifiable, Hashable, Sendable {

    enum Kind: String, Codable, Sendable, CaseIterable {
        /// Entries add up over the day and the total resets at midnight.
        /// Calories, protein, water, cigarettes, pushups.
        case dailyTotal
        /// Each entry is a standalone reading. Weight, the cat's weight.
        case measurement
    }

    var id: UUID = UUID()
    var name: String
    var unit: String = ""
    var kind: Kind = .dailyTotal
    /// Digits shown after the decimal point. 0 for calories, 1 for weight.
    var decimals: Int = 0
    var sortIndex: Int = 0
    var isArchived: Bool = false
    /// Which trackers get logged at the same time. `Food` holds Calories and
    /// Protein; `Weight` holds your weight, and later the cat's.
    ///
    /// Deliberately a string rather than an entity: there is nothing to create,
    /// nothing to manage, no empty sections and no orphans. Empty means the
    /// tracker isn't grouped with anything. See docs/PRODUCT.md — the moment
    /// sections get their own screen, this app has grown the management UI it
    /// exists to avoid.
    var section: String = ""
    /// When this record last changed. Used to resolve edits made on two
    /// devices — newer wins. See "Mergeable by design" in docs/TECH.md.
    ///
    /// Everything except `sortIndex`, which has its own stamp below.
    var modified: Date = .stamp()
    /// When this tracker last moved, as opposed to last changed.
    ///
    /// `sortIndex` gets its own timestamp because it is the one field that is
    /// routinely rewritten without anybody editing anything: dragging one row
    /// renumbers every row it passed. Under a single `modified` that made a
    /// drag on this phone beat — and silently discard — a rename made on the
    /// iPad an hour earlier, since a merge compares whole records. Dropping the
    /// stamp instead was worse: two copies then differed only in `sortIndex`
    /// with equal timestamps, so the tie-break settled it by comparing the
    /// records as text, which is to say by comparing `sortIndex` itself, and
    /// each tracker independently took its highest index. That produces
    /// duplicate indices and an order neither device chose.
    ///
    /// Two stamps cost one `Date` and settle both: a rename and a reorder made
    /// on different devices now both survive, because they no longer compete.
    var orderModified: Date = .stamp()

    /// Formats a value the way this tracker wants to be read: grouped
    /// thousands, fixed decimals, unit appended if there is one.
    func format(_ value: Double, includeUnit: Bool = true) -> String {
        let number = value.formatted(
            .number.precision(.fractionLength(decimals)).grouping(.automatic)
        )
        guard includeUnit, !unit.isEmpty else { return number }
        return "\(number) \(unit)"
    }

    /// The value as it would be typed into the number pad: no grouping
    /// separators, no trailing zeros, so it reads back through `NumberInput`
    /// as the same number in every region.
    func editText(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0...max(decimals, 1)))
                .grouping(.never)
                .locale(locale)
        )
    }
}

extension Tracker {

    /// The winning record, wearing whichever position was set more recently.
    ///
    /// Handed to the merge so that losing on content does not cost a tracker
    /// its place in the list, and winning on content does not let a stale
    /// position overwrite a newer drag.
    ///
    /// The position is resolved without reference to which record won on
    /// content: newer `orderModified` takes it, and two positions stamped in
    /// the same second are settled by taking the lower index. Deciding a tie by
    /// "whoever won the content" would read a different answer depending on
    /// what had already been merged, and cost associativity — three documents
    /// would land differently depending on the order they were combined in.
    /// Reduced this way each half is an independent join, which is what keeps
    /// the merge commutative and associative under the fuzz tests.
    static func keepingNewerOrder(_ winner: Tracker, _ loser: Tracker) -> Tracker {
        var result = winner
        if loser.orderModified > winner.orderModified {
            result.sortIndex = loser.sortIndex
            result.orderModified = loser.orderModified
        } else if loser.orderModified == winner.orderModified {
            result.sortIndex = min(winner.sortIndex, loser.sortIndex)
        }
        return result
    }

    /// What a brand new install starts with, so the app is useful before it
    /// has been configured at all.
    static var starterSet: [Tracker] {
        [
            Tracker(name: "Calories", unit: "kcal", kind: .dailyTotal, sortIndex: 0,
                    section: "Food"),
            Tracker(name: "Protein", unit: "g", kind: .dailyTotal, sortIndex: 1,
                    section: "Food"),
            Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1, sortIndex: 2,
                    section: "Weight"),
        ]
    }
}
