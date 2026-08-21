import SwiftUI

/// Everything logged, newest first, under a heading per day. Today is one day
/// like every other; it merely happens to sort to the top.
struct HistoryView: View {
    @Environment(Store.self) private var store
    @State private var editing: HistoryItem?
    /// Filtered through the same `HistoryItem.matches` as the Log again sheet:
    /// two implementations of one search would drift, and the second would be
    /// the one nobody tests. Not snapshotted the way that sheet's list is —
    /// this screen has to stay live, because deleting a row and repeating one
    /// both have to show here straight away.
    @State private var query = ""
    /// The row a repeat has just written. Logging again writes a row dated now,
    /// which lands among rows dated minutes ago, so without this you are left
    /// comparing timestamps to find the one your tap made.
    @State private var highlighted: HistoryItem.ID?

    private struct Jump: Equatable {
        var day: DayKey
        var count: Int
    }

    /// The day the list has been asked to scroll to, and which asking it was.
    ///
    /// **The counter is what makes the same day twice a second jump**, and it
    /// replaced clearing this back to `nil` inside its own `onChange`. That
    /// worked and cost a whole extra evaluation of this screen's `body` per
    /// jump — rebuilding `Store.historyItems`, regrouping every day and diffing
    /// every row.
    @State private var jumpTarget: Jump?
    /// `picked` outlives the popover on purpose: jumping to March and then to
    /// April is two opens, and the second should not start back at today.
    @State private var jumping = false
    @State private var picked = Date()

    var body: some View {
        let days = days
        // One dictionary for the whole screen. `HistoryItem.line` takes it as a
        // parameter precisely so a screenful of rows does not each rebuild it.
        // `uniquingKeysWith`, because a document holding two trackers with the
        // same id is a shape the load path accepts and would trap
        // `uniqueKeysWithValues`.
        let trackers = Dictionary(
            store.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        // `entries`, not `historyItems`: the two are empty together — a
        // `HistoryItem` refuses only an empty batch — and this is a stored
        // array's `isEmpty` rather than a walk that groups and sorts five years
        // of them.
        let logged = !store.entries.isEmpty
        Group {
            if !logged {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "clock",
                    description: Text("Your entries will appear here after you log them.")
                )
            } else if days.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollViewReader { proxy in
                    List {
                        // **One section for the whole log, not one per day —
                        // and day grouping must not become sections again.** A
                        // `Section` costs about 0.8ms to put into a `List`
                        // whatever is in it, so 1,733 days were 1.4s of blocked
                        // main thread before a row was drawn: 1,517–1,543ms
                        // before, 321–327ms after, three runs each at 29,729
                        // entries. Every row in one section is 185ms, and taking
                        // the header away or moving to `.plain` changes neither
                        // (docs/scale.md). The rows are cheap; the sections are
                        // not.
                        Section {
                            ForEach(days, id: \.day) { group in
                                // What a jump lands on: the heading rather
                                // than the first row, so the day you asked for
                                // arrives with its name above it.
                                dayHeading(title(for: group.day))
                                    .id(group.day)
                                ForEach(group.items) { item in
                                    HistoryRow(item: item, trackers: trackers) { editing = item }
                                        // The accent at a fifth over the fill
                                        // a grouped row already has: #16423F
                                        // against the row's #1C1C1E in dark
                                        // mode, sampled off a screenshot, with
                                        // white on it at 11.1:1.
                                        //
                                        // **The fade has to live on the
                                        // colour.** `withAnimation` around the
                                        // state change does not reach a row's
                                        // background: it was written that way
                                        // first, and a recording showed the mark
                                        // cut off between two frames rather than
                                        // fading.
                                        //
                                        // Handed to `rowPress()` rather than set
                                        // here — a row has one background and
                                        // the press fills it, so the two are one
                                        // expression or the last one written
                                        // wins.
                                        .rowPress(
                                            rest: Color.accentFill
                                                .opacity(highlighted == item.id ? 0.2 : 0)
                                                .animation(
                                                    .easeOut(duration: 0.9), value: highlighted
                                                )
                                                .background(
                                                    Color(.secondarySystemGroupedBackground)
                                                )
                                        )
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                if let entry = item.entries.first {
                                                    store.deleteBatch(containing: entry)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            // `.tint(.primary)` at the root
                                            // reaches a swipe action, so this
                                            // drew as a blank white capsule in
                                            // dark mode — white fill, white
                                            // label, no glyph and no word — on
                                            // the one control in the app that
                                            // destroys a record. `role:
                                            // .destructive` does not survive an
                                            // inherited tint, so the red is
                                            // named here.
                                            .tint(.red)
                                        }
                                }
                                // Both gestures this screen offers are
                                // invisible — swipe-to-delete by iOS's own
                                // design, and a row that opens an editor looks
                                // exactly like a row that does nothing
                                // (docs/TODO.md item 22). Under the first day
                                // only: the last day is at the bottom of five
                                // years, and repeating it under all 1,733 days
                                // would be the app nagging.
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
                    // The transaction is what stops the popover's own dismissal
                    // animation being inherited by the scroll; `scrollTo`
                    // outside `withAnimation` is already instant.
                    .onChange(of: jumpTarget) { _, target in
                        guard let target = target?.day else { return }
                        var instant = Transaction()
                        instant.disablesAnimations = true
                        withTransaction(instant) { proxy.scrollTo(target, anchor: .top) }
                        // `scrollTo` moves the list and posts nothing, so with
                        // VoiceOver on, tapping a date was silent. Focus is
                        // deliberately not moved instead: that would mean an
                        // `AccessibilityFocusState` on every one of 1,733 day
                        // headings.
                        AccessibilityNotification.PageScrolled(title(for: target)).post()
                    }
                }
            }
        }
        .toolbar {
            if Self.canJump(days: days),
               let newest = days.first?.day, let oldest = days.last?.day {
                ToolbarItem(placement: .topBarTrailing) {
                    jumpButton(oldest: oldest, newest: newest, days: days)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .searchableNames($query, when: logged)
        .safeAreaInset(edge: .bottom, spacing: 0) { UndoBar() }
        .sheet(item: $editing) { item in
            BatchEditor(item: item)
        }
        // No animation on the way in: the row it marks is being inserted in
        // the same instant, so it arrives already marked rather than fading up
        // from a row that was not there a frame ago. Measured off a recording —
        // the mark is at full strength in the frame the row appears in.
        .onChange(of: store.lastLoggedAgainRow) { _, row in
            guard let row else { return }
            highlighted = row
        }
        // And on arrival, if the write is seconds old: `onChange` only fires
        // for a write made while this screen is up, and since item 20 most
        // repeats happen on the Log again sheet over home. Recent rather than
        // merely pending — a repeat's undo stands until something newer is
        // written, so an hour-old repeat is still in the slot and would flash a
        // mark at a row nobody just made.
        .onAppear {
            guard let row = store.lastLoggedAgainRow, let at = store.lastLoggedAgainAt,
                  Date().timeIntervalSince(at) < 5 else { return }
            // Here the row is already on screen, so the `.animation` on the
            // colour would bloom the mark up over 0.9s — eating into a 2s hold,
            // on a mark whose whole job is to be there when you look.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { highlighted = row }
        }
        // Keyed on `lastLoggedAgainRow`, not a flag or a timestamp: every write
        // gets a fresh batch id, so a second repeat of the same row is a
        // different value and buzzes. `lastLoggedAgainAt` was here first and is
        // too coarse — `Date.stamp()` rounds to whole seconds so the store file
        // is lossless, so two taps inside one second carry the same date and the
        // second one arrives in silence.
        .logHaptic(store.lastLoggedAgainRow)
        // `task(id:)` so a second repeat restarts the clock instead of racing
        // it, and so nothing is left running behind a screen nobody is on.
        .task(id: highlighted) {
            guard highlighted != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            highlighted = nil
        }
    }

    /// Go to a date. It navigates and it never filters: the list under it is
    /// the whole history at every moment.
    ///
    /// A compact `DatePicker` in the nav bar and a month-index sheet were both
    /// built at 29,264 entries and compared on screen (docs/TODO.md item 25).
    /// The calendar is the only one of the three that can name a *day*, and the
    /// only one that is the same number of taps at every type size — the
    /// month/year wheel behind its title crosses five years without scrolling.
    ///
    /// The picker is bounded by the span of the days *on screen* — the ends of
    /// `days`, which is the query-filtered grouping, not the whole history. So a
    /// search for something that only happened in 2026 greys 2022–2025 out even
    /// though the store still holds them. Deliberate: the control navigates the
    /// list as displayed (docs/TODO.md item 25b).
    private func jumpButton(oldest: DayKey, newest: DayKey, days: [DayGroup]) -> some View {
        // An out-of-order `ClosedRange` traps, and this file already refuses
        // that class of crash where a document could be shaped wrong (see the
        // tracker dictionary above).
        let first = oldest.startOfDay(calendar: store.calendar)
        let last = newest.startOfDay(calendar: store.calendar)
        let range = min(first, last)...max(first, last)
        return Button {
            // Clamped before the popover opens, never after: the picker would
            // otherwise move an out-of-range selection itself, and that move
            // arrives looking exactly like a tap on a day. Today is outside the
            // range whenever the newest thing logged is older than today.
            picked = min(max(picked, range.lowerBound), range.upperBound)
            jumping = true
            // **Opening it is a jump too.** A `DatePicker` reports nothing at
            // all when you tap the day that is already selected — not through
            // `onChange`, and not through a `Binding` written by hand either,
            // which was built and tapped to check. So scrolling by hand into
            // 2022, opening the calendar and tapping today did nothing, on a
            // control whose whole job is going somewhere.
            jump(to: picked, days: days)
        } label: {
            Label("Jump to a date", systemImage: "calendar")
        }
        .labelStyle(.iconOnly)
        .navBarAccent()
        .popover(isPresented: $jumping) {
            DatePicker(
                "Jump to a date", selection: $picked, in: range, displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            // A popover sizes itself to its content and the graphical picker
            // proposes no width of its own: without this it came out 140 points
            // wide, anchored to a button in the top right, with half the
            // calendar off the edge of the screen.
            //
            // A fixed frame, so it was photographed rather than argued. **The
            // day grid is 289–306 points at every text size**, checked at five
            // of them from extra-small to AX5. The picker does scale, but
            // downwards — the month/year title grows by about two thirds and the
            // weekday row relabels `SUN MON TUE` to `S M T` (docs/scale.md), so
            // size a label in here against the 289–306. 320 also fits the
            // narrowest phone iOS 18 runs on, the 360-point 12/13 mini.
            .frame(width: 320)
            .padding(8)
            .presentationCompactAdaptation(.popover)
            // **The picker does not close itself.** Closing it on the first
            // change was written first and is worse: the month and year wheels
            // behind the title *are* the selection, so touching either one
            // jumped and dismissed — and crossing five years, which is what this
            // screen is for, needs both. That version made "March 2022" three
            // visits to a control that shuts on contact.
            .onChange(of: picked) { _, date in jump(to: date, days: days) }
        }
    }

    /// Scroll to the day that was picked, or to the nearest one with something
    /// on it.
    ///
    /// **The calendar day, not the moment.** A `DatePicker` hands back a date
    /// carrying the current time of day, and `Store.dayKey` would then read it
    /// through `dayStartHour` — so at 2am, with a 4am day start, picking the
    /// 15th would go to the 14th.
    private func jump(to date: Date, days: [DayGroup]) {
        let parts = store.calendar.dateComponents([.year, .month, .day], from: date)
        let target = DayKey(
            year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0
        )
        guard let day = DayKey.nearest(
            to: target, in: days.map(\.day), calendar: store.calendar
        ) else { return }
        jumpTarget = Jump(day: day, count: (jumpTarget?.count ?? 0) + 1)
    }

    /// The day heading, as a row rather than a section header — see the
    /// `Section` above for why there are no sections.
    ///
    /// `.headline` in `.secondary` is not a guess: a probe build put the
    /// candidate fonts in a list beside a real inset-grouped header at this OS
    /// version and compared them on screen. If iOS restyles its headers this
    /// stops matching, and that is the price of the section going.
    ///
    /// `TrackerDetailView.dayHeading` is the same heading with the day's total
    /// beside it, and the two have already drifted once over where the header
    /// trait goes — see the comment there before changing either.
    private func dayHeading(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            // A `Text` in a row announces no header trait of its own, and
            // without it the rotor loses every day heading in the history.
            .accessibilityAddTraits(.isHeader)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 6, trailing: 16))
    }

    /// Internal so `HistoryTests` can build this list through the same grouping
    /// the screen draws; this suite has no UI target.
    struct DayGroup {
        var day: DayKey
        var items: [HistoryItem]
    }

    /// Whether the jump control has anywhere to go. One day is one destination,
    /// and the picker would open on a single selectable square with both month
    /// arrows dimmed. Keyed off the *filtered* days, so a search that leaves one
    /// day standing takes the control away with it (docs/TODO.md item 25b).
    static func canJump(days: [DayGroup]) -> Bool { days.count >= 2 }

    /// The rows the query keeps, grouped by day. A day with nothing left in it
    /// is not drawn, so a search does not leave empty headings behind.
    ///
    /// **An unnamed entry disappears under a non-empty query.** This searches
    /// names, through the same `HistoryItem.matches` the Log again sheet runs —
    /// two screens filtering the same field of the same records must not
    /// disagree about what a query means (docs/TODO.md item 16b). Matching the
    /// identity line as well was refused: that line falls back to a tracker or a
    /// group for rows nobody named, so "food" would return every meal ever
    /// logged under that group.
    static func days(in store: Store, matching query: String) -> [DayGroup] {
        var groups: [DayKey: [HistoryItem]] = [:]
        for item in store.historyItems where item.matches(query) {
            groups[store.dayKey(item.date), default: []].append(item)
        }
        return groups.sorted { $0.key > $1.key }.map { DayGroup(day: $0.key, items: $0.value) }
    }

    private var days: [DayGroup] { Self.days(in: store, matching: query) }

    private func title(for day: DayKey) -> String {
        day.label(today: store.today, calendar: store.calendar)
    }
}

private struct HistoryRow: View {
    @Environment(Store.self) private var store
    let item: HistoryItem
    let trackers: [UUID: Tracker]
    let edit: () -> Void

    /// **The name leads and stays quiet.** Item 13 put the numbers first, which
    /// was right about uniformity and wrong about scanning: finding a food by
    /// name meant reading twelve small grey second lines while twelve large
    /// numbers that identify nothing took the eye first (docs/TODO.md item 14b).
    /// The fix is position, not weight — the name is still a grey footnote, and
    /// a row nobody named leads with its group or its tracker so that the first
    /// line identifies every row rather than some of them.
    var body: some View {
        let line = line
        // Asked once for the row and handed to both halves: it is the same call
        // that decides what a tap writes, and it is a linear scan of the
        // trackers per ask.
        let canRepeat = !store.repeatableEntries(of: item).isEmpty
        // Two buttons with disjoint frames, the same shape a home card uses:
        // tapping the row edits it, tapping the disc logs it again.
        return HStack(spacing: 8) {
            Button(action: edit) {
                // Beside the numbers while it fits and under them once it does
                // not: at AX5 this read `Body fat ·` / `Mea-` / `sure-` / `ment`
                // down the left against `12:20` / `AM` down the right — one row,
                // most of a screen, and *Measurement* hyphenated across three
                // lines. `StackingRow` is that fallback, shared.
                StackingRow {
                    LogRowLabel(
                        identity: identityLine(line, canRepeat: canRepeat),
                        values: line.values
                    )
                } trailing: {
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        // The time takes the width it needs: `12:04 AM` broken
                        // across two lines after the `A` is not a time any more,
                        // and an identity line that wraps is still readable. The
                        // priority is the caller's — home's card gives it to the
                        // number instead.
                        .layoutPriority(1)
                }
                .contentShape(.rect)
            }
            // `.row`, not `.plain`: `.plain`'s press is the label at 75% over
            // what is behind it, which was not something anyone noticed
            // (docs/TODO.md item 28).
            .buttonStyle(.row)
            .accessibilityHint(item.entries.count == 1 ? "Edits this entry" : "Edits this batch")
            repeatButton(canRepeat: canRepeat)
        }
        .listRowInsets(.listRow)
    }

    /// Log this row again, now. One tap: no sheet, no confirmation, and no
    /// picker in front of it.
    ///
    /// Off when the row has nothing left to write — every tracker it named has
    /// been deleted or archived, or is a measurement, since a repeat drops
    /// measurement members rather than copying a reading nobody took
    /// (docs/TODO.md item 23). The greying is `Store.repeatableEntries` coming
    /// back empty, the same call that decides what a tap writes.
    ///
    /// **The off state used to be invisible.** The disc measured 1.25:1 against
    /// the light row and was reported from real use as a control nobody could
    /// see; item 26 replaced the `.quaternary` fill under it, and it now draws
    /// `#AEAEB2` on the light row and `#636366` on the dark one — **2.21:1 and
    /// 2.84:1**, with the glyph at 9.50 and 5.99 on top of that.
    private func repeatButton(canRepeat: Bool) -> some View {
        // `RepeatDisc`, not a disc drawn here: this action appears in three
        // places, and drawing it three times is what let home's copy come out a
        // different colour.
        return Button { store.logAgain(item) } label: { RepeatDisc() }
            .buttonStyle(.accentFill)
            .disabled(!canRepeat)
            .accessibilityLabel("Log again")
    }

    private var line: HistoryItem.Line { item.line(trackers: trackers) }

    /// The identity line, with the reason the disc is off appended when it is.
    ///
    /// **On the quiet line, not beside the disc.** There is no room by the disc
    /// — it is 44pt of a row whose other end is the time — and a word on the
    /// identity line adds no element of its own. Not free at every type size: at
    /// AX5 "chocolate shake · Archived" wraps two lines further than the name
    /// alone, but a line of its own would cost those lines on every row rather
    /// than only where the disc is off.
    private func identityLine(_ line: HistoryItem.Line, canRepeat: Bool) -> String {
        guard !canRepeat, let reason = item.repeatBlockedReason(trackers: trackers) else {
            return line.identity
        }
        return "\(line.identity) · \(reason)"
    }
}

#Preview {
    let trackers = StarterTracker.defaultTrackers()
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
