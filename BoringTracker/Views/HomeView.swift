import SwiftUI

/// Your trackers as cards. That's the whole main screen.
struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(LogSheet.lastGroupKey) private var lastGroup = ""
    @State private var logging: LogSheet.Target?
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
                if !store.activeTrackers.isEmpty {
                    // Unlike a card's small +, this is the primary action: it
                    // opens the last-used group instead of this row's. It is
                    // centred so it sits inside either hand's thumb arc.
                    Button(action: logLastGroup) {
                        Label("Log", systemImage: "plus")
                            .frame(
                                maxWidth: horizontalSizeClass == .regular ? 440 : .infinity
                            )
                            // Dark on the teal, not the white iOS draws by
                            // default — see `Color.onAccent`. Inside the label,
                            // because that is where a `.disabled` outside can
                            // still reach it.
                            .onAccentFill()
                    }
                    .buttonStyle(.borderedProminent)
                    // The accent is named here rather than inherited: the
                    // environment tint is the ordinary label colour now, and
                    // teal is a fill (docs/TODO.md item 13c, `Color.accentFill`).
                    .tint(Color.accentFill)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    // The inset is reserved across the full width, so the bar
                    // has to span it. Backing only the constrained button left
                    // the list scrolling through untinted gutters either side
                    // of it on a regular-width screen.
                    .frame(maxWidth: .infinity)
                    .background(.bar)
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
            // be drawn dark on the teal like every other prominent button here.
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
    private func headlineText(_ headline: Headline) -> some View {
        Text(headline.text)
            .font(.title2.weight(.medium))
            .monospacedDigit()
            // The one piece of motion in the app, and the whole of item 15:
            // logging a number should show the number changing. Until now the
            // only acknowledgement of a log was the sheet closing, and the card
            // behind it already read as though it had always said that.
            //
            // `value:` gives the digits their direction, so a total rolls up
            // and an undo rolls back down.
            .contentTransition(.numericText(value: headline.amount ?? 0))
            // On the card rather than at the place that writes, which is what
            // keeps it honest in both directions. Nothing waits on it: `log()`
            // still writes and dismisses in the same breath, and this animates
            // behind the sheet on its way out. And it belongs to the number
            // rather than to the log sheet, so a repeat from History — which
            // changes the same total by another door — gets it for free, as
            // does an undo, an edit and a deletion.
            //
            // Brief, and an ease rather than a spring: a spring is a bounce,
            // and a number that bounces is congratulating you (docs/TODO.md
            // item 15, docs/PHILOSOPHY.md "Quiet").
            .animation(.easeOut(duration: 0.3), value: headline.text)
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
                // The same dark-on-teal the Log pill uses, for the same
                // measured reason: this glyph sits on the identical fill six to
                // ten times down the main screen, so it was the identical
                // 1.86:1. The two move together or the screen has two design
                // languages again (docs/TODO.md item 13b).
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
