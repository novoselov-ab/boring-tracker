import SwiftUI

/// Your trackers as cards. That's the whole main screen.
struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(LogSheet.lastGroupKey) private var lastGroup = ""
    @State private var logging: LogSheet.Target?
    /// Whether the Log again sheet is up. Not a `Route`: it comes up over home
    /// and leaves as soon as it has written something, so it is a presentation
    /// rather than a place (docs/TODO.md item 20).
    @State private var loggingAgain = false
    /// The row the sheet wrote from here, while it is still the one the store
    /// would take back.
    ///
    /// The store keeps one undo slot for the whole app and a repeat's offer
    /// stands until something newer is written, so "is there a repeat to undo"
    /// is not the same question as "did this screen write it". Only the second
    /// one belongs on home. Comparing the row rather than keeping a flag is
    /// what makes it self-clearing: an undo empties the slot and a repeat made
    /// on History replaces it, and either way this stops matching.
    @State private var wroteRow: HistoryItem.ID?
    @State private var path: [Route] = []

    /// Everything reachable from here. An enum rather than a bare `UUID` so
    /// settings can be pushed onto the same stack instead of arriving as a
    /// second sheet over the top of the log sheet.
    enum Route: Hashable {
        case tracker(UUID)
        case history
        case settings
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.activeTrackers.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("Boring Tracker")
            // Always the small title, never the large one. A large title is
            // only drawn at the top of the scroll and swaps for the inline one
            // as you move, so the screen reads as changing when nothing but
            // the offset has: the same words, twice the size, in a different
            // place. Inline says it once. It is also what every other screen
            // here already does, which is the point of this item.
            //
            // It gives vertical space back rather than taking it — the large
            // title's own band is gone — so the density item 11 bought is
            // intact; the card count is in the commit body.
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    // Home writes an undo-able thing now: the Log again sheet
                    // dismisses onto this screen, so this is where the offer to
                    // take it back has to be (docs/TODO.md item 20). The same
                    // `UndoBar` History draws, not a copy — one wording for one
                    // undo slot.
                    //
                    // **Only what the sheet wrote from here.** The store's slot
                    // is global and a repeat's offer never expires, so reading
                    // it directly meant that repeating a row on History and
                    // tapping Back pinned "Logged again" over the main screen
                    // for the rest of the session — an offer for something done
                    // on another screen, which is exactly what
                    // `offersDeletion: false` exists to stop in the other
                    // direction, and one whose Undo silently removes a batch if
                    // it is tapped ten minutes later. Matching `wroteRow`
                    // narrows it to this screen's own write, which is what the
                    // bar has always meant: the undo of the screen that wrote
                    // the thing.
                    //
                    // `offersDeletion: false` for the reason the sheet used to
                    // pass it: home has deleted nothing, and a deletion's offer
                    // is deliberately never expired, so without it a swipe on
                    // History would pin "Deleted batch" here instead.
                    if offersUndo {
                        UndoBar(offersDeletion: false)
                    }
                    logBar
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .navBarAccent()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.history) {
                        Label("History", systemImage: "clock")
                    }
                    .labelStyle(.iconOnly)
                    .navBarAccent()
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .tracker(let id): TrackerDetailView(trackerID: id)
                case .history: HistoryView()
                case .settings: SettingsView()
                }
            }
            .sheet(item: $logging) { target in
                LogSheet(target: target)
            }
            .sheet(isPresented: $loggingAgain) {
                // Told by the sheet rather than watched for: the write and the
                // dismissal happen in the same breath, so an `onChange` on the
                // store would have to guess whether the sheet was still up when
                // it fired.
                RepeatView { wroteRow = store.lastLoggedAgainRow }
            }
            // The clock the offer expires on, and the thing that redraws home
            // when it does — `offersUndo` cannot do that half, because elapsed
            // time is not state SwiftUI observes.
            //
            // **Both halves are needed and each covers the other's hole.**
            // Pushing settings or History takes the stack root off screen and
            // cancels this task, so a timer alone let a write made before the
            // trip come back with a fresh ten seconds on the way home
            // (screenshotted: the bar was still there 32 seconds after the
            // write). And a predicate alone leaves the bar drawn until
            // something else happens to invalidate the body, which coming back
            // from a pushed screen does not — same screenshot, other cause. So
            // the task recomputes what is *left* of the offer each time home
            // reappears, and the predicate keeps any redraw honest meanwhile.
            //
            // The store's own slot never expires —
            // a repeat's undo stands until something newer is written — which
            // was right when the bar lived on a screen you left, and is wrong on
            // the one screen you are always on: nothing else here would clear
            // it, so a bar could sit above the log button for the rest of the
            // session and an idle tap on Undo twenty minutes later would remove
            // a batch with no tombstone behind it.
            //
            // Ten seconds is the count-up finishing (0.8s) plus long enough to
            // read the number, decide it was the wrong row and reach the button
            // — and short enough that the offer belongs to the tap that made it.
            // After that the undo is still there on History, which is where a
            // deliberate correction goes anyway.
            .task(id: wroteRow) {
                guard wroteRow != nil, let at = store.lastLoggedAgainAt else { return }
                // What is left of the ten seconds, not ten seconds. This runs
                // again every time home comes back, so a write made before a
                // trip to settings is already over when the task restarts and
                // is cleared in the same breath rather than being given a
                // second full offer.
                let remaining = Self.undoOffer - Date().timeIntervalSince(at)
                if remaining > 0 {
                    try? await Task.sleep(for: .seconds(remaining))
                    guard !Task.isCancelled else { return }
                }
                wroteRow = nil
            }
        }
    }

    /// How long home offers to take a repeat back.
    private static let undoOffer: TimeInterval = 10

    /// Whether the bar is drawn: this screen wrote the pending repeat, and it
    /// wrote it recently.
    ///
    /// Both halves are read from the store rather than from a flag, so neither
    /// can be left standing by a screen that stopped running. The row says whose
    /// write it is; the date says how old, which is what makes the answer
    /// correct on the way back from a pushed screen where the timer above was
    /// cancelled.
    private var offersUndo: Bool {
        guard wroteRow != nil, store.lastLoggedAgainRow == wroteRow,
              let at = store.lastLoggedAgainAt else { return false }
        return Date().timeIntervalSince(at) < Self.undoOffer
    }

    /// The bottom bar: the one big thing, and one small one beside it.
    ///
    /// **The small one is the risk in item 16.** The bottom of home holds the
    /// most frequent action in the app, and a peer beside it competes with it
    /// for the same thumb — so Repeat is not a peer. It is a bordered square
    /// against a filled pill: no accent, no words, a third of the width, and
    /// the same height so the bar does not grow. Two prominent buttons were
    /// tried first and read as a choice to make on arrival, which is a decision
    /// in front of logging and wrong by default (docs/PHILOSOPHY.md).
    ///
    /// **On the leading side**, which costs Log nothing it was using: a
    /// right-handed thumb rests at the bottom right, and the pill still runs
    /// under it. Trailing was tried and puts the rarer control in the easiest
    /// place on the screen.
    ///
    /// The glyph is History's repeat disc glyph, deliberately. `arrow.clockwise`
    /// already means "log this again" in this app, one screen away, and a word
    /// here would take another 60pt off the pill to say what the screen it
    /// opens says in its own title.
    @ViewBuilder
    private var logBar: some View {
        if !store.activeTrackers.isEmpty {
            HStack(spacing: 8) {
                Button { loggingAgain = true } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        // Width only. A height here makes this button *taller*
                        // than the pill it is meant to sit under — measured at
                        // 60pt against the pill's 50 — and a secondary control
                        // that overhangs the primary one is the competition
                        // this shape exists to avoid. Left to itself,
                        // `.controlSize(.large)` gives both the same 50.
                        .frame(width: 30)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                // The glyph stays; only what VoiceOver reads changes. "Log
                // again" is what the screen it opens is called and what
                // History's disc already says (docs/TODO.md item 20).
                .accessibilityLabel("Log again")
                // Unlike a card's small +, this is the primary action: it
                // opens the last-used group instead of this row's. It stays
                // centred enough to sit inside either hand's thumb arc.
                Button(action: logLastGroup) {
                    Label("Log", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        // Dark on the fill, not the white iOS draws by
                        // default — see `Color.onAccent`. Inside the label,
                        // because that is where a `.disabled` outside can
                        // still reach it.
                        .onAccentFill()
                }
                .buttonStyle(.borderedProminent)
                // The accent is named here rather than inherited: the
                // environment tint is the ordinary label colour now, and the
                // accent is a fill (docs/TODO.md item 13c, `Color.accentFill`).
                .tint(Color.accentFill)
                .controlSize(.large)
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 440 : .infinity)
            .padding(.horizontal)
            .padding(.vertical, 6)
            // The inset is reserved across the full width, so the bar has to
            // span it. Backing only the constrained buttons left the list
            // scrolling through untinted gutters either side of it on a
            // regular-width screen.
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    /// Straight into whatever you logged last, with the keypad up. No picker
    /// in between — that would be a tap on the common path, every time.
    private func logLastGroup() {
        guard let group = store.groupToLog(preferring: lastGroup) else { return }
        // No `tracker:` — the sheet already lands on the first field of the
        // group when none is named, and it resolves that from the store as it
        // opens rather than from a snapshot taken here.
        LogSheet.present(.init(group: group), using: $logging)
    }

    /// A dead end otherwise: with every tracker deleted or archived there is
    /// nothing to log against and nothing on screen that says how to fix that.
    private var empty: some View {
        ContentUnavailableView {
            Label("No trackers", systemImage: "number")
        } description: {
            Text("Add one to start counting whatever you like.")
        } actions: {
            // Spelled out rather than the string convenience so the label can
            // be drawn dark on the fill like every other prominent button here.
            // It is a rare screen, but a screen that says the same thing a
            // different way is what item 13 is named after.
            NavigationLink(value: Route.settings) {
                Text("Add Tracker").onAccentFill()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentFill)
        }
    }

    /// The cards split into the same blocks settings draws: one block per log
    /// group, in the order the groups first appear.
    ///
    /// Blocks are `LogGroup`s rather than runs of adjacent trackers, so what is
    /// drawn as one block is exactly what one + opens. A group's trackers need
    /// not sit next to each other — `update` leaves a tracker's position alone
    /// when its group changes — and
    /// grouping by adjacency drew a group under two identical headings while
    /// the sheet behind either one held all of it. The screen was contradicting
    /// the sheet it launches.
    ///
    /// Still not a gather: every loose tracker is its own group, so nothing
    /// jumps to the bottom of the screen for having no group and there is no
    /// "Other" heading. Only a group's stragglers move, up to where that
    /// group already is.
    ///
    /// Nothing here reorders. Ordering lives in settings, where member drags
    /// stay inside a run and a run itself moves as one block.
    private var runs: [[Tracker]] {
        store.activeTrackerRuns
    }

    private var list: some View {
        List {
            if let notice = LoadNotice(origin: store.origin, saveError: store.saveError) {
                Section { NoticeRow(notice: notice) }
            }
            // One ordered list, in the order the groups first appear: a group
            // gets its heading over its trackers, and every loose tracker is a
            // bare card where it already sits (docs/PRODUCT.md). Nothing is
            // gathered at the bottom and there is no "Other" heading — having
            // no group is the normal state, not a leftover, and it needs no
            // special case here.
            // Keyed on the first card, not on the run itself: `Tracker` hashes
            // over every stored property, including the two timestamps and the
            // sort index that a reorder rewrites on every row. Keyed by value,
            // one drag in settings changes the identity of every run, and the
            // list is rebuilt from scratch instead of moving the row that moved.
            ForEach(runs, id: \.first?.id) { run in
                Section {
                    ForEach(run) { tracker in
                        TrackerCard(
                            tracker: tracker,
                            open: { path.append(.tracker(tracker.id)) },
                            log: {
                                LogSheet.present(
                                    .init(group: LogGroup(of: tracker), tracker: tracker.id),
                                    using: $logging
                                )
                            }
                        )
                    }
                } header: {
                    if let group = run.first?.group, !group.isEmpty {
                        Text(group)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // Every loose tracker is its own section (see `runs`), so the gap
        // between sections is paid once per card rather than once per group —
        // with ten trackers the default spacing was costing more vertical room
        // than two whole cards. Compact is the standard shorter value; nothing
        // here is hand-tuned.
        .listSectionSpacing(.compact)
    }
}

/// A daily total, or the latest reading. The two kinds of tracker are the only
/// real decision in the product, so they are the only real difference here.
///
/// One line, not three. The stacked name-over-number card was 118pt tall and
/// four of them filled a phone, which made the home screen a thing you scroll
/// rather than a thing you read (docs/TODO.md item 11). Name left, number right,
/// caption tucked under the name for the measurement kind: the same information
/// in the height of a standard list row, and the number is still the loudest
/// thing on it.
///
/// At `.xxxLarge` and above it goes back to stacking — see `isStacked`. The
/// row is only worth compressing while it still reads.
private struct TrackerCard: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The app has exactly one animation, and this is it — so this is the only
    /// place that has to ask.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tracker: Tracker
    let open: () -> Void
    let log: () -> Void

    var body: some View {
        // Read once per pass and handed down. Both of these scan the whole
        // entry history — `total` and `latestEntry` are linear — and they are
        // wanted three times over between the layout and the spoken label. Six
        // to ten of these cards are on screen by design, which is the point of
        // this item, so a per-card constant factor is the one that shows.
        let headline = headline
        let caption = caption
        return HStack(spacing: 8) {
            // Two plain buttons with disjoint frames rather than a
            // NavigationLink wrapping a button: a link would either swallow the
            // + or leave its chevron stranded in the middle of the card.
            Button(action: open) {
                summary(headline, caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    // Spelled out rather than composed from the child order,
                    // which put "8 hours ago" before "78.4 kg" once the caption
                    // moved up beside the name. The number is the reading; the
                    // qualifier goes after it. On the label content rather than
                    // on the `Button` — applied outside, the button still read
                    // its children in layout order and this had no effect.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        [tracker.name, headline.text, caption]
                            .compactMap { $0 }
                            .joined(separator: ", ")
                    )
            }
            .buttonStyle(.plain)
            // Left on the `Button`, deliberately, though the label above had to
            // move inside. Moving this too was tried and reverted: the claim it
            // rested on — that these modifiers do nothing out here — is
            // contradicted twice in this repo, by `logButton` below and by
            // HistoryView's row, both of which label a `.plain` button from
            // outside and are read correctly. The difference may be the
            // `children: .ignore` above turning this button into a container,
            // in which case the hint belongs inside after all. Unverified
            // either way: it needs VoiceOver, not a reading of the tree, and
            // guessing costs the hint entirely on the users who rely on it.
            .accessibilityHint("Shows the history")
            logButton
        }
        // The row is as tall as the + and no taller. The default inset-grouped
        // row padding was adding 46pt of its own, which is most of a second row.
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
    }

    /// Whether the row has given up on fitting on one line.
    ///
    /// One threshold, read in both places that branch on it — the layout and
    /// the name's line cap — because a row that stacks with its name still
    /// capped to one line is the clipped-name bug wearing the other layout.
    ///
    /// `.xxxLarge`, not `isAccessibilitySize`. The fallback was pitched at the
    /// accessibility sizes because that is where the name was first seen to
    /// collapse, but the top of the *normal* slider is already past it: on an
    /// SE, "Calories burned exercising" beside "1,234,567 kcal" leaves "Calo…"
    /// at `.xxxLarge`, which does not tell that row from the "Calories" one
    /// under it. `.xxLarge` still leaves "Calorie…" and is left alone — that
    /// reads, and it is where the density is still worth having.
    private var isStacked: Bool {
        typeSize >= .xxxLarge
    }

    /// One line normally, stacked once the text outgrows it.
    ///
    /// The whole point of item 11 is that a name and a number fit on one row,
    /// and at ordinary sizes they do. Past `isStacked` they cannot: the number
    /// is sized first, the name absorbs the entire shortfall, and the screen
    /// becomes a column of numbers with no legible labels — at AX3 and up
    /// "Calories" rendered as a single clipped glyph. Density is worth having
    /// only while the row is still readable, so above the threshold this falls
    /// back to the stacked shape the card had before, which has room for both.
    /// Somebody reading at AX5 is not the person counting how many cards fit.
    @ViewBuilder
    private func summary(_ headline: Headline, _ caption: String?) -> some View {
        if isStacked {
            VStack(alignment: .leading, spacing: 2) {
                nameBlock(caption)
                headlineText(headline)
            }
        } else {
            // `spacing: 0`, with the gap coming from the `Spacer` alone. An
            // HStack inserts its spacing on *both* sides of a spacer, so
            // `spacing: 8` around `Spacer(minLength: 8)` reserved 24pt rather
            // than 8 — and since the number outranks the name, all 16pt of the
            // surplus was spent out of the name's truncation budget, which is
            // the width this row has least of.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                nameBlock(caption)
                Spacer(minLength: 8)
                headlineText(headline)
                    // The number gets the width it needs and the name is what
                    // gives way, because the number is the one thing on this
                    // row that has to be readable across a kitchen and a
                    // truncated name still says which tracker it is. How far
                    // that goes is bounded by `isStacked` rather than by
                    // anything here: the worst case left inside this branch is
                    // "Calorie…" beside "1,234,567 kcal", on an SE at
                    // `.xxLarge`. A floor on the name was tried instead and
                    // reverted — `minWidth` reserves its width whether the name
                    // needs it or not, so "Weight" kept an 83pt blank gap and
                    // charged it to the number, which halved. That is this
                    // row's priority backwards, and for the common short name.
                    .layoutPriority(1)
            }
        }
    }

    /// A tracker name is unbounded free text — the editor sets no limit — and
    /// "Calories burned exercising" wrapping to three lines would put back
    /// exactly the row height this card exists to cut. Capped on the one-line
    /// layout, uncapped on the stacked one, which has the room.
    ///
    /// The name is drawn in the primary colour, like the number. Grey means
    /// "secondary" and the name is not: it is the only thing on the row that
    /// says which number you are reading, and a grey label beside a white
    /// total reads as an annotation on it. The hierarchy is carried by size
    /// and weight instead — `.subheadline` against a medium `.title2` — which
    /// still puts the number first at a glance without making the label
    /// something you have to look for. The caption stays grey, because
    /// "8 hours ago" genuinely is secondary to the reading it dates.
    private func nameBlock(_ caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tracker.name)
                .font(.subheadline)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(isStacked ? nil : 1)
    }

    /// Shrunk from `.largeTitle` to `.title2`, which is the largest size that
    /// fits beside the 44pt + without making the row taller than the button
    /// already does. "Legible at a glance with one hand at the fridge" is a
    /// floor, not a reason to spend a third of the screen on four numbers.
    ///
    /// One line, and it shrinks rather than truncating — on *both* layouts. The
    /// scale factor used to live only on the one-line branch, which left the
    /// stacked branch, the one that exists because the text is already too big,
    /// clipping "1,234 kcal" to "1,23…" at AX5 on an iPhone SE. A clipped total
    /// is worse than a small one, and that is no less true where the type is
    /// large on purpose.
    @ViewBuilder
    private func headlineText(_ headline: Headline) -> some View {
        Group {
            if let amount = headline.amount {
                // Counts to the new number instead of swapping to it
                // (docs/TODO.md item 20). Item 15 rolled the digits with
                // `.contentTransition(.numericText)`, which is a handsome
                // 0.3s and shows you a *different* number rather than the
                // addition: 1,690 became 1,780 and you were left to work out
                // that a 90 had gone in. Counting says which way and roughly
                // how much before you have read a digit.
                CountingNumber(value: amount) { tracker.format($0) }
            } else {
                // A measurement tracker nobody has logged yet. There is no
                // number to count from, so the em dash is simply replaced.
                Text(headline.text)
            }
        }
        .font(.title2.weight(.medium))
        // Load-bearing while it counts, not a nicety: proportional digits
        // change width on every frame, so the number would shiver through the
        // whole animation and drag the name beside it along.
        //
        // It fixes the width of a digit, not the *number* of them. A count that
        // crosses a grouping boundary — 950 to 1,050 kcal, an ordinary lunch —
        // gains a digit and a separator part-way through, and because the
        // number carries `layoutPriority(1)` it takes that width out of the
        // name's truncation budget, so a name long enough to truncate
        // re-truncates mid-count. Raised in review and left: reserving the
        // width is the `minWidth` that `summary` tried and reverted for the
        // common short name, and reserving the *destination* width would move
        // the name before the number arrives.
        .monospacedDigit()
        // On the card rather than at the place that writes, which is what
        // keeps it honest in both directions. Nothing waits on it: `log()`
        // still writes and dismisses in the same breath, and this counts
        // behind the sheet on its way out — measured, see the commit and
        // docs/TODO.md item 15. And it belongs to the number rather than to
        // the log sheet, so logging again — which changes the same total by
        // another door — gets it for free, as does an undo, an edit and a
        // deletion.
        //
        // 0.8s, where item 15 was 0.3s: at 0.3 a count is a flicker and reads
        // as the swap it replaced. It is still an ease rather than a spring —
        // a spring is a bounce, and a number that bounces is congratulating
        // you (docs/PHILOSOPHY.md "Quiet") — and easing out means the count
        // arrives rather than stopping dead.
        //
        // Keyed on the amount rather than on the string it prints, because the
        // amount is what is being interpolated. Two consequences, both looked
        // at and kept: editing a tracker's unit or decimals changes the string
        // without changing the number, and now swaps rather than transitions —
        // which is right, since nothing was logged; and the midnight rollover
        // still counts a daily total down to zero, now over 0.8s rather than
        // 0.3s. Item 15 left that deliberately (the number really did change)
        // and slowing it does not make it a different decision.
        //
        // `nil` under Reduce Motion, which swaps the number instantly. Somebody
        // who has asked the system for less motion has not asked for the app's
        // one animation to run nearly three times longer than it used to, and
        // what the count buys — watching the addition happen — is exactly the
        // moving thing that setting turns off. This is the only animation in the
        // app, so it is the only place that has to ask.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: headline.amount)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// The bottom Log button, scaled down: same fill, same tint, same meaning.
    ///
    /// It used to be a bare blue glyph, which is a different design language
    /// from the thing it is a smaller version of, and low enough contrast that
    /// people did not read it as a control at all. The filled circle is 30pt so
    /// it stays visibly secondary to the 50pt Log pill; the 44pt frame around
    /// it is the tap target, and `contentShape` is what makes the frame — not
    /// the fill — the thing your thumb has to hit.
    ///
    /// A tinted `.bordered` fill was tried instead, on the grounds that eight
    /// solid dots down one screen is loud. It was rejected on the original
    /// complaint: a blue glyph on a pale blue disc is exactly the low contrast
    /// this was meant to fix, and the size and the idiom were only two of the
    /// three things wrong with it.
    private var logButton: some View {
        Button(action: log) {
            Image(systemName: "plus")
                // Fixed, not `.subheadline`: the disc and the 44pt target are
                // fixed too, and a text style scales without them. At AX3 the
                // glyph outgrew its circle and the + drew as a crosshair
                // straddling the edge — the "doesn't read as a control"
                // complaint this button exists to fix, arriving by another
                // door. A control that is already a comfortable target at
                // every size has nothing to gain by growing.
                .font(.system(size: 15, weight: .bold))
                // The same dark-on-accent the Log pill uses, for the same
                // measured reason: this glyph sits on the identical fill six to
                // ten times down the main screen, so on the old teal it was the
                // identical 1.86:1. The two move together or the screen has two
                // design languages again (docs/TODO.md item 13b).
                .foregroundStyle(Color.onAccent)
                .frame(width: 30, height: 30)
                // `Color.accentFill`, not `.tint` and not `Color.accentColor`:
                // the environment tint is the ordinary label colour now, and
                // the catalog colour that second name resolves does not exist
                // yet (docs/TODO.md items 13c and 18).
                .background(Color.accentFill, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log \(tracker.name)")
    }

    /// What the card shows, and the number behind it.
    ///
    /// Both together because both come from the same linear scan of the entry
    /// history, and the transition needs the number to know which way the
    /// digits should roll. `nil` where there is nothing to show — a
    /// measurement tracker nobody has logged yet, which prints an em dash.
    private struct Headline {
        var text: String
        var amount: Double?
    }

    private var headline: Headline {
        switch tracker.kind {
        case .dailyTotal:
            let total = store.total(for: tracker.id, on: store.today)
            return Headline(text: tracker.format(total), amount: total)
        case .measurement:
            let latest = store.latestEntry(for: tracker.id)
            return Headline(
                text: latest.map { tracker.format($0.value) } ?? "—", amount: latest?.value
            )
        }
    }

    private var caption: String? {
        switch tracker.kind {
        case .dailyTotal:
            nil
        case .measurement:
            store.latestEntry(for: tracker.id).map {
                $0.date.formatted(.relative(presentation: .named))
            }
        }
    }
}

/// A number that counts to its new value rather than swapping to it.
///
/// `Animatable` on the view itself, which is the whole mechanism: SwiftUI
/// interpolates `animatableData` across whatever animation is in flight and
/// calls `body` for each frame, so the *value* is what animates and the text is
/// simply drawn from it. There is no timer, no `TimelineView` and no state —
/// nothing runs when nothing is changing.
///
/// It formats per frame, deliberately. A tracker's own `format` is what makes
/// 1,690 read as "1,690 kcal" and 79.5 as "79.5 kg", and counting through
/// numbers drawn by a second, simpler rule is how the card would disagree with
/// itself mid-count — decimals and grouping included. Roughly fifty
/// `FormatStyle` calls over the animation, on the one card whose number
/// changed.
private struct CountingNumber: View, Animatable {
    var value: Double
    /// `@Sendable`, and `nonisolated` below, because SwiftUI interpolates the
    /// value off the main actor: `Animatable` is not main-actor isolated and a
    /// `View` is, so under Swift 6 the conformance only compiles when the part
    /// the animator touches stands outside the isolation. It touches the
    /// number, never the formatting.
    let format: @Sendable (Double) -> String

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}

// MARK: - Telling the user when something was wrong with their data

private struct LoadNotice {
    var title: String
    var detail: String

    init?(origin: StoreOrigin, saveError: String?) {
        if let saveError {
            self.title = "Couldn't save"
            self.detail = saveError
            return
        }
        switch origin {
        case .backup:
            title = "Recovered from backup"
            detail = "The store file couldn't be read, so the previous copy was used. "
                + "Anything logged in the last moments before that may be missing."
        case .unreadable(let quarantine):
            title = "Couldn't read your data"
            detail = "The files that wouldn't open were kept at \(quarantine.lastPathComponent) "
                + "and the app started fresh. Nothing was deleted."
        case .file, .fresh:
            return nil
        }
    }
}

private struct NoticeRow: View {
    let notice: LoadNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(notice.title, systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(notice.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal")
    let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1, sortIndex: 1)
    let store = Store(
        document: StoreDocument(
            trackers: [calories, weight],
            entries: [
                Entry(trackerID: calories.id, value: 620, date: .now.addingTimeInterval(-7_200)),
                Entry(trackerID: calories.id, value: 415, date: .now.addingTimeInterval(-3_600)),
                Entry(trackerID: weight.id, value: 78.4, date: .now.addingTimeInterval(-86_400)),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview"))
    )
    return HomeView().environment(store)
}
