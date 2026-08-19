import SwiftUI

/// The things you have logged to a daily total, most recently logged first,
/// one tap each to log again.
///
/// A second door on home for a different job. The Log button opens an empty
/// sheet with the keypad up, which is right when the number is new; this is for
/// the far commoner case where you are eating the same thing again, and it
/// never raises a keypad at all (docs/TODO.md item 16).
///
/// It is History filtered to the rows a repeat makes sense of and collapsed to
/// one row per distinct thing you ate, with the day sections flattened away and
/// a search field over the top. Not a new list built from the entries: the
/// grouping of a batch into one row and the ordering are the same question both
/// screens ask, and answering it twice is how they come to disagree. Since item
/// 29 the two are in the same order as well — a collapsed row is dated by the
/// last time you logged it, and that is what sorts the list.
///
/// **The tracker's kind decides what is here, not the name** — see
/// `Store.repeatItems` (docs/TODO.md item 21). So an unnamed row is here,
/// identified by its values the way History identifies it, and a weight is not.
/// A search only matches names, so any query empties the unnamed rows out of
/// the list; the field says "Search names" and that is the whole of it.
///
/// **A row here is what a tap writes, not what the batch holds.** Every row is
/// projected onto its writable members before it is collapsed
/// (`HistoryItem.keeping`), so a weigh-in is listed as its calories, its value
/// line shows only those, and every morning's weigh-in of the same breakfast is
/// one row rather than one per reading.
///
/// **A sheet, not a pushed screen, and a tap on a row closes it** (docs/TODO.md
/// item 20). Pushed, it was a titled screen with a list and a search field —
/// which is precisely what History is, so it read as a second History rather
/// than as a fast way to log, and it was reached and left the way you reach and
/// leave a place. Half height over the screen you were on says the opposite: it
/// is a thing that comes up, takes one tap, and goes. What it costs is that
/// nothing here can be a *destination* — no editing a row, no deleting one, no
/// second tap — and that is the point rather than the price. History is still
/// there for all of it.
struct RepeatView: View {
    /// Called once a row has actually written something, just before the sheet
    /// goes. It is how home knows the pending undo is its own — see
    /// `HomeView.wroteRow`.
    var logged: () -> Void = {}

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Built once, when the sheet opens, and deliberately not rebuilt while it
    /// is up.
    ///
    /// **Because it is the expensive part.** `repeatItems` walks and sorts every
    /// entry ever logged; a computed property read from `body` would pay that
    /// again on every keystroke in the search field. Filtering a snapshot is a
    /// string comparison per row. Measured again after the move to a sheet,
    /// unchanged — the numbers are in `Store.repeatItems` and in the commit.
    ///
    /// It also used to be what stopped the list reshuffling under your thumb
    /// between two taps, which no longer arises: one tap logs and the sheet
    /// leaves, so there is no second tap to aim. Kept for the cost, which is the
    /// half that was always load-bearing.
    ///
    /// `nil` rather than `[]` until it is built, so the empty state cannot flash
    /// on screen for the frame before the first pass.
    @State private var items: [HistoryItem]?
    @State private var query = ""
    /// Whether this presentation has already written something — see `log(_:)`.
    @State private var wrote = false

    var body: some View {
        NavigationStack { content }
            // Half the screen, draggable to full. A presentation that stops
            // short of the top is the whole difference from the pushed screen:
            // home stays visible behind it, so this reads as something over
            // what you were doing rather than somewhere you went. `.large` is
            // there because the list is as long as your history and the
            // keyboard needs the room when you search.
            //
            // **Past `.xxxLarge` it opens at full height instead**, at the same
            // threshold and for the same reason the home card stops fitting on
            // one line: half a screen holds one and a half rows at AX5 —
            // checked on an iPhone 17 — and a list you cannot see two of is not
            // a list you can pick from. Somebody reading at AX5 is not the
            // person the half-height presentation was buying anything for.
            .presentationDetents(typeSize >= .xxxLarge ? [.large] : [.medium, .large])
            // The system's own "this pulls down", as on the log sheet. It is
            // the only thing that advertises the exit: there is no Cancel and
            // no Done, because tapping a row is the one thing this sheet does
            // and leaving without logging is the rare case — the same trade
            // item 5 made when it took Cancel off the log sheet.
            .presentationDragIndicator(.visible)
    }

    private var content: some View {
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
        return Group {
            if let items {
                let shown = items.filter { $0.matches(query) }
                if items.isEmpty {
                    // Not "nothing named yet" any more, which was true of the
                    // old filter and would now be a lie: a name has nothing to
                    // do with what turns up here (docs/TODO.md item 21). The
                    // one thing this state has to say is which kind of tracker
                    // fills the list, because the other kind never will.
                    ContentUnavailableView(
                        "Nothing to log again yet",
                        // The same glyph the rows and home's bar draw, so the
                        // screen with nothing on it still says what it is for.
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
        // "Log again", not "Repeat". It says what the tap does instead of naming
        // a concept, and it is the app's own verb — the button beside the door
        // to this screen says Log, and History's disc has been labelled "Log
        // again" since item 14. Nobody has to interpret it (docs/TODO.md item
        // 20). The type keeps its name: `RepeatView`, `repeatItems` and
        // `repeatKey` are about the *rule* for collapsing rows, and renaming
        // them would rename the model after a screen's title.
        .navigationTitle("Log again")
        .navigationBarTitleDisplayMode(.inline)
        // The one thing History's list does not have, and the reason this is a
        // list at all rather than a row of chips: with a year of food behind
        // you the thing you want is four letters away.
        //
        // Not while the list is empty: a field over "Nothing to log again yet"
        // matches nothing by construction (docs/TODO.md item 25b,
        // `searchableNames(_:when:)`). The snapshot is exactly the right thing
        // to ask — it is what this screen is about, it is already built, and a
        // query merely matching nothing leaves it non-empty, which is the case
        // the field must survive.
        //
        // **`!= true`, so the unbuilt snapshot counts as "something to
        // search".** Written the other way first — `!(items?.isEmpty ?? true)`,
        // no field until the snapshot arrives — and it took the whole sheet
        // with it: `onAppear` fills `items` one pass after the first, the
        // field's branch flipped from absent to present underneath a
        // presentation that was already up, and the sheet came back **blank**,
        // no title and no list, on every fixture and every text size.
        // Photographed before and after. The empty direction is fine — the
        // `empty` fixture draws its empty state with no field — so this asks
        // the question in the direction that never has to appear.
        .searchableNames($query, when: items?.isEmpty != true)
        // No `UndoBar` here any more. The bar is on home, where this sheet
        // leaves you — an undo drawn on a presentation that dismisses itself
        // would be a button you cannot reach.
        .onAppear { if items == nil { items = store.repeatItems } }
    }

    /// Write the row, tell home, and go.
    ///
    /// **Once per presentation.** `dismiss()` starts an *animated* dismissal and
    /// the list stays laid out and hit-testable while the sheet slides away, so
    /// a second tap in that window would write a second copy — and only the
    /// second would be undoable, since the store keeps one slot (item 14). The
    /// flag is what actually closes the double tap the pushed screen carried;
    /// the sheet leaving narrows the window, it does not shut it.
    ///
    /// Here rather than in the row, because it is the *sheet* that is leaving:
    /// a guard per row would still let a tap on a different row through.
    private func log(_ item: HistoryItem) {
        guard !wrote, store.logAgain(item) else { return }
        wrote = true
        logged()
        dismiss()
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
/// **A row nobody named leads with its tracker, or with the group the batch was
/// logged as** — `HistoryItem.line` already answers that for History, and since
/// item 21 those rows are here too. So the list reads "Food / 450 kcal, 30 g"
/// and "Calories / 90 kcal" rather than a column of bare numbers, and the name a
/// row does have still leads it where there is one.
///
/// Off when the row has nothing left to write — every tracker it named has been
/// archived. Kept in the list rather than hidden: the row is still a true
/// statement about what you ate, and a food that vanishes from the list when you
/// archive a tracker would be a screen quietly editing your history. (A row
/// whose trackers were *deleted* no longer reaches this screen at all — the
/// projection leaves nothing of it, see `Store.repeatItems` — so in practice
/// this state is the archived one.)
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
/// **A tap logs and the sheet goes**, and the writing itself belongs to
/// `RepeatView.log(_:)` rather than to the row: a row that has been tapped is
/// still on screen and still hit-testable for the length of the dismissal, so
/// the refusal of a second write has to be one flag for the sheet rather than
/// one per row (docs/TODO.md item 20). That closes the double tap this list
/// carried when it was a screen, where the list sat still under your thumb and
/// would take a second copy that made the first unrecoverable.
///
/// A row that can write nothing is disabled and nothing happens, so a tap on it
/// is not silently read as "done".
///
/// The undo for a mistap is on home, which is where this leaves you.
private struct RepeatRow: View {
    @Environment(Store.self) private var store
    let item: HistoryItem
    /// Built once for the screen by `RepeatView`, not per row.
    let trackers: [UUID: Tracker]
    /// Log this row again. Owned by `RepeatView`, which decides whether this
    /// presentation has already written something.
    let log: () -> Void

    var body: some View {
        let line = item.line(trackers: trackers)
        let canRepeat = !store.repeatableEntries(of: item).isEmpty
        return Button(action: log) {
            // The same two lines History draws, in the same order and the same
            // weights: the name leads and stays quiet, the values follow
            // (docs/TODO.md item 14b). A louder name was tempting here, where
            // the name is what you came for — but the two screens list the same
            // rows, and one of them shouting is how an app grows a second
            // design language.
            HStack(spacing: 8) {
                // The row's two halves, stacking past `.xxxLarge` the way
                // home's card and both other lists do: at AX5 this read `640` /
                // `kcal, 31` / `g` beside `Tue,` / `Aug 4`, two columns of
                // fragments where the row has one sentence to say.
                StackingRow {
                    VStack(alignment: .leading, spacing: 2) {
                        // The same word History puts here, from the same
                        // call, for the same reason: a dimmed row says
                        // "unavailable" and does not say why. On this screen
                        // the answer is always "Archived" — a deleted
                        // tracker's row is not listed at all and a measurement
                        // member is projected away before the row is built —
                        // but the sentence is not written twice to prove it.
                        Text(identityLine(line, canRepeat: canRepeat))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(line.values)
                    }
                } trailing: {
                    // The day, where History's row shows the time. History has
                    // already said which day in its section heading and this
                    // list has no sections, so the two show the half the other
                    // one is missing.
                    Text(day.label(today: store.today, calendar: store.calendar))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        // As on History, and for the same reason: `Tue, Aug 4`
                        // broken across two lines is a date you have to
                        // reassemble.
                        .layoutPriority(1)
                }
                // **Dimmed while the row is off**, which is what `.plain` used
                // to do for free and a custom `ButtonStyle` does not. A
                // disabled row here greys its whole self where History greys
                // only its disc, because here the whole row *is* the button —
                // this type's doc argues that at length and it is still the
                // rule. Item 26 replaced `.plain` to carry the pressed colour
                // into the disc and took this with it unnoticed: measured on
                // the Log again sheet's archived rows, the value line came back
                // as the `#000000` a live row draws, so a row that cannot be
                // tapped read exactly like one that can.
                //
                // **0.5, because that is the opacity `.plain` composited at.**
                // Not computed — built both ways and photographed: on the Log
                // again sheet's archived rows this draws `#6D6D6E` where the
                // build before item 26 drew `#6D6D6E`, and the `.secondary`
                // identity line above it `#A4A4A5` against `#A4A4A5`, to the
                // byte in light; `#969696` and `#616161` on the dark `#2C2C2C`
                // row, where a live row is `#FFFFFF`. (The arithmetic alone
                // says `#6E6E6E` — SwiftUI's disabled opacity solves to about
                // 0.502 rather than a round half, which is one more reason to
                // read the pixels than to trust the sum.) A shape style was the
                // tempting alternative and would flatten the two lines into one
                // weight.
                //
                // The disc is deliberately *outside* this: its off state is a
                // named fill with a legible glyph now, and dimming that a
                // second time is the invisible control item 26 was reported
                // for (`Color.accentFillDisabled`).
                .opacity(canRepeat ? 1 : 0.5)
                // Not a `Button`. The row already is one, and a control inside
                // a control is two tap targets where the screen means one — so
                // the disc reads `\.isEnabled` from the `.disabled(!canRepeat)`
                // on the row below it.
                RepeatDisc()
            }
            .contentShape(.rect)
        }
        // `.accentFill`, so the disc inside recedes with the press like the
        // other two (docs/TODO.md item 26). It costs the row's text the dimming
        // `.plain` gave it *while pressed* — see `AccentFillButtonStyle`. The
        // *disabled* half of that dimming is restored above, deliberately: it
        // was load-bearing and its loss was not noticed.
        .buttonStyle(.accentFill)
        .disabled(!canRepeat)
        .accessibilityHint("Logs this again")
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
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
    // Presented the way the app presents it, over something, rather than as a
    // screen of its own: the detents are half of what this view is.
    return Color(.systemBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) { RepeatView().environment(store) }
}
