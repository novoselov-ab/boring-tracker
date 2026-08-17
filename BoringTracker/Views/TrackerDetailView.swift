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
            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.entries) { entry in
                        row(tracker, entry: entry)
                    }
                } header: {
                    header(tracker, group: group)
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

    private func header(_ tracker: Tracker, group: DayGroup) -> some View {
        HStack {
            Text(title(for: group.day))
            Spacer()
            if tracker.kind == .dailyTotal {
                Text(tracker.format(store.total(for: trackerID, on: group.day)))
                    .monospacedDigit()
            }
        }
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
