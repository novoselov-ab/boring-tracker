import Foundation

/// Metric or imperial, chosen once on the welcome screen.
///
/// Two options and not three. `Locale` tells `.uk` from `.us`, but the only unit
/// here that differs between them is body weight, and the UK weighs itself in
/// stones — a unit this app cannot write, since an entry is one number.
enum UnitSystem: String, CaseIterable, Identifiable, Sendable {
    case metric
    case imperial

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }

    /// What the phone's region uses. Offered as the preselected answer, never
    /// applied without one.
    static func preferred(_ locale: Locale = .current) -> UnitSystem {
        locale.measurementSystem == .metric ? .metric : .imperial
    }
}

/// One tracker the welcome screen offers to create.
///
/// **`StarterTracker.offered` below is the starter set**, and it is the whole of
/// it: nothing else in the app creates a tracker on your behalf. It replaced
/// `Tracker.starterSet`, a constant three that a fresh install wrote before
/// anybody had said anything.
struct StarterTracker: Identifiable, Hashable, Sendable {

    var name: String
    var kind: Tracker.Kind
    var metricUnit: String = ""
    /// Empty means the metric unit is the unit in both systems: a kcal is a kcal.
    var imperialUnit: String = ""
    var decimals: Int = 0
    var group: String = ""
    /// Ticked when the screen opens, so the button at the bottom is an answer
    /// rather than a prompt.
    var isPreselected: Bool = false

    /// The name, which is also what the screen shows and what a chosen set holds.
    var id: String { name }

    func unit(_ system: UnitSystem) -> String {
        switch system {
        case .metric: metricUnit
        case .imperial: imperialUnit.isEmpty ? metricUnit : imperialUnit
        }
    }

    func tracker(units: UnitSystem, sortIndex: Int) -> Tracker {
        Tracker(
            name: name, unit: unit(units), kind: kind, decimals: decimals,
            sortIndex: sortIndex, group: group
        )
    }
}

extension StarterTracker {

    /// Everything on offer, in the order the screen lists it.
    ///
    /// The ticked three are what every install before 1.1 was given. *Dentist*
    /// is here because the `lastTime` kind is otherwise invisible on a fresh
    /// install — the App Store screenshot advertises it and the README names
    /// it, and until this screen nothing in the app introduced it. Unticked,
    /// because it has to be *intermittent* to read as anything but a date: a
    /// daily habit under a last-time tracker always says "today". See
    /// docs/PRODUCT.md.
    static let offered: [StarterTracker] = [
        StarterTracker(name: "Calories", kind: .dailyTotal, metricUnit: "kcal",
                       group: "Food", isPreselected: true),
        StarterTracker(name: "Protein", kind: .dailyTotal, metricUnit: "g",
                       group: "Food", isPreselected: true),
        StarterTracker(name: "Carbs", kind: .dailyTotal, metricUnit: "g",
                       group: "Food"),
        StarterTracker(name: "Fats", kind: .dailyTotal, metricUnit: "g",
                       group: "Food"),
        StarterTracker(name: "Weight", kind: .measurement, metricUnit: "kg",
                       imperialUnit: "lb", decimals: 1, group: "Weight",
                       isPreselected: true),
        StarterTracker(name: "Dentist", kind: .lastTime),
    ]

    static var preselected: Set<StarterTracker.ID> {
        Set(offered.lazy.filter(\.isPreselected).map(\.id))
    }

    /// The trackers a choice makes, in the order `offered` lists them rather than
    /// the order they were ticked in.
    static func trackers(_ chosen: Set<ID>, units: UnitSystem) -> [Tracker] {
        offered.filter { chosen.contains($0.id) }
            .enumerated()
            .map { $1.tracker(units: units, sortIndex: $0) }
    }

    /// What the welcome screen's button creates if nothing on it is touched.
    static func defaultTrackers(units: UnitSystem = .metric) -> [Tracker] {
        trackers(preselected, units: units)
    }
}
