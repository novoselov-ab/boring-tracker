import SwiftUI

/// Everything logged, newest first. Today is one day section like every other;
/// it merely happens to sort to the top.
struct HistoryView: View {
    @Environment(Store.self) private var store
    @State private var editing: HistoryItem?
    /// Filters the same field, through the same `HistoryItem.matches`, as the
    /// Repeat screen. Two implementations of one search would drift, and the
    /// second one would be the one nobody tests (docs/TODO.md item 16b).
    ///
    /// Not snapshotted the way Repeat's list is: this screen has to stay live,
    /// because deleting a row and repeating one both have to be visible here
    /// straight away. So a keystroke rebuilds `historyItems` — which every
    /// redraw of this screen already did — and filters it.
    @State private var query = ""

    var body: some View {
        let days = days
        // One dictionary for the whole screen. `HistoryItem.line` takes it as a
        // parameter precisely so a screenful of rows does not each rebuild it,
        // and the rows were rebuilding one each anyway.
        //
        // `uniquingKeysWith`, not `uniqueKeysWithValues`, which traps: a store
        // file holding two trackers with the same id is a shape nothing on the
        // load path rejects, and the rest of the store layer already survives
        // it.
        let trackers = Dictionary(
            store.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        Group {
            if days.isEmpty, !query.isEmpty {
                ContentUnavailableView.search(text: query)
            } else if days.isEmpty {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "clock",
                    description: Text("Your entries will appear here after you log them.")
                )
            } else {
                List {
                    ForEach(days, id: \.day) { group in
                        Section(title(for: group.day)) {
                            ForEach(group.items) { item in
                                HistoryRow(item: item, trackers: trackers) { editing = item }
                                    .swipeActions(edge: .trailing) {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            if let entry = item.entries.first {
                                                store.deleteBatch(containing: entry)
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        // The same prompt as the Repeat screen, and it is doing work: it says
        // what the field looks at, which is the one thing a searcher has to
        // know here. See `days` for what that costs an unnamed row.
        .searchable(text: $query, prompt: "Search names")
        // `UndoBar`, not a copy of it: the Repeat screen writes through the same
        // `logAgain` and takes it back through the same one slot, and two copies
        // of this is two chances to word one undo differently.
        .safeAreaInset(edge: .bottom, spacing: 0) { UndoBar() }
        .sheet(item: $editing) { item in
            BatchEditor(item: item)
        }
    }

    private struct DayGroup {
        var day: DayKey
        var items: [HistoryItem]
    }

    /// The rows the query keeps, grouped by day. A day with nothing left in it
    /// is not drawn, so a search does not leave empty headings behind.
    ///
    /// **An unnamed entry disappears under a non-empty query, and stays under
    /// an empty one.** It has no name, and this searches names — the same rule
    /// the Repeat screen runs, through the same `HistoryItem.matches`, because
    /// two screens filtering the same field of the same records must not
    /// disagree about what a query means (docs/TODO.md item 16b).
    ///
    /// The alternative was to match the identity line as well, so that
    /// "weight" found this morning's weight reading. Refused: that line falls
    /// back to a tracker or a group for rows nobody named, so a search for
    /// "food" would return every meal ever logged under that group — a query
    /// nobody typed a name for, answered with hundreds of rows. What makes the
    /// omission safe rather than surprising is that half a log does not vanish
    /// silently: the field says "Search names", the day headings for filtered
    /// days go with their rows, and an unmatched query gets the search empty
    /// state rather than a blank list.
    private var days: [DayGroup] {
        var groups: [DayKey: [HistoryItem]] = [:]
        for item in store.historyItems where item.matches(query) {
            groups[DayKey(item.date, calendar: store.calendar), default: []].append(item)
        }
        return groups.sorted { $0.key > $1.key }.map { DayGroup(day: $0.key, items: $0.value) }
    }

    private func title(for day: DayKey) -> String {
        day.label(today: store.today, calendar: store.calendar)
    }
}

private struct HistoryRow: View {
    @Environment(Store.self) private var store
    let item: HistoryItem
    /// Built once for the screen by `HistoryView`, not per row.
    let trackers: [UUID: Tracker]
    let edit: () -> Void

    /// One shape for every row: what it is called on the first line, what it
    /// was on the second.
    ///
    /// **The name leads and stays quiet.** Item 13 put the numbers first on the
    /// grounds that the numbers are what every row has, which was right about
    /// uniformity and wrong about scanning: item 14 made History the place you
    /// come to *find a food by name* and repeat it, and finding one meant
    /// reading twelve small grey second lines while twelve large white numbers,
    /// which identify nothing, took the eye first (docs/TODO.md item 14b).
    ///
    /// So the fix is position, not weight. The name is still a grey footnote —
    /// quiet was asked for deliberately, and re-loudening it would undo item 13
    /// rather than finish it — and reading order does the work instead. Every
    /// row still has the same structure, which is what item 13's uniformity was
    /// actually about; a row nobody named leads with its group or its tracker,
    /// so the first line is an identity line on every row rather than on some
    /// of them.
    var body: some View {
        let line = line
        // Two plain buttons with disjoint frames, the same shape a home card
        // uses: tapping the row edits it, tapping the disc logs it again.
        return HStack(spacing: 8) {
            Button(action: edit) {
                // The time is on the identity line rather than beside the
                // numbers: it is the same footnote grey, and the two quiet
                // things belong together above the one loud one.
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.identity)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(line.values)
                    }
                    Spacer(minLength: 8)
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(item.entries.count == 1 ? "Edits this entry" : "Edits this batch")
            repeatButton
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
    }

    /// Log this row again, now. One tap: no sheet, no confirmation, and no
    /// picker in front of it — the same rule the home screen's + follows, for
    /// the same reason.
    ///
    /// Drawn as a home card's + is drawn, because it is the same action reached
    /// from the other screen, and a second design language for "write a log"
    /// is the complaint docs/TODO.md item 13 is named after. A different glyph,
    /// because this one repeats something that already happened rather than
    /// opening an empty sheet.
    ///
    /// Off when the row has nothing left to write: every tracker it named has
    /// been deleted or archived. A control that looks live and does nothing is
    /// worse than one that plainly cannot be used.
    ///
    /// **A deleted tracker's row explains itself and an archived one does not.**
    /// The row prints "Deleted tracker" where the record is gone — on the
    /// identity line for a lone entry, beside the number inside a batch — so
    /// that row says why the disc is off; an archived tracker is still a
    /// record, so its row reads like any other and the disc is simply
    /// absent-looking beside it (measured at 1.25:1 against the row in light
    /// mode — it reads as no button rather than a dead one). Still deliberate
    /// after item 14b: an archived tracker's row now leads with that tracker's
    /// name, which is more than it used to say, and "Archived" on the row is a
    /// label about the tracker rather than about the thing that was logged.
    private var repeatButton: some View {
        let canRepeat = !store.repeatableEntries(of: item).isEmpty
        return Button { store.logAgain(item) } label: {
            Image(systemName: "arrow.clockwise")
                // Fixed rather than a text style, for the reason home's + is:
                // the disc and the 44pt target do not scale, so a glyph that
                // does outgrows its own circle at the accessibility sizes.
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(canRepeat ? AnyShapeStyle(Color.onAccent) : AnyShapeStyle(.tertiary))
                .frame(width: 30, height: 30)
                // `Color.accentFill`, not `.tint`: the environment tint is the
                // ordinary label colour now, and the accent is only ever a fill
                // (docs/TODO.md item 13c).
                .background(
                    canRepeat ? AnyShapeStyle(Color.accentFill) : AnyShapeStyle(.quaternary),
                    in: .circle
                )
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!canRepeat)
        .accessibilityLabel("Log again")
    }

    private var line: HistoryItem.Line { item.line(trackers: trackers) }
}

#Preview {
    let trackers = Tracker.starterSet
    let batch = UUID()
    let store = Store(
        document: StoreDocument(
            trackers: trackers,
            entries: [
                Entry(trackerID: trackers[0].id, value: 100, name: "chicken rice", batchID: batch),
                Entry(trackerID: trackers[1].id, value: 10, name: "chicken rice", batchID: batch),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-history"))
    )
    return NavigationStack { HistoryView().environment(store) }
}
