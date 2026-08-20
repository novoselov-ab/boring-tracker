import Foundation

struct Tracker: Codable, Identifiable, Hashable, Sendable {

    enum Kind: String, Codable, Sendable, CaseIterable {
        case dailyTotal
        case measurement
        /// The date is the data and there is no number: tyres, a water filter,
        /// the dentist. See docs/PRODUCT.md.
        case lastTime

        var label: String {
            switch self {
            case .dailyTotal: "Daily total"
            case .measurement: "Measurement"
            case .lastTime: "Last time"
            }
        }
    }

    var id: UUID = UUID()
    var name: String
    var unit: String = ""
    /// The raw string, so a `kind` written by a later build survives being read
    /// and saved by this one — docs/TECH.md, "An unknown value is kept, not
    /// refused". The app asks `kind` below.
    var kindRaw: String = Kind.dailyTotal.rawValue
    var decimals: Int = 0
    var sortIndex: Int = 0
    var isArchived: Bool = false
    /// Empty means the tracker isn't grouped with anything. A string rather than
    /// an entity — docs/TECH.md, "Why a group is a string, not an entity".
    var group: String = ""
    /// Every field except `sortIndex`, which has `orderModified` below. Newer
    /// wins a conflicting edit — docs/TECH.md, "Mergeable by design".
    var modified: Date = .stamp()
    /// `sortIndex` only. It is the one field rewritten without anybody editing
    /// anything — dragging one row renumbers every row it passed — so under a
    /// single `modified` a drag here beat and silently discarded a rename made on
    /// another device. Dropping the stamp instead was worse: the copies then
    /// differed only in `sortIndex` with equal timestamps, and the text tie-break
    /// gave each tracker its own highest index.
    var orderModified: Date = .stamp()

    /// An unknown kind reads as `.measurement`: it shows the latest value and
    /// when it was taken, which is the shape that renders sensibly for a
    /// tracker built for behaviour this build does not have.
    ///
    /// **Setting it to what it already reads as writes nothing**, which is what
    /// keeps the editor's picker from destroying a kind it cannot draw. That
    /// picker shows `Measurement` for an unknown string, so tapping
    /// away and back looks like a revert and would otherwise save
    /// `"measurement"` over it — stamped newer, so the loss would then win the
    /// merge on every other device.
    var kind: Kind {
        get { Kind(rawValue: kindRaw) ?? .measurement }
        set { if newValue != kind { kindRaw = newValue.rawValue } }
    }

    /// Written out because the stored property is `kindRaw` and every caller
    /// says `kind:`.
    init(
        id: UUID = UUID(), name: String, unit: String = "", kind: Kind = .dailyTotal,
        decimals: Int = 0, sortIndex: Int = 0, isArchived: Bool = false, group: String = "",
        modified: Date = .stamp(), orderModified: Date = .stamp()
    ) {
        self.id = id
        self.name = name
        self.unit = unit
        self.kindRaw = kind.rawValue
        self.decimals = decimals
        self.sortIndex = sortIndex
        self.isArchived = isArchived
        self.group = group
        self.modified = modified
        self.orderModified = orderModified
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, unit
        case kindRaw = "kind"
        case decimals, sortIndex, isArchived, group, modified, orderModified
    }

    func format(_ value: Double, includeUnit: Bool = true) -> String {
        let number = value.formatted(
            .number.precision(.fractionLength(decimals)).grouping(.automatic)
        )
        guard includeUnit, !unit.isEmpty else { return number }
        return "\(number) \(unit)"
    }

    /// What one entry reads as in the place a number goes.
    ///
    /// A `lastTime` entry has no number. Its date is the whole record and the 0
    /// in `Entry.value` is storage, never a reading — so every screen that draws
    /// an entry asks this rather than `format`, and none of them can print it
    /// (docs/TECH.md, "The value a `lastTime` entry does not have").
    func entryText(_ value: Double) -> String {
        kind == .lastTime ? "Logged" : format(value)
    }

    /// The value as it would be typed into the number pad: it has to read back
    /// through `NumberInput` as the same number in every region.
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
    /// The position is resolved without reference to who won on content, so each
    /// half is an independent join and the merge stays commutative and
    /// associative (held to it by the fuzz tests). Ties take the lower index.
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

    static var starterSet: [Tracker] {
        [
            Tracker(name: "Calories", unit: "kcal", kind: .dailyTotal, sortIndex: 0,
                    group: "Food"),
            Tracker(name: "Protein", unit: "g", kind: .dailyTotal, sortIndex: 1,
                    group: "Food"),
            Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1, sortIndex: 2,
                    group: "Weight"),
        ]
    }
}
