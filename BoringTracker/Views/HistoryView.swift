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
                    // Filled, dark-labelled, and shaped like the repeat disc
                    // eight lines below it — the same idiom in a capsule
                    // because the word is wider than it is tall. It used to be
                    // teal *text* on the bar, which is the pairing item 13c
                    // removes: 1.89:1 in light mode, on the one control in the
                    // app that exists to be found in a hurry.
                    //
                    // 32pt fill inside a 44pt target, so the bar's height does
                    // not move: this is the recovery for a control that writes
                    // data on one tap, and a bare `Button("Undo")` was hit only
                    // where the word is drawn — roughly 20pt inside a 40pt bar,
                    // half the size of the mistake it exists to fix.
                    Text("Undo")
                        .foregroundStyle(Color.onAccent)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background(Color.accentFill, in: .capsule)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
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
                // ordinary label colour now, and teal is only ever a fill
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

    /// `uniquingKeysWith`, not `uniqueKeysWithValues`, which traps: a store file
    /// holding two trackers with the same id is a shape nothing on the load path
    /// rejects, and the rest of the store layer already survives it.
    private var line: HistoryItem.Line {
        item.line(
            trackers: Dictionary(
                store.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
            )
        )
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
