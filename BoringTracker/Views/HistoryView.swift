import SwiftUI

/// Everything logged, newest first. Today is one day section like every other;
/// it merely happens to sort to the top.
struct HistoryView: View {
    @Environment(Store.self) private var store
    @State private var editing: HistoryItem?

    var body: some View {
        let days = days
        Group {
            if days.isEmpty {
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
                                HistoryRow(item: item) { editing = item }
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
        .safeAreaInset(edge: .bottom, spacing: 0) { undoBar }
        .sheet(item: $editing) { item in
            BatchEditor(item: item)
        }
    }

    /// The one undo on this screen, at the bottom rather than at the top of the
    /// list.
    ///
    /// It used to be a section above the first day, which works only while you
    /// are already looking at the top — and neither thing it undoes happens
    /// there. Repeating is a button on a row you scrolled to find, three days
    /// back or three months; deleting is a swipe on that same row. In both cases
    /// the top of the list is off screen, so the undo appeared where the user
    /// was not, and the tap itself had no visible result at all. An undo you
    /// cannot see is not an undo, and this is the bar idiom home's Log already
    /// uses (docs/PHILOSOPHY.md, "frequent actions live low").
    ///
    /// One bar for both, because the store keeps one undo slot: two undo
    /// affordances in two places on one screen is a screen saying the same thing
    /// twice, which is the complaint docs/TODO.md item 13 is named after.
    @ViewBuilder
    private var undoBar: some View {
        if let message = undoMessage {
            HStack {
                Text(message)
                    .foregroundStyle(.secondary)
                    // On the message rather than on the bar. At default sizes
                    // the button's 44pt sets the height and this is slack
                    // inside it; above the accessibility sizes the message is
                    // the taller of the two and sets the height itself, and
                    // without this its wrapped lines render flush against both
                    // edges of the material. Padding the bar instead would buy
                    // the same margin by making it 12pt taller at every size,
                    // for a case that only happens at the top of the range.
                    .padding(.vertical, 6)
                Spacer()
                Button(action: undo) {
                    // 44pt, the same rule the repeat disc below follows and for
                    // a better reason: this is the recovery for a control that
                    // writes data on one tap. A bare `Button("Undo")` is hit
                    // only where the word is drawn — measured at roughly 20pt
                    // tall inside a 40pt bar — so the target was half the size
                    // of the mistake it exists to fix.
                    Text("Undo")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    /// What the pending undo would take back. A repeat wins when both could be
    /// set, which cannot happen — the store's slot holds one — so this is the
    /// order the two are read in, not a priority between them.
    private var undoMessage: String? {
        if let logged = store.lastLoggedAgain {
            // Named honestly when the row was only partly repeatable: the tap
            // promised the row and wrote less than the row, and the alternative
            // is a button that quietly does something other than what it says.
            return logged.skipped == 0
                ? "Logged again"
                : "Logged \(logged.count) of \(logged.count + logged.skipped) again"
        }
        if store.lastDeletion != nil {
            return store.lastDeletionCount == 1 ? "Deleted entry" : "Deleted batch"
        }
        return nil
    }

    private func undo() {
        if store.lastLoggedAgain != nil {
            store.undoLastLog()
        } else {
            store.undoLastDeletion()
        }
    }

    private struct DayGroup {
        var day: DayKey
        var items: [HistoryItem]
    }

    private var days: [DayGroup] {
        var groups: [DayKey: [HistoryItem]] = [:]
        for item in store.historyItems {
            groups[DayKey(item.date, calendar: store.calendar), default: []].append(item)
        }
        return groups.sorted { $0.key > $1.key }.map { DayGroup(day: $0.key, items: $0.value) }
    }

    private func title(for day: DayKey) -> String {
        if day == store.today { return "Today" }
        if day == store.today.adding(days: -1, calendar: store.calendar) { return "Yesterday" }
        let start = day.startOfDay(calendar: store.calendar)
        return if day.year == store.today.year {
            start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        } else {
            start.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }
}

private struct HistoryRow: View {
    @Environment(Store.self) private var store
    let item: HistoryItem
    let edit: () -> Void

    /// One shape for every row: the numbers on the first line, the name under
    /// them if there is one.
    ///
    /// It used to be two shapes. A named batch put the name first and dropped
    /// the values to a grey footnote beneath it, an unnamed one printed the
    /// values full size on the first line — so "100 kcal, 10 g" changed size,
    /// weight, colour and position depending on whether a name had been typed,
    /// and a day's scroll was two interleaved layouts. The numbers are what
    /// every row has, so they are what every row shows the same way; the name
    /// is what only some rows have, so it is the part that may be missing, and
    /// grey where it isn't.
    var body: some View {
        // Two plain buttons with disjoint frames, the same shape a home card
        // uses: tapping the row edits it, tapping the disc logs it again.
        HStack(spacing: 8) {
            Button(action: edit) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(values)
                        if let name = item.displayName {
                            Text(name)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
    /// `values` prints "Deleted tracker" where the record is gone, so that row
    /// says why the disc is off; an archived tracker is still a record, so its
    /// row reads like any other and the disc is simply absent-looking beside it
    /// (measured at 1.25:1 against the row in light mode — it reads as no button
    /// rather than a dead one). Left that way deliberately, and corrected in
    /// docs/TODO.md item 14 rather than fixed here: saying "Archived" on the row
    /// is a change to what a row shows, and what a row shows is item 14b's
    /// question.
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
                .background(canRepeat ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!canRepeat)
        .accessibilityLabel("Log again")
    }

    private var values: String {
        let trackers = Dictionary(store.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let units = item.entries.compactMap { trackers[$0.trackerID]?.unit }
        return item.entries
            .sorted { lhs, rhs in
                let left = trackers[lhs.trackerID]?.sortIndex ?? .max
                let right = trackers[rhs.trackerID]?.sortIndex ?? .max
                return (left, lhs.trackerID, lhs.id) < (right, rhs.trackerID, rhs.id)
            }
            .map { entry in
                guard let tracker = trackers[entry.trackerID] else {
                    return "Deleted tracker: \(entry.value.formatted())"
                }
                let needsName = tracker.unit.isEmpty || units.count(where: { $0 == tracker.unit }) > 1
                return needsName
                    ? "\(tracker.name): \(tracker.format(entry.value))"
                    : tracker.format(entry.value)
            }
            .joined(separator: ", ")
    }
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
