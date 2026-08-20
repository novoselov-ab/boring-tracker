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
            // The chart stays a section of its own: there is one of it at
            // most, and it is genuinely a separate thing.
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
                    LogSheet.present(
                        .init(group: LogGroup(of: tracker), tracker: trackerID),
                        using: $logging
                    )
                }
                .navBarAccent()
            }
        }
        // The bar, at the bottom, where the swipe that needs undoing happened —
        // `UndoBar` carries the argument and it was written about this shape.
        // This screen kept a `Section` above the first row until now, which is
        // an undo you can only see while already looking at the top of a list
        // you have just scrolled down (docs/TODO.md items 20, 20b, 22 each
        // fixed History and left this screen a tap away untouched).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if offersUndo {
                UndoBar()
            }
        }
    }

    /// Whether the bar is drawn: the pending deletion took something from *this*
    /// tracker.
    ///
    /// Undo is offered at all — rather than a confirmation on the swipe —
    /// because a swipe you meant should be instant and a swipe you didn't should
    /// be cheap to fix.
    ///
    /// It is a gate for the reason home has one (`HomeView.offersUndo`): the
    /// store keeps one *global* slot, so a screen drawing `UndoBar` unguarded
    /// offers to take back a write made somewhere else. Home asks whose write it
    /// is; this asks whose tracker it is, which is the scoping the undo row it
    /// replaces already had — swipe a row away on History and this screen stays
    /// quiet unless that row was one of these. `lastDeletion(for:)` and not
    /// `lastDeletion`, so a batch that took an entry from two trackers offers
    /// the undo on both of their screens and on nobody else's.
    ///
    /// The bar's repeat half never fires here and needs no flag to stop it:
    /// nothing on this screen repeats — the Log button writes an ordinary entry
    /// — and a repeat made elsewhere leaves this `nil` anyway, because one slot
    /// holding a repeat is a slot holding no deletion.
    private var offersUndo: Bool {
        store.lastDeletion(for: trackerID) != nil
    }

    private func row(_ tracker: Tracker, entry: Entry) -> some View {
        Button {
            editing = entry
        } label: {
            // The same row shape home's card and History draw, and the same
            // fallback: side by side while it fits, stacked once it does not.
            // Without it this screen split the timestamp mid-token at AX5 —
            // `12:04 A` on one line and `M` on the next.
            StackingRow {
                // **The name leads, and this screen used to be the exception**
                // — `520 kcal` in body text over `chicken salad` in grey, the
                // reverse of the row History draws one tap away (docs/TODO.md
                // item 35). The argument for the old order was real: the
                // tracker is fixed here, so the number is what tells two rows
                // apart, and leading with the name gives weight to the least
                // distinguishing part of the row. It lost to consistency —
                // two screens showing the same two facts in opposite orders
                // read as an app that has not decided, and moving between them
                // meant re-learning where to look. `LogRowLabel` is that row,
                // shared, so the next change lands on both.
                //
                // `entry.name` and no fallback, where History falls back to the
                // tracker or the group: that fallback exists because History
                // mixes trackers and a row has to say which one it is. Here the
                // navigation title has said it already, so an unnamed entry
                // draws its value alone rather than repeating the title down
                // the screen. Handed over as it is, blank and all — what counts
                // as no name is `LogRowLabel`'s to decide, for all three
                // screens.
                //
                // The value line loses `.monospacedDigit()` with the flip,
                // which is History's treatment and costs nothing: these lines
                // are leading-aligned and of different lengths, so tabular
                // figures were never lining a column up. **The day heading
                // above them keeps its own**, and that is the pairing rather
                // than an oversight: the day totals are right-aligned at the
                // same edge down the whole list, which is a column, and it is
                // the one place on this screen where digits of different widths
                // would visibly fail to line up.
                LogRowLabel(
                    identity: entry.name,
                    values: tracker.format(entry.value)
                )
            } trailing: {
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    // As on History: a time that breaks after the `A` has
                    // stopped being a time, and the value beside it wraps
                    // perfectly well.
                    .layoutPriority(1)
            }
            // The whole row, not the two pieces of text in it (docs/TODO.md
            // item 28). A `Button` hit-tests its label's drawn content unless
            // it is given a shape, so the gap between the value and the time —
            // most of the row's width — was dead here exactly as it was on
            // settings.
            .contentShape(.rect)
        }
        // `.row`: this screen's rows edit an entry, and until item 28 their
        // whole press was `.plain` dimming the text 25% (`RowButtonStyle`).
        .buttonStyle(.row)
        .rowPress()
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

    /// The two gestures on a row, said once, because neither is visible.
    ///
    /// The same sentence History carries and deliberately the same words:
    /// item 22 wrote it for rows that edit on a tap and delete on a swipe, and
    /// checked the Log again sheet as the other candidate — but not this screen,
    /// whose rows have exactly the same two. Two screens teaching one pair of
    /// gestures differently is the drift docs/TODO.md item 13 is named after, so
    /// this is a copy of the wording on purpose and wants changing in both.
    ///
    /// **Under the first day only**, in the plain footer idiom, no icon and no
    /// colour — `HistoryView` carries the argument for all three.
    private var hint: some View {
        Text("Tap a row to edit it, or swipe to delete.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
