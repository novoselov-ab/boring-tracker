import Charts
import SwiftUI

/// Daily totals as bars, measurements as a line with a moving average.
///
/// The points are aggregated when the range or the data changes, never inside
/// `body` on the way to a frame — which is what a computed property here would
/// mean while someone drags a finger across it.
struct TrackerChart: View {
    let tracker: Tracker

    @Environment(Store.self) private var store
    @State private var range: ChartRange = .week
    @State private var points: [ChartPoint] = []
    @State private var average: [ChartPoint] = []
    @State private var scrubbed: Date?

    /// The biggest the axis labels are allowed to get — see the chart's frame
    /// below. `.large` is the system's default size, the one the 180pt frame was
    /// chosen against.
    private static let labelCeiling = DynamicTypeSize.large

    private struct Key: Equatable {
        var range: ChartRange
        var revision: UInt64
        var today: DayKey
        /// Moving the day start rebuilds every bucket while changing neither
        /// `revision`'s meaning nor, at any hour past the new boundary,
        /// `today` — so without this the bars stay as they were while History
        /// and the home total show the new ones.
        var dayStart: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $range) {
                ForEach(ChartRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)

            readout

            chart
                .frame(height: 180)
                // **The labels stop growing where the box they are in stops
                // growing.** The plot is a fixed 180pt frame and its axis labels
                // were the one thing inside it that scaled: at AX5 all four x
                // labels read `A…` and the y labels touched each other and
                // overlapped the bars. A ceiling rather than a fixed size, so the
                // small end of the slider still shrinks with everything else.
                //
                // **Scaling the frame was built and photographed instead, and it
                // does not fix this**: 180pt to 320 gives the plot more height
                // and the x axis no more *width*, so the dates are still `A…`.
                .dynamicTypeSize(...Self.labelCeiling)
                .chartXSelection(value: $scrubbed)
        }
        .onChange(of: Key(range: range, revision: store.revision, today: store.today,
                          dayStart: store.dayStartHour),
                  initial: true) {
            recompute()
        }
    }

    @ViewBuilder
    private var chart: some View {
        Chart {
            switch tracker.kind {
            case .dailyTotal:
                ForEach(points) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value(tracker.name, point.value)
                    )
                    // The ordinary label colour, not the accent: a bar carries a
                    // value, not an affordance, and the accent as a foreground
                    // measured 1.90:1 against the chart's own background in light
                    // mode — a bar you cannot see is a chart that doesn't work.
                    .foregroundStyle(.primary)
                }
            case .measurement:
                ForEach(average) { point in
                    LineMark(
                        x: .value("When", point.date),
                        y: .value("Average", point.value),
                        series: .value("Series", "average")
                    )
                    .foregroundStyle(.secondary)
                    .interpolationMethod(.catmullRom)
                }
                ForEach(points) { point in
                    LineMark(
                        x: .value("When", point.date),
                        y: .value(tracker.name, point.value),
                        series: .value("Series", "readings")
                    )
                    // Label colour for the same reason as the bars. The average
                    // line stays `.secondary`, so the two are told apart by
                    // weight rather than by hue.
                    .foregroundStyle(.primary)
                    PointMark(
                        x: .value("When", point.date),
                        y: .value(tracker.name, point.value)
                    )
                    .foregroundStyle(.primary)
                    .symbolSize(points.count > 60 ? 0 : 20)
                }
            }

            if let marked {
                RuleMark(x: .value("Selected", marked.date))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .zIndex(-1)
            }
        }
        .chartYScale(domain: .automatic(includesZero: tracker.kind == .dailyTotal))
    }

    /// The scrubbed value, or the most recent one. Sitting above the chart so
    /// the layout doesn't jump when a finger lands on it.
    private var readout: some View {
        HStack(alignment: .firstTextBaseline) {
            if let marked {
                Text(tracker.format(marked.value))
                    .font(.title3.monospacedDigit())
                Text(marked.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(minHeight: 24)
    }

    private var marked: ChartPoint? {
        guard let scrubbed else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(scrubbed)) < abs($1.date.timeIntervalSince(scrubbed))
        }
    }

    /// No goals, so the only honest summary is what the numbers already say.
    private var summary: String {
        guard !points.isEmpty else { return "" }
        switch tracker.kind {
        case .dailyTotal:
            let logged = points.filter { $0.value != 0 }
            guard !logged.isEmpty else { return "" }
            let mean = logged.reduce(0) { $0 + $1.value } / Double(logged.count)
            return "\(tracker.format(mean)) a day on \(logged.count) logged days"
        case .measurement:
            let low = points.min { $0.value < $1.value }?.value ?? 0
            let high = points.max { $0.value < $1.value }?.value ?? 0
            return "\(tracker.format(low)) to \(tracker.format(high))"
        }
    }

    private func recompute() {
        scrubbed = nil
        let earliest = store.entries(for: tracker.id).first.map { store.day(of: $0) }
        guard let start = ChartData.start(
            of: range, today: store.today, earliest: earliest, calendar: store.calendar
        ) else {
            points = []
            average = []
            return
        }

        switch tracker.kind {
        case .dailyTotal:
            points = ChartData.dailyTotals(
                from: start, to: store.today, calendar: store.calendar,
                dayStartHour: store.dayStartHour
            ) { store.total(for: tracker.id, on: $0) }
            average = []
        case .measurement:
            points = ChartData.readings(
                store.entries(for: tracker.id),
                from: start.startOfDay(calendar: store.calendar, dayStartHour: store.dayStartHour)
            )
            average = ChartData.movingAverage(points)
        }
    }
}
