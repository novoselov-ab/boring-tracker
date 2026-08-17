import Charts
import SwiftUI

/// Daily totals as bars, measurements as a line with a moving average.
///
/// Nothing interactive beyond scrubbing for a value, and the points are
/// aggregated when the range or the data changes — never inside `body` on the
/// way to a frame, which is what a computed property here would mean while
/// someone drags a finger across it.
struct TrackerChart: View {
    let tracker: Tracker

    @Environment(Store.self) private var store
    @State private var range: ChartRange = .week
    @State private var points: [ChartPoint] = []
    @State private var average: [ChartPoint] = []
    @State private var scrubbed: Date?

    private struct Key: Equatable {
        var range: ChartRange
        var revision: UInt64
        var today: DayKey
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
                .chartXSelection(value: $scrubbed)
        }
        .onChange(of: Key(range: range, revision: store.revision, today: store.today),
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
                    // The ordinary label colour, not the accent. These were the
                    // accent, which as the old teal was 1.90:1 against the
                    // chart's own background in light mode — a bar you cannot
                    // see is a chart that doesn't work — and the accent is a
                    // fill for a dark label rather than something to draw with
                    // (docs/TODO.md item 13c). The colour has changed since and
                    // the rule has not: a bar carries a value, not an
                    // affordance, so it has nothing to say in a tint.
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
                    // The readings line and its points, in the label colour for
                    // the same reason as the bars above. The average line stays
                    // `.secondary`, so the two are still told apart by weight
                    // rather than by a hue one of them can no longer have.
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
                from: start, to: store.today, calendar: store.calendar
            ) { store.total(for: tracker.id, on: $0) }
            average = []
        case .measurement:
            points = ChartData.readings(
                store.entries(for: tracker.id),
                from: start.startOfDay(calendar: store.calendar)
            )
            average = ChartData.movingAverage(points)
        }
    }
}
