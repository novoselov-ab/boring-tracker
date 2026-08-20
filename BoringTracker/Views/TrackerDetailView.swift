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
        // Read once, deliberately. `days` is computed, and this function asks it
        // three questions; three reads cost 31.3–31.7ms against one at
        // 12.0–13.0ms, at 29,320 entries.
        let days = days
        List {
            // No chart for a `lastTime` tracker: it has no numbers to plot, and
            // the interval between one event and the next is a different idea
            // that this kind deliberately does not have (docs/PRODUCT.md).
            if !days.isEmpty, tracker.kind != .lastTime {
                Section {
                    TrackerChart(tracker: tracker)
                }
            }
            if days.isEmpty {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "number",
                    description: Text(tracker.kind == .lastTime
                        ? "Tap + the first time you do it."
                        : "Tap + to add the first \(tracker.name.lowercased()).")
                )
                .listRowBackground(Color.clear)
            }
            // One section for the whole log, not one per day: a `Section` costs
            // about 0.8ms whatever is in it, so a five-year history's 1,733 days
            // were 1.0s of blocked main thread every time this screen opened.
            // Rows are lazy; sections are not.
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
                        if group.day == days.first?.day {
                            hint
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
                    // One tap and no sheet for a `lastTime` tracker, the same
                    // as its card's + — the two are the same action and must
                    // not be two different amounts of work.
                    if tracker.kind == .lastTime {
                        store.logNow(tracker)
                    } else {
                        LogSheet.present(
                            .init(group: LogGroup(of: tracker), tracker: trackerID),
                            using: $logging
                        )
                    }
                }
                .navBarAccent()
            }
        }
        // At the bottom, where the swipe that needs undoing happened. A `Section`
        // above the first row is an undo you can only see while already looking
        // at the top of a list you have just scrolled down.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if offersUndo {
                UndoBar()
            }
        }
    }

    /// Gated, for the reason `HomeView.offersUndo` is: the store keeps one
    /// *global* undo slot, so a screen drawing `UndoBar` unguarded offers to take
    /// back a write made somewhere else. `lastDeletion(for:)` and not
    /// `lastDeletion`, so a batch that took an entry from two trackers offers the
    /// undo on both of their screens and on nobody else's.
    private var offersUndo: Bool {
        store.lastDeletion(for: trackerID) != nil
    }

    private func row(_ tracker: Tracker, entry: Entry) -> some View {
        Button {
            editing = entry
        } label: {
            // Side by side while it fits, stacked once it does not. Without it
            // this screen split the timestamp mid-token at AX5 — `12:04 A` on one
            // line and `M` on the next.
            StackingRow {
                // `entry.name` and no fallback, where History falls back to the
                // tracker or the group: that fallback exists because History
                // mixes trackers and a row has to say which one it is. Here the
                // navigation title has said it already.
                LogRowLabel(
                    identity: entry.name,
                    values: tracker.entryText(entry.value)
                )
            } trailing: {
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    // A time that breaks after the `A` has stopped being a time,
                    // and the value beside it wraps perfectly well.
                    .layoutPriority(1)
            }
            // A `Button` hit-tests its label's drawn content unless given a
            // shape, so without this the gap between the value and the time —
            // most of the row's width — is dead.
            .contentShape(.rect)
        }
        .buttonStyle(.row)
        .rowPress()
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                store.delete(entry)
            }
            // The root `.tint(.primary)` reaches a swipe action and
            // `role: .destructive` loses to it, so without this the button drew
            // as a white capsule with an invisible glyph. A swipe action states
            // its own colour.
            .tint(.red)
        }
    }

    /// The same sentence `HistoryView` carries, deliberately word for word:
    /// these rows have exactly the same two invisible gestures, and two screens
    /// teaching one pair differently is its own kind of drift. Wants changing in
    /// both.
    private var hint: some View {
        Text("Tap a row to edit it, or swipe to delete.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    /// A row rather than a section header — see `HistoryView.dayHeading`, which
    /// is the other drawing of this one thing. The two have already come apart
    /// once, over where the header trait went, so anything changed in one wants
    /// looking at in the other.
    private func dayHeading(_ tracker: Tracker, group: DayGroup) -> some View {
        HStack {
            Text(title(for: group.day))
                // On the day's label alone, never on the `HStack`. A trait set on
                // a container reaches every child, so up there it made the day's
                // *total* a heading too and the VoiceOver headings rotor came out
                // twice as long with every other stop a bare number — 3,466 stops
                // for 1,733 days, read off the live accessibility tree.
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if tracker.kind == .dailyTotal {
                Text(tracker.format(store.total(for: trackerID, on: group.day)))
                    .monospacedDigit()
            }
        }
        .font(.headline)
        .foregroundStyle(.secondary)
        // And deliberately no `.accessibilityElement(children: .combine)`, though
        // a heading reading as one phrase would be nicer than two: it costs 180ms
        // of the 400 this screen takes to open, because combining children is not
        // lazy the way a row's body is — every one of 1,733 headings resolves its
        // children whether or not it is on screen.
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 6, trailing: 16))
    }

    struct DayGroup {
        var day: DayKey
        var entries: [Entry]
    }

    /// Newest day first, and newest entry first within each day. Cheap enough to
    /// do on demand: it walks one tracker's entries, which are already sorted.
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
