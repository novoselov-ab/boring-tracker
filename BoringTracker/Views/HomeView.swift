import SwiftUI

/// Your trackers as cards. That's the whole main screen.
struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(LogSheet.lastGroupKey) private var lastGroup = ""
    @State private var logging: LogSheet.Target?
    @State private var loggingAgain = false
    /// The row the sheet wrote *from here*. The store keeps one undo slot for
    /// the whole app, so "is there a repeat to undo" is not the same question as
    /// "did this screen write it" — and comparing the row rather than keeping a
    /// flag is what makes it self-clearing.
    @State private var wroteRow: HistoryItem.ID?
    /// The row the Log again sheet last wrote, while the disc is acknowledging
    /// it (docs/TODO.md item 30).
    ///
    /// **The acknowledgement the sheet could not draw itself.** Marking the
    /// *row* as the sheet leaves was built and recorded on an iPhone 17 Pro and
    /// does not work: `dismiss()` stops the presentation's content updating, so
    /// a checkmark set on the same tap is never drawn — the sheet slides away
    /// for about 300ms showing the state it had before the tap. Held for **0ms
    /// and 50ms** the mark still never appeared; at **500ms** it did, which is a
    /// delay on the most repeated action in the app.
    ///
    /// **The written row rather than a flag**, so two repeats a moment apart are
    /// two different values — every write gets a fresh batch id. Not
    /// `lastLoggedAgainAt`, which was here first and is too coarse:
    /// `Date.stamp()` canonicalises to whole seconds, so two repeats inside one
    /// second carry the *same* date, and the second would change nothing, buzz
    /// nothing, and leave the first tap's clock to clear the mark early.
    @State private var loggedAgain: HistoryItem.ID?
    @State private var addingTracker: Tracker?
    @State private var path: [Route] = []

    /// An enum rather than a bare `UUID` so settings can be pushed onto the same
    /// stack instead of arriving as a second sheet over the top of the log
    /// sheet.
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
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    // **Only what the sheet wrote from here.** The store's
                    // undo slot is global, so reading it directly meant that
                    // repeating a row on History and tapping Back pinned
                    // "Logged again" over the main screen. `offersDeletion:
                    // false` stops the same thing in the other direction: home
                    // has deleted nothing, and a deletion's offer is
                    // deliberately never expired.
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
            .sheet(item: $addingTracker) { tracker in
                TrackerEditor(tracker: tracker)
            }
            .sheet(isPresented: $loggingAgain) {
                // Told by the sheet rather than watched for: the write and the
                // dismissal happen in the same breath, so an `onChange` on the
                // store would have to guess whether the sheet was still up.
                RepeatView {
                    wroteRow = store.lastLoggedAgainRow
                    loggedAgain = store.lastLoggedAgainRow
                }
            }
        }
        // **Outside the `NavigationStack`, not on its root content** (found in
        // review). A `task` on the root is cancelled by a push, so tapping
        // History inside that second left the flag set with nothing running to
        // unset it, and coming back drew a checkmark for a write that was by
        // then old.
        //
        // The clock starts at the write, not at the uncovering, so not all of
        // it is on screen. Off a 30fps recording of a synthesized tap, the disc
        // is drawn as a checkmark in the first frame the bar is fully uncovered
        // and holds for about 0.8s of the one; starting from the sheet's
        // `onDismiss` instead buys 0.2s and gives up the mark already being
        // there as the sheet uncovers it.
        .task(id: loggedAgain) {
            guard loggedAgain != nil else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            loggedAgain = nil
        }
    }

    /// Whether the Log again disc is saying "written".
    ///
    /// Three conditions, and each of them is a way the mark went stale in
    /// review: it has to be **this screen's** write, one the store is **still
    /// holding** — Undo sits 44pt above this disc, and a checkmark over an
    /// emptied slot is the app acknowledging a write it has just taken back —
    /// and **recent**, because `Task.sleep` does not run while the app is
    /// suspended, so backgrounding inside the second and coming back ten minutes
    /// later draws home before the sleep resumes.
    ///
    /// Two seconds against a mark that lives for one: `lastLoggedAgainAt` is
    /// canonicalised to whole seconds, so it can sit up to half a second either
    /// side of the moment it describes.
    private var isConfirming: Bool {
        guard let loggedAgain, store.lastLoggedAgainRow == loggedAgain,
              let at = store.lastLoggedAgainAt
        else { return false }
        return Date().timeIntervalSince(at) < 2
    }

    /// Whether the bar is drawn: this screen wrote the pending repeat. Only
    /// whose write it is — how old it is belongs to `UndoBar`, which asks it the
    /// same way on every screen since item 20b.
    private var offersUndo: Bool {
        wroteRow != nil && store.lastLoggedAgainRow == wroteRow
    }

    /// The bottom bar: the one big thing, and one small one beside it.
    ///
    /// **The Log pill leads and the Log again disc trails**, swapped from the
    /// other way round in item 27 and decided by the user: the pill spans most
    /// of the bar either way, so it stays under the thumb wherever the small
    /// control sits.
    ///
    /// **Repeat is not a peer, and that is the constraint the sides do not
    /// change.** Two prominent buttons were tried first and read as a choice to
    /// make on arrival, which is a decision in front of logging
    /// (docs/PHILOSOPHY.md). What keeps this secondary is a circle with no word
    /// on it against a pill six times its width.
    ///
    /// **A 50pt circle, and the 70pt slot is gone** (docs/TODO.md item 33). The
    /// slot had been measured for the `.bordered` square this used to be, and
    /// was kept so the pill's width would not move — which left a 30pt disc
    /// floating in the middle of 70pt of air beside a 50pt pill. Five
    /// alternatives were rendered and photographed and the user picked this one;
    /// the pill goes 292 to 312.
    @ViewBuilder
    private var logBar: some View {
        if !store.activeTrackers.isEmpty {
            HStack(spacing: 8) {
                // Unlike a card's small +, this opens the last-used group
                // rather than this row's.
                Button(action: logLastGroup) {
                    Label("Log", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        // Inside the label, because that is where a
                        // `.disabled` outside can still reach it.
                        .onAccentFill()
                }
                // `.accentPill`, not `.borderedProminent` with a tint. The
                // fill is the same and so are the metrics, measured either side
                // of the change; what a tint could not reach is the pressed
                // state, which iOS drew 1.08:1 against rest in dark mode and in
                // the opposite direction from every other accent fill on this
                // screen (docs/TODO.md item 26).
                .buttonStyle(.accentPill)
                .controlSize(.large)
                Button { loggingAgain = true } label: {
                    RepeatDisc(diameter: 50, glyph: 20, confirmed: isConfirming)
                }
                // `.accentFill` rather than `.plain`, so the disc reads the
                // press and recedes to `Color.accentFillPressed`.
                .buttonStyle(.accentFill)
                .accessibilityLabel("Log again")
                // On home rather than inside `RepeatView`: the sheet stops
                // updating the moment it is dismissed, so the one signal that
                // has to arrive cannot hang off a view being torn down.
                //
                // **The same buzz for a partial repeat**, deliberately (raised
                // in review). The honest wording is already on screen at the
                // same instant, in the undo bar directly above this: "Logged 1
                // of 2 again". A second haptic meaning "partly" would be a
                // vocabulary of two buzzes nobody is going to learn.
                .logHaptic(loggedAgain)
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
        // No `tracker:` — the sheet lands on the group's first field when none
        // is named, and resolves it from the store as it opens rather than from
        // a snapshot taken here.
        LogSheet.present(.init(group: group), using: $logging)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No trackers", systemImage: "number")
        } description: {
            Text("Add one to start counting whatever you like.")
        } actions: {
            NavigationLink(value: Route.settings) {
                Text("Add Tracker").onAccentFill()
            }
            .buttonStyle(.accentPill)
        }
    }

    /// The cards split into the same blocks settings draws: one block per log
    /// group, in the order the groups first appear.
    ///
    /// Blocks are `LogGroup`s rather than runs of adjacent trackers, so what is
    /// drawn as one block is exactly what one + opens. A group's trackers need
    /// not sit next to each other — `update` leaves a tracker's position alone
    /// when its group changes — and grouping by adjacency drew a group under two
    /// identical headings while the sheet behind either one held all of it.
    private var runs: [[Tracker]] {
        store.activeTrackerRuns
    }

    private var list: some View {
        List {
            if let notice = LoadNotice(origin: store.origin, saveError: store.saveError) {
                Section { NoticeRow(notice: notice) }
            }
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

            addTrackerRow
        }
        .listStyle(.insetGrouped)
        // Every loose tracker is its own section (see `runs`), so the gap
        // between sections is paid once per card rather than once per group —
        // with ten trackers the default spacing was costing more vertical room
        // than two whole cards.
        .listSectionSpacing(.compact)
    }

    /// A quiet way to make another tracker, at the end of the cards.
    ///
    /// **Inline and scrolling with the list, not pinned above it.** Home's
    /// bottom already holds the most frequent action in the app and the second
    /// most, and a third control down there competes with them for the same
    /// thumb (docs/PHILOSOPHY.md, "frequent actions live low").
    ///
    /// What keeps it out of the way is that it is quiet — **not the fold**,
    /// which it is nowhere near. Measured on an iPhone 17 (1206×2622) at the
    /// default type size: nine loose cards still leave the row fully visible
    /// above the Log bar, and it takes ten to push it off the screen. The commit
    /// that added it recorded "four or more and it is below the fold", and that
    /// does not reproduce.
    ///
    /// It opens the editor rather than pushing Settings, which is where the same
    /// button lives: a label that says "add tracker" and delivers a screen with
    /// an *Add Tracker* button on it is a promise kept a step late.
    private var addTrackerRow: some View {
        Section {
            Button {
                addingTracker = Tracker(name: "")
            } label: {
                Label("Add Tracker", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.row)
            // `rest: .clear` rather than a `listRowBackground` of its own:
            // `rowPress()` owns the row's background so that a press can fill
            // the whole cell, and this row is deliberately not a card.
            .rowPress(rest: Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 16))
        }
    }
}

/// A daily total, or the latest reading.
///
/// One line, not three. The stacked name-over-number card was 118pt tall and
/// four of them filled a phone, which made the home screen a thing you scroll
/// rather than a thing you read (docs/TODO.md item 11). At `.xxxLarge` and above
/// it goes back to stacking — see `DynamicTypeSize.stacksRows`.
private struct TrackerCard: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tracker: Tracker
    let open: () -> Void
    let log: () -> Void

    var body: some View {
        // Read once per pass and handed down. `total` and `latestEntry` both
        // scan the whole entry history and are wanted three times over between
        // the layout and the spoken label, on six to ten cards at once.
        let headline = headline
        let caption = caption
        return HStack(spacing: 8) {
            // Two buttons with disjoint frames rather than a NavigationLink
            // wrapping a button: a link would either swallow the + or leave its
            // chevron stranded in the middle of the card.
            Button(action: open) {
                summary(headline, caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    // On the label content rather than on the `Button`:
                    // applied outside, the button still read its children in
                    // layout order, which put "8 hours ago" before "78.4 kg"
                    // once the caption moved up beside the name.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        [tracker.name, headline.text, caption]
                            .compactMap { $0 }
                            .joined(separator: ", ")
                    )
            }
            // `.row`, not `.plain`: `.plain`'s whole press here was dimming
            // the text 25%, which is not a press anyone noticed (docs/TODO.md
            // item 28).
            .buttonStyle(.row)
            // Left on the `Button`, deliberately, though the label above had
            // to move inside. Moving this too was tried and reverted:
            // `logButton` below and HistoryView's repeat disc both label a
            // button from outside and are read correctly. The difference may be
            // the `children: .ignore` above turning this button into a
            // container, in which case the hint belongs inside after all —
            // **unverified**, since it needs VoiceOver rather than a reading of
            // the tree, and guessing costs the hint entirely.
            .accessibilityHint("Shows the history")
            logButton
        }
        .rowPress()
        // The row is as tall as the + and no taller. The default inset-grouped
        // row padding was adding 46pt of its own, which is most of a second row.
        .listRowInsets(.listRow)
    }

    /// One line normally, stacked once the text outgrows it.
    ///
    /// Past `stacksRows` a name and a number cannot share a row: the number is
    /// sized first, the name absorbs the entire shortfall, and at AX3 and up
    /// "Calories" rendered as a single clipped glyph.
    private func summary(_ headline: Headline, _ caption: String?) -> some View {
        // Two things changed shape when this moved into `StackingRow`, and are
        // inert rather than absent — written down because whatever makes them
        // matter will not look like a change to this card. The stacked branch
        // adds `frame(maxWidth: .infinity)`, which the card's own `VStack` never
        // had and the caller already does. And the `layoutPriority` below now
        // applies in *both* branches: a `List` row proposes its height freely,
        // so inside the `VStack` there is nothing for it to arbitrate.
        StackingRow {
            nameBlock(caption)
        } trailing: {
            headlineText(headline)
                // The number gets the width it needs and the name gives way:
                // the number has to be readable across a kitchen and a
                // truncated name still says which tracker it is. A floor on the
                // name was tried instead and reverted — `minWidth` reserves its
                // width whether the name needs it or not, so "Weight" kept an
                // 83pt blank gap and charged it to the number, which halved.
                //
                // Priority is the caller's: a History row lets its *time* take
                // the width instead, and one container cannot hold both
                // answers.
                .layoutPriority(1)
        }
    }

    private func nameBlock(_ caption: String?) -> some View {
        TrackerRowName(name: tracker.name, caption: caption)
    }

    /// `.title2`, the largest size that fits beside the 44pt + without making
    /// the row taller than the button already does.
    ///
    /// One line, and it shrinks rather than truncating — on *both* layouts. The
    /// scale factor used to live only on the one-line branch, which left the
    /// stacked branch, the one that exists because the text is already too big,
    /// clipping "1,234 kcal" to "1,23…" at AX5 on an iPhone SE.
    @ViewBuilder
    private func headlineText(_ headline: Headline) -> some View {
        Group {
            if let amount = headline.amount {
                // Counts to the new number instead of swapping to it. Item 15
                // rolled the digits with `.contentTransition(.numericText)`,
                // which shows you a *different* number rather than the addition:
                // 1,690 became 1,780 and you were left to work out that a 90 had
                // gone in.
                CountingNumber(value: amount) { tracker.format($0) }
            } else {
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
        // gains a digit and a separator part-way through, and takes that width
        // out of the name's truncation budget, so a name long enough to truncate
        // re-truncates mid-count. Raised in review and left: reserving the width
        // is the `minWidth` that `summary` tried and reverted.
        .monospacedDigit()
        // On the card rather than at the place that writes: logging again, an
        // undo, an edit and a deletion all change the same total by another
        // door and get this for free. Nothing waits on it — `log()` still
        // writes and dismisses in the same breath, and this counts behind the
        // sheet on its way out (docs/TODO.md item 15).
        //
        // 0.8s, where item 15 was 0.3s: at 0.3 a count is a flicker and reads
        // as the swap it replaced. An ease rather than a spring — a number that
        // bounces is congratulating you (docs/PHILOSOPHY.md "Quiet").
        //
        // Keyed on the amount rather than on the string it prints, so editing a
        // tracker's unit or decimals swaps rather than transitions, and the
        // midnight rollover still counts a daily total down to zero.
        //
        // `nil` under Reduce Motion: what the count buys — watching the addition
        // happen — is exactly the moving thing that setting turns off.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: headline.amount)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// The bottom Log button, scaled down: same fill, same meaning.
    ///
    /// It used to be a bare blue glyph — a different design language from the
    /// thing it is a smaller version of, and low enough contrast that people did
    /// not read it as a control at all. A tinted `.bordered` fill was tried
    /// instead, on the grounds that eight solid dots down one screen is loud,
    /// and rejected on the original complaint: a blue glyph on a pale blue disc
    /// is exactly that low contrast again.
    ///
    /// The 44pt frame is the tap target, and `contentShape` is what makes the
    /// frame rather than the 30pt fill the thing your thumb has to hit.
    private var logButton: some View {
        Button(action: log) {
            Image(systemName: "plus")
                // Fixed, not `.subheadline`: the disc and the 44pt target are
                // fixed too, and a text style scales without them. At AX3 the
                // glyph outgrew its circle and the + drew as a crosshair
                // straddling the edge.
                .font(.system(size: 15, weight: .bold))
                // The same dark-on-accent the Log pill uses: this glyph sits
                // on the identical fill six to ten times down the main screen,
                // so on the old teal it was the identical 1.86:1 (docs/TODO.md
                // item 13b).
                //
                // `.onAccentFill()` and not `Color.onAccent` written out: the
                // background below carries all three states since item 26, and a
                // foreground that names only the enabled one is half a control.
                // The first `.disabled` put on this button would have painted
                // black on `#636366` at 3.51:1 rather than the 5.99:1 the white
                // glyph measures there, and nothing would have said so.
                .onAccentFill()
                .frame(width: 30, height: 30)
                // `accentFilled`, not `.tint` and not `Color.accentColor`: the
                // environment tint is the ordinary label colour now, and
                // `Color.accentColor` is still the system blue — item 18's
                // catalog deliberately does not claim that magic name. The
                // modifier is what puts the pressed colour and the press's scale
                // on every accent fill at once.
                .accentFilled(.circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        // `.accentFill` rather than `.plain`: the disc draws its own pressed
        // colour instead of iOS's 75% composite of whatever is behind it.
        .buttonStyle(.accentFill)
        .accessibilityLabel("Log \(tracker.name)")
    }

    /// Both together because both come from the same linear scan of the entry
    /// history, and the count needs the number to know which way to go. `nil`
    /// where there is nothing to show, which prints an em dash.
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
/// `Animatable` on the view itself is the whole mechanism: SwiftUI interpolates
/// `animatableData` across whatever animation is in flight and calls `body` for
/// each frame, so there is no timer, no `TimelineView` and no state — nothing
/// runs when nothing is changing.
///
/// It formats per frame, deliberately: counting through numbers drawn by a
/// second, simpler rule is how the card would disagree with itself mid-count,
/// decimals and grouping included. Roughly fifty `FormatStyle` calls over the
/// animation, on the one card whose number changed.
private struct CountingNumber: View, Animatable {
    var value: Double
    /// `@Sendable`, and `nonisolated` below, because SwiftUI interpolates the
    /// value off the main actor: `Animatable` is not main-actor isolated and a
    /// `View` is, so under Swift 6 the conformance only compiles when the part
    /// the animator touches stands outside the isolation.
    let format: @Sendable (Double) -> String

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}

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
