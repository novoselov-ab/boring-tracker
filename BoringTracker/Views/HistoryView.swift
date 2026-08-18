import SwiftUI

/// Everything logged, newest first, under a heading per day. Today is one day
/// like every other; it merely happens to sort to the top.
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
    /// The row a repeat has just written, while it is still worth pointing at.
    ///
    /// Logging again writes a row dated now, which lands among rows dated a few
    /// minutes ago — so without this you are left comparing timestamps to find
    /// out which one your tap made (docs/TODO.md item 20). It clears itself: a
    /// mark that stays is a second state to reason about, and by the time you
    /// have looked away and back the answer to "which is new" is no longer a
    /// question anyone is asking.
    @State private var highlighted: HistoryItem.ID?

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
                    // **One section for the whole log, not one per day.** This
                    // is the entire fix for the 1.5s freeze this screen used
                    // to open with, and it is not about how much is drawn: a
                    // `Section` costs about 0.8ms to put into a `List`
                    // regardless of what is in it, so 1,733 days cost 1.4
                    // seconds of blocked main thread before a row is drawn.
                    // 1,517–1,543ms before, 321–327ms after, three runs each.
                    //
                    // Measured four ways at 29,729 entries, because the obvious
                    // suspects were all wrong (docs/scale.md): every row in one
                    // section is 185ms, every section with one trivial row each
                    // is 1,375ms, and taking the header away or moving to
                    // `.plain` changes neither. The rows are cheap and the
                    // sections are not.
                    //
                    // What it costs is the card per day — one section is one
                    // card — so the day heading is a row that looks like the
                    // header it replaces, and the gap between days is the
                    // heading's clear background rather than the space between
                    // two cards. Nothing else about the screen changes: every
                    // row is still here, newest first, grouped by day.
                    Section {
                        ForEach(days, id: \.day) { group in
                            dayHeading(title(for: group.day))
                            ForEach(group.items) { item in
                                HistoryRow(item: item, trackers: trackers) { editing = item }
                                    // The accent, at a fifth, over the fill a
                                    // grouped row already has: #16423F against
                                    // the row's #1C1C1E in dark mode, sampled
                                    // off a screenshot. Loud enough to find in
                                    // a list of near-identical rows, quiet
                                    // enough that it is still the same row —
                                    // white on it measures 11.1:1, so nothing
                                    // on the row gets harder to read while it
                                    // is up.
                                    //
                                    // On every row, not only the marked one, so
                                    // the unmarked rows are drawn by the same
                                    // expression instead of one row having to
                                    // match iOS's default by hand. It does
                                    // match — the named colour renders the same
                                    // #1C1C1E the list drew before this — and
                                    // painting them all is what keeps that
                                    // true if it ever stops being.
                                    //
                                    // **The fade has to live here.**
                                    // `withAnimation` around the state change
                                    // does not reach a row's background: it was
                                    // written that way first and a recording
                                    // showed the mark cut off between two
                                    // frames rather than fading. Attached to
                                    // the colour, it fades over ~785ms,
                                    // measured the same way.
                                    .listRowBackground(
                                        Color.accentFill
                                            .opacity(highlighted == item.id ? 0.2 : 0)
                                            .animation(
                                                .easeOut(duration: 0.9), value: highlighted
                                            )
                                            .background(Color(.secondarySystemGroupedBackground))
                                    )
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            if let entry = item.entries.first {
                                                store.deleteBatch(containing: entry)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        // The `Toggle` case from the root
                                        // tint's own comment, arriving for
                                        // real: `.tint(.primary)` reaches a
                                        // swipe action, so this drew as a blank
                                        // white capsule in dark mode — white
                                        // fill, white label, no glyph and no
                                        // word — on the one control in the app
                                        // that destroys a record. `role:
                                        // .destructive` does not survive an
                                        // inherited tint, so the red is named
                                        // here, exactly as a bar button names
                                        // `navBarAccent()` (docs/TODO.md item
                                        // 20).
                                        .tint(.red)
                                    }
                            }
                            // Both gestures this screen offers are invisible:
                            // swipe-to-delete is invisible by iOS's design, and
                            // a row that opens an editor when tapped looks
                            // exactly like a row that does nothing (docs/TODO.md
                            // item 22). One sentence in the ordinary footer
                            // idiom, which the log sheet already uses, costs no
                            // tap and no chrome — a hint that never moves is
                            // cheaper than a gesture nobody finds.
                            //
                            // **Under the first day only.** A hint under the
                            // last day is at the bottom of a list that is five
                            // years long, which is nowhere; this one is the
                            // first thing under the rows you arrive looking at,
                            // and repeating it under all 1,733 days would be the
                            // app nagging.
                            //
                            // A row rather than a `Section` footer since the
                            // sections went: same words, same place, same
                            // secondary footnote the footer style drew it in.
                            //
                            // No icon and no colour: the plain footer style is
                            // already secondary, and anything louder competes
                            // with the rows for the same glance.
                            if group.day == days.first?.day {
                                Text("Tap a row to edit it, or swipe to delete.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(
                                        EdgeInsets(
                                            top: 6, leading: 16, bottom: 6, trailing: 16
                                        )
                                    )
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
        // Marked from what the store wrote rather than at the disc that was
        // tapped, so the row is marked however the write arrived — this
        // screen's disc today, anything else that goes through `logAgain`
        // later.
        //
        // No animation on the way in, and none is wanted: the row it marks is
        // being inserted in the same instant, so it arrives already marked
        // rather than fading up from a row that was not there a frame ago.
        // Measured off a recording — the mark is at full strength in the frame
        // the row appears in. (The `onAppear` path below has to say so
        // explicitly, because there the row is already on screen.)
        .onChange(of: store.lastLoggedAgainRow) { _, row in
            guard let row else { return }
            highlighted = row
        }
        // And on arrival, if the write is seconds old. `onChange` only fires
        // for a write made while this screen is up, which since item 20 is no
        // longer where most repeats happen: the Log again sheet writes over
        // home and dismisses, so coming here straight afterwards to see what
        // landed — the exact moment this mark is for — would find nothing
        // marked.
        //
        // Recent, rather than merely pending. A repeat's undo stands until
        // something newer is written, so an hour-old repeat is still in the
        // slot, and marking it on every visit until then would flash a mark at
        // a row nobody just made. Five seconds is "I tapped that and opened
        // History to look", and nothing longer.
        .onAppear {
            guard let row = store.lastLoggedAgainRow, let at = store.lastLoggedAgainAt,
                  Date().timeIntervalSince(at) < 5 else { return }
            // Without animations, so this path marks the way the other one
            // does. The colour below carries an `.animation`, which is
            // bidirectional: on the `onChange` path the row is being inserted
            // at that instant so there is nothing to animate from, but here the
            // row is already on screen and the mark would otherwise bloom up
            // over 0.9s — 0.9s of fade-in eating into a 2s hold, on a mark
            // whose whole job is to be there when you look. The same
            // `disablesAnimations` transaction the log sheet presents with.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { highlighted = row }
        }
        // It fades on its own, which is the half that is a decision: a mark
        // that stays is a second state to reason about. `task(id:)` restarts
        // the clock when a second repeat marks a second row, and cancels when
        // the screen goes — so nothing is left running behind a screen nobody
        // is on.
        .task(id: highlighted) {
            guard highlighted != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            highlighted = nil
        }
    }

    /// The day heading, as a row rather than a section header.
    ///
    /// It has to *be* a header without being one, so it is drawn as the header
    /// it replaced and says so to VoiceOver. `.headline` in `.secondary` is not
    /// a guess: a probe build put the candidate fonts in a list beside a real
    /// inset-grouped header at this OS version and compared them on screen, and
    /// `.headline` is the one that matches — same size, same weight, same grey.
    /// If iOS restyles its headers, this stops matching and will need looking
    /// at again; that is the price of the section going, and it is written down
    /// here so the next person knows where to look.
    ///
    /// The clear background is what keeps the day boundary visible: the rows
    /// either side of it sit on the card colour, so a row that does not draws a
    /// gap where two cards used to leave one. **Not the same gap** — the review
    /// measured this one at about 17 points a day wider, and the first heading
    /// 47 points lower than the first card was, because these insets are paid on
    /// top of what a headerless `Section` already reserves rather than instead
    /// of it. Left as it is and parked in docs/TODO.md under "Noted, not
    /// scheduled"; the numbers are in docs/scale.md.
    ///
    /// `TrackerDetailView.dayHeading` is the same heading with the day's total
    /// beside it, and the two have already drifted once over where the header
    /// trait goes — see the comment there before changing either.
    private func dayHeading(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            // Sections announce their headers; a `Text` in a row does not, so
            // it is said explicitly. Without this the rotor loses every day
            // heading in the history, which is the one thing that makes a
            // five-year list navigable without scrolling it.
            .accessibilityAddTraits(.isHeader)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            // Leading 16 to line up with `HistoryRow`, which sets its own.
            .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 6, trailing: 16))
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
            groups[store.dayKey(item.date), default: []].append(item)
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
        // Asked once for the row and handed to both halves. It is the same call
        // that decides what a tap writes, and asking it twice per row on a list
        // as long as your history is a linear scan of the trackers per ask.
        let canRepeat = !store.repeatableEntries(of: item).isEmpty
        // Two plain buttons with disjoint frames, the same shape a home card
        // uses: tapping the row edits it, tapping the disc logs it again.
        return HStack(spacing: 8) {
            Button(action: edit) {
                // The time is on the identity line rather than beside the
                // numbers: it is the same footnote grey, and the two quiet
                // things belong together above the one loud one.
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(identityLine(line, canRepeat: canRepeat))
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
            repeatButton(canRepeat: canRepeat)
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
    /// opening an empty sheet — the plus in it says a log is written either way.
    ///
    /// Off when the row has nothing left to write: every tracker it named has
    /// been deleted or archived, or is a measurement — a weight-only row greys
    /// its disc because a repeat drops measurement members rather than copying
    /// a reading nobody took (docs/TODO.md item 23). One rule, not two: the
    /// greying is `Store.repeatableEntries` coming back empty, the same call
    /// that decides what a tap writes. A control that looks live and does
    /// nothing is worse than one that plainly cannot be used.
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
    private func repeatButton(canRepeat: Bool) -> some View {
        // `RepeatDisc`, not a disc drawn here: this action appears in three
        // places and drawing it three times is what let home's copy come out a
        // different colour (docs/TODO.md item 21). The greying follows the
        // `.disabled` below, from inside the label.
        return Button { store.logAgain(item) } label: { RepeatDisc() }
            .buttonStyle(.plain)
            .disabled(!canRepeat)
            .accessibilityLabel("Log again")
    }

    private var line: HistoryItem.Line { item.line(trackers: trackers) }

    /// The identity line, with the reason the disc is off appended when it is.
    ///
    /// **On the quiet line, not beside the disc.** There is no room by the disc
    /// — it is 44pt of a row whose other end is the time — and the identity
    /// line is already where this row says what it is, and where "Deleted
    /// tracker" has always appeared. A word there costs no height at any type
    /// size, wraps with the line it is on, and is read in the same glance as
    /// the thing it is about.
    ///
    /// Nothing is appended while the disc works: a row that can be repeated has
    /// nothing to explain, and a label on every row would be noise on the
    /// screen you scroll most.
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
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-history"))
    )
    return NavigationStack { HistoryView().environment(store) }
}
