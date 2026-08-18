import SwiftUI

/// The history: every entry, newest first, grouped by the day it belongs to.
///
/// Takes an id rather than a `Tracker` so it always reads the current one —
/// rename a tracker and this follows without any plumbing.
struct TrackerDetailView: View {
    let trackerID: UUID

    @Environment(Store.self) private var store
    @State private var editing: Entry?
    @State private var logging: LogSheet.Target?

    var body: some View {
        Group {
            if let tracker = store.tracker(trackerID) {
                content(tracker)
            } else {
                ContentUnavailableView("Tracker deleted", systemImage: "trash")
            }
        }
        .sheet(item: $editing) { entry in
            EntryEditor(entry: entry)
        }
        .sheet(item: $logging) { target in
            LogSheet(target: target)
        }
    }

    @ViewBuilder
    private func content(_ tracker: Tracker) -> some View {
        // Read once. `days` is a computed property and this function asked it
        // three questions — the chart's guard below, the empty state's, and the
        // `ForEach` — so a five-year history walked, grouped and sorted one
        // tracker's entries three times per redraw. Counted with a counter in
        // the property rather than estimated: three reads costing 31.3–31.7ms
        // against one costing 12.0–13.0ms, at 29,320 entries. (This said "four
        // questions … 35ms where one walk is 9ms" until the count and the
        // timings were both re-measured; docs/scale.md carries the correction.)
        let days = days
        List {
            if let deleted = store.lastDeletion(for: trackerID) {
                undoRow(tracker, deleted: deleted)
            }
            if !days.isEmpty {
                Section {
                    TrackerChart(tracker: tracker)
                }
            }
            if days.isEmpty {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "number",
                    description: Text("Tap + to add the first \(tracker.name.lowercased()).")
                )
                .listRowBackground(Color.clear)
            }
            // One section for the whole log, not one per day — the same fix
            // History needed and for the same measured reason: a `Section`
            // costs about 0.8ms whatever is in it, so a five-year history's
            // 1,733 days were 1.0 second of blocked main thread every time
            // this screen opened. See `HistoryView` and docs/scale.md for the
            // four measurements that rule out the rows, the header and the
            // list style.
            //
            // The chart and the undo row stay sections of their own: there are
            // at most two of them, and they are genuinely separate things.
            //
            // Guarded, where `ForEach` over nothing needed no guard: an empty
            // `Section` still draws its own gap under the empty state.
            if !days.isEmpty {
                Section {
                    ForEach(days, id: \.day) { group in
                        dayHeading(tracker, group: group)
                        ForEach(group.entries) { entry in
                            row(tracker, entry: entry)
                        }
                    }
                }
            }
        }
        .navigationTitle(tracker.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Log", systemImage: "plus") {
                    LogSheet.present(
                        .init(group: LogGroup(of: tracker), tracker: trackerID),
                        using: $logging
                    )
                }
                .navBarAccent()
            }
        }
    }

    private func row(_ tracker: Tracker, entry: Entry) -> some View {
        Button {
            editing = entry
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.format(entry.value))
                        .font(.body.monospacedDigit())
                    if let name = entry.name, !name.isEmpty {
                        Text(name)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                store.delete(entry)
            }
            // The same fix History's swipe needed, on the same day: the root
            // `.tint(.primary)` reaches a swipe action and `role: .destructive`
            // loses to it, so this drew as a white capsule with an invisible
            // glyph (docs/TODO.md item 20). Settings' archive swipe already
            // named `.tint(.orange)`, which is why that one was never wrong —
            // the rule is that a swipe action states its own colour.
            .tint(.red)
        }
    }

    /// The day heading, as a row rather than a section header — see
    /// `HistoryView.dayHeading` for why it is a row at all, and for how
    /// `.headline` in `.secondary` was matched against a real one.
    ///
    /// It still carries the day's total on the right, which is the thing this
    /// screen's headings do that History's do not — and the thing that makes
    /// the trait below belong to the label rather than to the row.
    ///
    /// **This heading and `HistoryView.dayHeading` are two drawings of one
    /// thing, and they have already come apart once**: the trait went on the
    /// container here and on the only `Text` there, so only this screen got the
    /// bug below. Anything changed in one of them wants looking at in the other.
    private func dayHeading(_ tracker: Tracker, group: DayGroup) -> some View {
        HStack {
            Text(title(for: group.day))
                // On the day's label alone, never on the `HStack`. A trait set
                // on a container reaches every child it holds, so up there it
                // made the day's *total* a heading too, and the VoiceOver
                // headings rotor — the one thing that makes a five-year list
                // navigable without scrolling it — came out twice as long with
                // every other stop a bare number: `Today`, `250 kcal`,
                // `Sun, Aug 16`, `5,550 kcal`, read off the live accessibility
                // tree, which is 3,466 stops for 1,733 days. The same read of
                // the section header this replaced shows it marking its label
                // and leaving its total alone, so this is that restored.
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if tracker.kind == .dailyTotal {
                Text(tracker.format(store.total(for: trackerID, on: group.day)))
                    .monospacedDigit()
            }
        }
        .font(.headline)
        .foregroundStyle(.secondary)
        // And no `.accessibilityElement(children: .combine)` here, though a
        // heading reading as one phrase would be nicer than two: it costs 180ms
        // of the 400 this screen now takes to open, because combining children
        // is not lazy the way a row's body is — every one of 1,733 headings
        // resolves its children whether or not it is on screen. The section
        // header this replaced did not combine either, so nothing is lost that
        // was there before; what carries the rotor is the trait on the label
        // above, which is deliberately not up here.
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 6, trailing: 16))
    }

    /// Undo lives here rather than behind a confirmation, because a swipe you
    /// meant should be instant and a swipe you didn't should be cheap to fix.
    private func undoRow(_ tracker: Tracker, deleted: Entry) -> some View {
        Section {
            HStack {
                // Named honestly: undo puts the whole deletion back, so a batch
                // must not be announced as the one value that happens to be this
                // tracker's.
                Text(store.lastDeletionCount == 1
                     ? "Deleted \(tracker.format(deleted.value))"
                     : "Deleted batch")
                    .foregroundStyle(.secondary)
                Spacer()
                // The same capsule History's undo bar draws. It was a bare
                // `Button("Undo")` until the item 13d review found it: with the
                // tint set to the label colour (item 13c), the one control that
                // takes back a deletion was drawn exactly like the sentence
                // beside it, which is a recovery you have to hunt for.
                UndoButton { store.undoLastDeletion() }
            }
        }
    }

    // MARK: - Grouping

    struct DayGroup {
        var day: DayKey
        var entries: [Entry]
    }

    /// Newest day first, and newest entry first within each day — the order you
    /// read a log in. Cheap enough to do on demand: it walks one tracker's
    /// entries, which are already sorted.
    private var days: [DayGroup] {
        var groups: [DayKey: [Entry]] = [:]
        for entry in store.entries(for: trackerID) {
            groups[store.day(of: entry), default: []].append(entry)
        }
        return groups
            .sorted { $0.key > $1.key }
            .map { DayGroup(day: $0.key, entries: $0.value.reversed()) }
    }

    private func title(for day: DayKey) -> String {
        day.label(today: store.today, calendar: store.calendar)
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal")
    let store = Store(
        document: StoreDocument(
            trackers: [calories],
            entries: [
                Entry(trackerID: calories.id, value: 450, date: .now.addingTimeInterval(-3_600),
                      name: "usual breakfast"),
                Entry(trackerID: calories.id, value: 620, date: .now.addingTimeInterval(-7_200)),
                Entry(trackerID: calories.id, value: 1_830, date: .now.addingTimeInterval(-100_000)),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-detail"))
    )
    return NavigationStack {
        TrackerDetailView(trackerID: calories.id).environment(store)
    }
}
