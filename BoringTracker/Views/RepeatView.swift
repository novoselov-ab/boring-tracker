import SwiftUI

/// The things you have logged and named, newest first, one tap each to log
/// again.
///
/// A second door on home for a different job. The Log button opens an empty
/// sheet with the keypad up, which is right when the number is new; this is for
/// the far commoner case where you are eating the same thing again, and it
/// never raises a keypad at all (docs/TODO.md item 16).
///
/// It is History filtered to the rows that have a name, with the day sections
/// flattened away and a search field over the top. Not a new list built from
/// the entries: the grouping of a batch into one row and the ordering are the
/// same question both screens ask, and answering it twice is how they come to
/// disagree.
struct RepeatView: View {
    @Environment(Store.self) private var store
    /// Built once, when the screen opens, and deliberately not rebuilt while it
    /// is up.
    ///
    /// **Because the list must not move under your thumb.** Repeating writes a
    /// new row dated now, which on a list ordered by recency belongs at the
    /// very top — so a live list would push every row down by one on each tap,
    /// and logging breakfast (coffee, then oats) would mean aiming at a target
    /// that just moved. What says the tap landed is the undo bar, exactly as it
    /// does on History.
    ///
    /// **And because it is the expensive part.** `repeatItems` walks and sorts
    /// every entry ever logged; a computed property read from `body` would pay
    /// that again on every keystroke in the search field. Filtering a snapshot
    /// is a string comparison per row.
    ///
    /// `nil` rather than `[]` until it is built, so the empty state cannot flash
    /// on screen for the frame before the first pass.
    @State private var items: [HistoryItem]?
    @State private var query = ""

    var body: some View {
        // One dictionary for the whole screen. `HistoryItem.line` takes it as a
        // parameter precisely so a screenful of rows does not each rebuild it.
        //
        // `uniquingKeysWith`, not `uniqueKeysWithValues`, which traps: a store
        // file holding two trackers with the same id is a shape nothing on the
        // load path rejects, and the rest of the store layer already survives
        // it.
        let trackers = Dictionary(
            store.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        Group {
            if let items {
                let shown = items.filter { $0.matches(query) }
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing named yet",
                        systemImage: "arrow.clockwise",
                        description: Text(
                            "Give a log a name — \"porridge\", \"flat white\" — and it turns up "
                                + "here to log again in one tap."
                        )
                    )
                } else if shown.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(shown) { item in
                        RepeatRow(item: item, trackers: trackers)
                    }
                    .listStyle(.insetGrouped)
                    // The band an inset-grouped list keeps for a section
                    // heading, given back. History spends it on "Today"; this
                    // list has no sections, so it was empty space between the
                    // title and the first row, at the top of a screen you came
                    // to scan (docs/TODO.md item 11). Worth 26pt, measured off
                    // screenshots on an iPhone 17 — the first row moves up 79px
                    // at 3x — which is half a row on a 52pt pitch.
                    .contentMargins(.top, 8, for: .scrollContent)
                }
            }
        }
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search names")
        // The repeat half only. Nothing is deleted here, and a deletion's undo
        // never expires, so the shared bar would otherwise arrive from History
        // reading "Deleted batch" over a screen that had done nothing.
        .safeAreaInset(edge: .bottom, spacing: 0) { UndoBar(offersDeletion: false) }
        .onAppear { if items == nil { items = store.repeatItems } }
    }
}

/// One thing you logged: what you called it, what it was, and when.
///
/// **The whole row is the button**, not a disc on the end of it. This screen
/// does exactly one thing to a row, so there is nothing else a tap could have
/// meant — and the target is then the full width rather than 44pt of it, which
/// is the difference between aiming and not. The disc stays anyway, drawn as
/// History draws it: it is the same action reached from the other screen, and
/// it is what says the row is a control rather than a record.
///
/// Off when the row has nothing left to write — every tracker it named has been
/// deleted or archived. Kept in the list rather than hidden: the row is still a
/// true statement about what you ate, and a food that vanishes from the list
/// when you archive a tracker would be a screen quietly editing your history.
///
/// **Disabling greys the whole row here, where History greys only its disc**,
/// because here the whole row *is* the button. Raised in review as a
/// contradiction and kept on purpose: a dimmed row reads as "this action is
/// unavailable", which is the platform's own meaning for a disabled control and
/// more than History manages — item 14 recorded that an archived tracker's row
/// says nothing at all about why its disc is off. If it ever reads as damaged
/// data instead, the fix is to say "Archived" on the row, which is a change to
/// what a row shows and belongs with item 14b's question rather than here.
///
/// **A double tap writes twice and only the second is undoable.** True on
/// History as well — the store keeps one undo slot on purpose (item 14) — but
/// the target here is a whole row rather than a 44pt disc, and the list
/// deliberately does not move to confirm the first tap. The alternatives are a
/// second undo slot, which item 14 rejected, and a confirmation, which the
/// philosophy rejects; so this is a known cost of the wider target, not an
/// oversight.
private struct RepeatRow: View {
    @Environment(Store.self) private var store
    let item: HistoryItem
    /// Built once for the screen by `RepeatView`, not per row.
    let trackers: [UUID: Tracker]

    var body: some View {
        let line = item.line(trackers: trackers)
        let canRepeat = !store.repeatableEntries(of: item).isEmpty
        return Button {
            store.logAgain(item)
        } label: {
            // The same two lines History draws, in the same order and the same
            // weights: the name leads and stays quiet, the values follow
            // (docs/TODO.md item 14b). A louder name was tempting here, where
            // the name is what you came for — but the two screens list the same
            // rows, and one of them shouting is how an app grows a second
            // design language.
            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.identity)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(line.values)
                    }
                    Spacer(minLength: 8)
                    // The day, where History's row shows the time. History has
                    // already said which day in its section heading and this
                    // list has no sections, so the two show the half the other
                    // one is missing.
                    Text(day.label(today: store.today, calendar: store.calendar))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                disc(canRepeat)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!canRepeat)
        .accessibilityHint("Logs this again")
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
    }

    private var day: DayKey {
        DayKey(item.date, calendar: store.calendar)
    }

    /// Not a `Button`. The row already is one, and a control inside a control
    /// is two tap targets where the screen means one.
    private func disc(_ canRepeat: Bool) -> some View {
        Image(systemName: "arrow.clockwise")
            // Fixed rather than a text style, for the reason home's + is: the
            // disc does not scale, so a glyph that does outgrows its own circle
            // at the accessibility sizes.
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
                Entry(
                    trackerID: trackers[0].id, value: 420,
                    date: .now.addingTimeInterval(-86_400), name: "porridge"
                ),
                Entry(trackerID: trackers[0].id, value: 90, date: .now.addingTimeInterval(-3_600)),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-repeat"))
    )
    return NavigationStack { RepeatView().environment(store) }
}
