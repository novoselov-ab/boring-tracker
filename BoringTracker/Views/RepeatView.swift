import SwiftUI

/// The things you have logged to a daily total, most recently logged first,
/// one tap each to log again.
///
/// The rows are `Store.repeatItems`, which is also what History groups and
/// orders by: two screens listing the same records must not disagree about
/// what one row is. This list differs only in putting every row a tap cannot
/// write below every row it can.
///
/// A sheet rather than a pushed screen (docs/TODO.md item 20). Pushed, it was a
/// titled list with a search field over it — which is what History already is,
/// so it read as a second History rather than as a fast way to log.
struct RepeatView: View {
    /// Told to home so it knows the pending undo is its own — see
    /// `HomeView.wroteRow`.
    var logged: () -> Void = {}

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    /// A snapshot, not a computed property: `repeatItems` walks and sorts every
    /// entry ever logged, so reading it from `body` would repay that on every
    /// keystroke in the search field. `nil` rather than `[]` until it is built,
    /// so the empty state cannot flash for the frame before the first pass.
    @State private var items: [HistoryItem]?
    @State private var query = ""
    @State private var wrote = false

    var body: some View {
        NavigationStack { content }
            // Full height at AX5 and up: half a screen holds one and a half
            // rows there — checked on an iPhone 17 — and a list you cannot see
            // two of is not a list you can pick from. Same threshold as the
            // home card's, for the same reason.
            .presentationDetents(typeSize >= .xxxLarge ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
    }

    private var content: some View {
        // One dictionary for the whole screen. `HistoryItem.line` takes it as a
        // parameter precisely so a screenful of rows does not each rebuild it.
        // `uniquingKeysWith`, because a document holding two trackers with the
        // same id is a shape the load path accepts and would trap
        // `uniqueKeysWithValues`.
        let trackers = Dictionary(
            store.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        return Group {
            if let items {
                let shown = items.filter { $0.matches(query) }
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing to log again yet",
                        systemImage: RepeatDisc.symbol,
                        description: Text(
                            "Anything you log to a daily total turns up here, named or not, to "
                                + "log again in one tap. A measurement like weight does not: you "
                                + "would take a new reading rather than repeat the last one."
                        )
                    )
                } else if shown.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(shown) { item in
                        RepeatRow(item: item, trackers: trackers) { log(item) }
                    }
                    .listStyle(.insetGrouped)
                    // Gives back the band an inset-grouped list reserves for a
                    // section heading. This list has no sections, so it was
                    // 26pt of empty space above the first row — measured off
                    // screenshots on an iPhone 17, where the first row moves up
                    // 79px at 3x.
                    .contentMargins(.top, 8, for: .scrollContent)
                }
            }
        }
        .navigationTitle("Log again")
        .navigationBarTitleDisplayMode(.inline)
        // **`!= true`, so the unbuilt snapshot counts as "something to
        // search".** Written as `!(items?.isEmpty ?? true)` first, and it took
        // the whole sheet with it: `onAppear` fills `items` one pass after the
        // first, the field's branch flipped from absent to present underneath a
        // presentation that was already up, and the sheet came back **blank** —
        // no title and no list, on every fixture and every text size. The empty
        // direction is fine, so this asks in the direction that never appears.
        .searchableNames($query, when: items?.isEmpty != true)
        .onAppear { if items == nil { items = store.repeatItems } }
    }

    /// Write the row, tell home, and go.
    ///
    /// **Once per presentation.** `dismiss()` starts an *animated* dismissal and
    /// the list stays laid out and hit-testable while the sheet slides away, so
    /// a second tap in that window writes a second copy — and only the second
    /// would be undoable, since the store keeps one slot. The flag belongs to
    /// the sheet rather than the row: a per-row guard still lets a tap on a
    /// different row through.
    private func log(_ item: HistoryItem) {
        guard !wrote, store.logAgain(item) else { return }
        wrote = true
        logged()
        dismiss()
    }
}

/// One thing you logged: what you called it, what it was, and when.
///
/// **The whole row is the button**, not a disc on the end of it — this screen
/// does exactly one thing to a row. A row with nothing left to write is
/// disabled rather than hidden, so archiving a tracker does not quietly edit
/// what your history says you ate.
private struct RepeatRow: View {
    @Environment(Store.self) private var store
    let item: HistoryItem
    let trackers: [UUID: Tracker]
    let log: () -> Void

    var body: some View {
        let line = item.line(trackers: trackers)
        let canRepeat = !store.repeatableEntries(of: item).isEmpty
        return Button(action: log) {
            HStack(spacing: 8) {
                StackingRow {
                    LogRowLabel(
                        identity: identityLine(line, canRepeat: canRepeat),
                        values: line.values
                    )
                } trailing: {
                    Text(day.label(today: store.today, calendar: store.calendar))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        // `Tue, Aug 4` broken after the comma is not a date
                        // any more; the identity line beside it wraps fine.
                        .layoutPriority(1)
                }
                // **Dimmed while the row is off**, which is what `.plain`
                // used to do for free and neither custom `ButtonStyle` does.
                // Item 26 replaced `.plain` and took this with it unnoticed:
                // on the archived rows of this sheet the value line came back
                // as the `#000000` a live row draws.
                //
                // **0.5 was read off pixels, not computed.** Built both ways
                // and photographed: this draws `#6D6D6E` where the build before
                // item 26 drew `#6D6D6E`, and the `.secondary` line above it
                // `#A4A4A5` against `#A4A4A5`, to the byte in light; `#969696`
                // and `#616161` on the dark `#2C2C2C` row. The arithmetic alone
                // says `#6E6E6E` — SwiftUI's disabled opacity solves to about
                // 0.502 rather than a round half.
                //
                // The disc is deliberately *outside* this: its off state is
                // already a named fill (`Color.accentFillDisabled`), and
                // dimming that a second time is an invisible control.
                .opacity(canRepeat ? 1 : 0.5)
                // Not a `Button`. The row already is one, and a control inside
                // a control is two tap targets where the screen means one — so
                // the disc reads `\.isEnabled` from the `.disabled(!canRepeat)`
                // below.
                RepeatDisc()
            }
            .contentShape(.rect)
        }
        // **`.row`, where the other two repeat discs are `.accentFill`** — here
        // the whole row is the one button, so what presses is the whole row.
        // Handing item 26's `accentFillPressed` down from here as well would
        // scale the disc twice, once with the row and once on its own.
        .buttonStyle(.row)
        .rowPress()
        .disabled(!canRepeat)
        .accessibilityHint("Logs this again")
        .listRowInsets(.listRow)
    }

    private var day: DayKey {
        store.dayKey(item.date)
    }

    private func identityLine(_ line: HistoryItem.Line, canRepeat: Bool) -> String {
        guard !canRepeat, let reason = item.repeatBlockedReason(trackers: trackers) else {
            return line.identity
        }
        return "\(line.identity) · \(reason)"
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
    return Color(.systemBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) { RepeatView().environment(store) }
}
