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
    /// When this record last changed. Used to resolve edits made on two
    /// devices — newer wins. See "Mergeable by design" in docs/TECH.md.
    var modified: Date = .stamp()

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
    /// What a brand new install starts with, so the app is useful before it
    /// has been configured at all.
    static var starterSet: [Tracker] {
        [
            Tracker(name: "Calories", unit: "kcal", kind: .dailyTotal, sortIndex: 0),
            Tracker(name: "Protein", unit: "g", kind: .dailyTotal, sortIndex: 1),
        ]
    }
}
