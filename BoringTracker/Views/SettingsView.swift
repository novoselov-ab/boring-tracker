import SwiftUI

/// Everything that isn't logging: making trackers, changing them, putting them
/// in order, and getting rid of them.
///
/// The same blocks home draws, so every order chosen here is an order home can
/// honor. Settings is not the common path — nobody's day is improved by this
/// screen being clever — and the tap budget it has to respect is the one it
/// must not spend, not the one it lives on. The only subscreen is the tracker
/// editor, which is five fields and genuinely does not fit in a row.
struct SettingsView: View {
    @Environment(Store.self) private var store
    /// The same key the app root reads, so the switch and what it switches
    /// cannot come apart. UI state, in `UserDefaults` — see `Appearance`.
    @AppStorage(Appearance.key) private var appearance = Appearance.system
    @State private var editing: Tracker?
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var visibleBounds: CGRect = .zero
    /// A drag in flight: what is held, and what letting go would drop it on.
    private struct Drag: Equatable {
        var source: UUID
        var target: UUID?
    }

    /// One `@GestureState` rather than two pieces of `@State`, because SwiftUI
    /// puts it back on its own when a drag is cancelled — the list rebuilt, the
    /// row torn down — and `onEnded` does not run in that case. Held as plain
    /// state, a cancelled drag would leave rows faded and tinted with nothing
    /// being dragged, and only the next completed drag would clear it.
    @GestureState private var drag: Drag?

    var body: some View {
        let carried = carriedByDrop
        // Whether anything on this screen can be reordered at all, which is the
        // same question item 25b answers on History: the jump control is absent
        // when there is nowhere to jump to, and a handle on a list of one is a
        // grip on the only row there is — nothing to drag it past, nowhere to
        // drop it, and a footer explaining sections and groups to somebody who
        // has neither. Absent rather than disabled, for 25b's reason: a control
        // you can touch and cannot use is worse than one that is not there.
        //
        // The zero case was already right — the footer is gated on there being
        // an active tracker — so this is that same gate with the threshold it
        // should always have had.
        let canReorder = store.activeTrackers.count > 1
        return List {
            ForEach(runs, id: \.first?.id) { run in
                Section {
                    ForEach(run) { tracker in
                        reorderableRow(tracker, carried: carried, canReorder: canReorder)
                            .onGeometryChange(for: CGRect.self) {
                                $0.frame(in: .global)
                            } action: { frame in
                                rowFrames[tracker.id] = frame
                            }
                            // **Outside `.onGeometryChange`, and that is not a
                            // style choice** — written inside
                            // `reorderableRow`, under the reader, it is
                            // silently dropped and the row keeps the platform's
                            // 74pt. See `EdgeInsets.listRow`, which carries the
                            // probe that isolated it.
                            .listRowInsets(.listRow)
                            // Out here for exactly the same reason, and it cost
                            // the same hour a second time: `rowPress()` sets
                            // the row's background, and under the reader that
                            // is dropped as silently as the insets were. The
                            // press still scaled, so the row looked like it had
                            // one — 3,642 pixels of text moving and no wash
                            // (docs/TODO.md item 32).
                            .rowPress()
                    }
                } header: {
                    if let group = run.first?.group, !group.isEmpty {
                        Text(group)
                    }
                }
            }

            // **The drag, and only the drag** (docs/TODO.md item 37). Item 34
            // put the tap in this footer as well — "Tap a tracker to edit it,
            // including which group it is in" — in the idiom History and a
            // tracker's own screen use for the same gesture, and it was still
            // not obvious in use. A footer explains a screen; what nobody
            // believed was a fact about a *row*, and it is the row that says it
            // now: `rowButton` draws what tapping would edit, under the name.
            //
            // So the sentence is gone rather than kept alongside. Three
            // explanations of one gesture — a caption, a chevron and a
            // paragraph — is what item 34 already ruled out at two, and the one
            // that reaches a reader who has not scrolled to the bottom of the
            // list is the one on the row.
            //
            // What is left is the drag, which genuinely has nowhere else to be
            // said: a handle is not a word and the group rule behind it is two
            // sentences. So the gate is `canReorder` now rather than "there is
            // a tracker" — with one tracker there is no handle, and there is
            // nothing left for this footer to carry.
            if canReorder {
                Section {
                    EmptyView()
                } footer: {
                    Text("Drag a tracker's handle to reorder. Between sections, its whole group moves with it.")
                }
            }

            Section {
                Button("Add Tracker", systemImage: "plus") {
                    // No group by default. A group means "logged at the
                    // same time as these", which is a claim about the new
                    // tracker that nobody has made yet, and defaulting to
                    // whichever one happened to be first makes it silently.
                    // It costs nothing to say: the picker is right there, and
                    // once the log sheet is group-scoped (docs/TODO.md item
                    // 3) a wrong guess here puts Steps in your meal sheet.
                    editing = Tracker(name: "")
                }
                .formRowAccent()
            }

            if !store.archivedTrackers.isEmpty {
                Section {
                    ForEach(store.archivedTrackers) { tracker in
                        row(tracker)
                    }
                } header: {
                    Text("Archived")
                } footer: {
                    Text("Hidden from the home screen. Nothing logged against them is lost.")
                }
            }

            // Below the trackers and above the data actions: it is a
            // preference about this phone rather than a thing you own, so it
            // belongs with the app's own settings and not among the records.
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                // Three short words, and all three fit — so the choice is
                // visible without a tap, the way the tracker editor already
                // shows both kinds. `.tint(.primary)` does not spoil this the
                // way it spoils a `Toggle`: a segmented control's selection is
                // a background, not a fill drawn in the tint.
                .pickerStyle(.segmented)
            } header: {
                // The segmented style drops the picker's own label, so the
                // heading is what names the row. Without it the section is
                // three words and a paragraph about "System", and nothing
                // saying what is being chosen.
                Text("Appearance")
            } footer: {
                Text("System follows the phone, including its own per-app setting. This is stored on this device only — it is not part of your data and does not export.")
            }

            // A menu picker rather than a segmented one: twenty-four options
            // are not three, and this is a thing you set once.
            Section {
                Picker("Day starts at", selection: dayStart) {
                    ForEach(DayStart.hours, id: \.self) { hour in
                        Text(DayStart.label(hour, calendar: store.calendar)).tag(hour)
                    }
                }
            } footer: {
                Text("When a daily total starts again. Move it later if your day ends after midnight — a 2am snack then counts towards the day you have been awake for. Nothing is rewritten: your entries keep the time they were logged at, and putting this back gives you exactly the totals you had.")
            }

            DataTransferView()

            // Last, and a pushed screen rather than rows here: the version and
            // the promises are read once, and the screen that arranges trackers
            // should not spend rows on them.
            Section {
                NavigationLink("About", destination: AboutView())
            }
        }
        // Both ends of the comparison a drop makes — every row's frame and the
        // finger's location — are read in `.global`, and nothing else. A named
        // coordinate space declared on the `List` is not reachable from inside
        // its rows: each side silently falls back to a different default, which
        // is how every drop landed on a row nobody dropped anything on.
        //
        // The band a drop may land in is this frame as reported, with nothing
        // added to it. Measured on an iPhone 17: the proxy says
        // `(0, 116, 402, 724)` with `safeAreaInsets` of 116 and 34, so the
        // frame is *already* the safe area and the insets describe what has
        // been taken off it. Adding `insets.top` back on counted it twice, put
        // the band at 232...806, and left the first row — 166 to 210, the
        // handle's own 44pt box — outside it, so letting go squarely on that
        // row dropped the tracker below it instead.
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: {
            visibleBounds = $0
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { tracker in
            TrackerEditor(tracker: tracker)
        }
    }

    // MARK: - Rows

    /// Bound to the store rather than to `@AppStorage`, because moving the day
    /// start has to re-derive the totals index and `today` in the same breath —
    /// see `Store.setDayStartHour`. The store owns the key; a second writer
    /// here would change the number without changing any of the numbers that
    /// depend on it.
    private var dayStart: Binding<Int> {
        Binding(get: { store.dayStartHour }, set: { store.setDayStartHour($0) })
    }

    private var runs: [[Tracker]] {
        store.activeTrackerRuns
    }

    private func row(_ tracker: Tracker) -> some View {
        rowButton(tracker)
            .rowPress()
            .swipeActions(edge: .trailing) {
                archiveButton(tracker)
            }
            .listRowInsets(.listRow)
    }

    /// The handle is drawn only where a drag could do something — see
    /// `canReorder` in `body`. The VoiceOver actions it carries go with it and
    /// lose nothing: `reorderActions(for:)` offers a move only where there is a
    /// neighbour to move past, so on the single-tracker list it was already
    /// empty, and a handle labelled "Reorder Coffees" with no actions under it
    /// is the same dead control by voice that it is by finger.
    private func reorderableRow(
        _ tracker: Tracker, carried: Set<UUID>, canReorder: Bool
    ) -> some View {
        HStack(spacing: 12) {
            rowButton(tracker)
            if canReorder {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .highPriorityGesture(reorderGesture(for: tracker.id))
                    .accessibilityLabel("Reorder \(name(of: tracker))")
                    .accessibilityHint("Drag onto another tracker")
                    .accessibilityActions {
                        reorderActions(for: tracker)
                    }
            }
        }
        // What a drop would do, while the finger is still down: the rows that
        // would move fade, and the row being dropped onto is tinted. Without
        // it the gesture is invisible — you find out where a tracker landed
        // only after letting go, which is how a drop target that resolved to
        // the wrong row survived a hand-run reproduction.
        .opacity(carried.contains(tracker.id) ? 0.4 : 1)
        // `Color.accentFill`, not `.tint` and not `Color.accentColor`: the
        // environment tint is the ordinary label colour now (docs/TODO.md item
        // 13c), and `Color.accentColor` is still the system blue — the catalog
        // added by item 18 names its colour set `AccentFill` precisely so that
        // it is not the app's global accent. A wash behind a row is a fill,
        // which is what the accent mostly is; nothing is written in it, and the
        // label on top is the ordinary one at 0.18 opacity of the accent. The
        // two places the accent *is* written with name themselves —
        // `navBarAccent()` and `formRowAccent()`, the latter one screen up in
        // this same file.
        //
        // One style with a switched opacity rather than a choice between two:
        // a fill at zero opacity draws exactly what `.clear` did, and no
        // `AnyShapeStyle` box is needed to give the branch one type.
        .background(
            Color.accentFill.opacity(drag?.target == tracker.id && !carried.isEmpty ? 0.18 : 0),
            in: .rect(cornerRadius: 8)
        )
        .swipeActions(edge: .trailing) {
            archiveButton(tracker)
        }
    }

    private func name(of tracker: Tracker) -> String {
        tracker.name.isEmpty ? "Untitled" : tracker.name
    }

    /// The whole row, and nothing less (docs/TODO.md item 28).
    ///
    /// **It used to respond on the name and on the chevron and nowhere in
    /// between.** A `Button` hit-tests its label's drawn content unless it is
    /// given a shape, and this label was two pieces of drawn content with a
    /// `Spacer` between them — so the gap in the middle of every tracker row,
    /// which is most of its width, was dead. A row tappable in two narrow
    /// places is worse than one that is plainly not tappable: a miss teaches
    /// you the tap failed rather than that you aimed wrong. `contentShape` is
    /// what fixes it. The height is `RowButtonStyle`'s: every row wearing
    /// `.row` is at least 44pt, which is what stops the target being one line
    /// of `.subheadline` tall on the rows with no drag handle beside them.
    ///
    /// `TrackerRowName` rather than this row's own fonts, and `spacing: 0` on
    /// the `HStack` rather than the default — an `HStack` puts its spacing on
    /// *both* sides of a `Spacer`, which `StackingRow` measured at 24pt where 8
    /// was meant.
    ///
    /// **The caption is what says the row can be edited** (docs/TODO.md item
    /// 37). See `editableSummary(of:)` for what it holds and why it is a line
    /// under the name rather than a value beside the chevron.
    private func rowButton(_ tracker: Tracker) -> some View {
        Button {
            editing = tracker
        } label: {
            HStack(spacing: 0) {
                // `capped: false`: the name is the whole of what identifies
                // this row — the caption under it says what kind of tracker it
                // is, not which one — so a truncated one is unreadable in a way
                // home's card never is. It wrapped before item 28 and it wraps
                // now.
                TrackerRowName(
                    name: name(of: tracker),
                    caption: editableSummary(of: tracker),
                    capped: false
                )
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.row)
    }

    /// What tapping this row would edit, under the name (docs/TODO.md item 37).
    ///
    /// **A row that shows its own settings is a row you tap to change them**,
    /// which is the thing item 34's footer said and nobody read. The chevron
    /// stays — it is iOS's disclosure indicator and it was never wrong, it was
    /// alone — and this is what sits beside it. The two together are the shape
    /// every drill-in row in iOS Settings has: what it is, what it is set to,
    /// and a `>`.
    ///
    /// **Under the name rather than beside the chevron**, which was the other
    /// candidate and is the one this screen cannot afford. A trailing value
    /// competes with the name for one line's width, and settings is the screen
    /// where a name has least of it — 44pt of that row is a drag handle, and
    /// `capped: false` means the name wraps rather than truncating, so
    /// "Calories burned exercising" would have gone to two lines to make room
    /// for "Daily total · kcal". A caption costs no width at all and no height
    /// either: a `.subheadline` over a `.caption2` is about 31pt against the
    /// 44pt `RowButtonStyle` already floors the row at, so the screen is the
    /// same length it was. Home's card has drawn its trackers this way since
    /// item 11 and settings has drawn them in `TrackerRowName` since item 28 —
    /// this fills the caption slot that was already there.
    ///
    /// The kind and the unit are two of the five things the editor edits, and
    /// the two that say what the row *is*. The group is the third and appears
    /// only on an archived row, which has no section heading over it to say so
    /// — that was this method's whole job before item 37, and it keeps it.
    /// Decimals and the name itself are visible in what the app already draws.
    ///
    /// **The separator carries a non-breaking space in front of it**, which is
    /// a wrap and not a typographic preference: at AX5 a caption takes two
    /// lines, and with an ordinary space "Daily total · kcal" broke as `Daily
    /// total` / `· kcal` — a line starting with a dot. Bound to the word before
    /// it, the same caption breaks as `Daily total ·` / `kcal`. Photographed
    /// both ways at AX5 on an iPhone 17 Pro; the trailing dot reads as the
    /// continuation it is.
    ///
    /// **"in Vices", not "Vices"**, and that word is the whole difference
    /// between a group and a unit. A unit is free text — anything you type — so
    /// an archived *Cigarettes* reading "Daily total · Vices" is a row saying
    /// its readings are counted in vices. It was unambiguous while the group
    /// stood alone on this line, and putting the kind in front of it is what
    /// took that away.
    /// Never `nil`: every tracker has a kind, so every row has something to
    /// say here. `archivedGroup(of:)`, which this replaced, was absent on most
    /// rows and optional for that reason.
    private func editableSummary(of tracker: Tracker) -> String {
        var parts = [tracker.kind.label]
        if !tracker.unit.isEmpty { parts.append(tracker.unit) }
        if tracker.isArchived, !tracker.group.isEmpty { parts.append("in \(tracker.group)") }
        return parts.joined(separator: "\u{00A0}· ")
    }

    private func archiveButton(_ tracker: Tracker) -> some View {
        // Archiving is the reversible one, so it is the one a swipe does.
        // Deleting asks which of the two deletions you meant, and that
        // question needs more room than a swipe has — see `TrackerEditor`.
        Button(tracker.isArchived ? "Unarchive" : "Archive",
               systemImage: tracker.isArchived ? "tray.and.arrow.up" : "archivebox") {
            var updated = tracker
            updated.isArchived.toggle()
            store.update(updated)
        }
        .tint(tracker.isArchived ? .green : .orange)
    }

    // MARK: - Reordering

    /// Two actions rather than one, because one row's neighbour can be another
    /// tracker or another whole group and "Move later" cannot honestly mean
    /// both. Said apart, each is its own inverse; said together, moving a
    /// member later and then earlier lands somewhere neither step asked for.
    @ViewBuilder
    private func reorderActions(for tracker: Tracker) -> some View {
        if let neighbour = memberNeighbour(of: tracker.id, by: -1) {
            Button("Move earlier") { apply(tracker.id, onto: neighbour) }
        }
        if let neighbour = memberNeighbour(of: tracker.id, by: 1) {
            Button("Move later") { apply(tracker.id, onto: neighbour) }
        }
        if let neighbour = runNeighbour(of: tracker.id, by: -1) {
            Button("Move \(blockName(of: tracker)) earlier") { apply(tracker.id, onto: neighbour) }
        }
        if let neighbour = runNeighbour(of: tracker.id, by: 1) {
            Button("Move \(blockName(of: tracker)) later") { apply(tracker.id, onto: neighbour) }
        }
    }

    /// What moves when this row crosses a run boundary: the group by name, or
    /// a loose tracker, which is a block of one and travels as itself.
    private func blockName(of tracker: Tracker) -> String {
        tracker.group.isEmpty ? name(of: tracker) : tracker.group
    }

    /// The tracker one place away inside the same run, if there is one.
    private func memberNeighbour(of sourceID: UUID, by distance: Int) -> UUID? {
        guard let run = runs.first(where: { $0.contains { $0.id == sourceID } }),
              let index = run.firstIndex(where: { $0.id == sourceID }),
              run.indices.contains(index + distance) else { return nil }
        return run[index + distance].id
    }

    /// Any tracker in the run one place away, which is what a drop needs to
    /// name in order to move this whole block past it.
    private func runNeighbour(of sourceID: UUID, by distance: Int) -> UUID? {
        guard let index = runs.firstIndex(where: { $0.contains { $0.id == sourceID } }),
              runs.indices.contains(index + distance) else { return nil }
        return runs[index + distance].first?.id
    }

    private func apply(_ sourceID: UUID, onto targetID: UUID) {
        withAnimation {
            store.move(sourceID, onto: targetID)
        }
    }

    private func reorderGesture(for sourceID: UUID) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($drag) { value, drag, _ in
                // Only when the answer changes. Every write here rebuilds the
                // list, and a finger reports a new position far more often
                // than it crosses from one row to the next.
                let next = Drag(source: sourceID, target: row(nearest: value.location.y))
                if drag != next { drag = next }
            }
            // Letting go anywhere commits, including outside the list, and that
            // is a decision rather than a missing check.
            //
            // `row(nearest:)` picks the closest row that is *on screen*; it
            // never asks whether the finger is, and nothing needs it to. The
            // rule is defined at every y: any point above the list resolves to
            // the topmost visible row and any point below it to the last, so
            // there is nowhere a drop becomes ambiguous and has to be refused.
            //
            // What the check would buy is **not** reachability, and an earlier
            // version of this comment said it was — that the first row sits
            // half under the navigation bar, so reaching it means dragging past
            // the top edge. It does not and it doesn't. Measured from the
            // frames this code actually reads, printed out of
            // `onGeometryChange` by a temporary `NSLog`: the list reports
            // **(0, 116, 402, 724)** and the first row **160.3…204.3**, 44pt
            // clear of the band's top, so a wide span at the top of the list
            // picks it with the finger still inside. Re-run on the new
            // geometry: releasing at 150 moved the dragged block onto the first
            // row, from inside the list, and the store shows it there.
            //
            // Re-measured for item 28, which cut a row from 74pt to 52. The
            // reading before it was 166…210 on an iPhone 17, 50pt clear; the
            // row is now 6pt *closer* to the band's top, at 44.3pt of
            // clearance, because a shorter row starts higher inside the same
            // list. Less room, not more — the conclusion survives it, and the
            // list's own frame did not move.
            //
            // What it would cost is a drag released a few points past an edge
            // the finger cannot see — likeliest at the ends of the list, which
            // is where a long drag is going. So the tolerance is the point.
            //
            // Checked on an iPhone 17 rather than reasoned about: with the list
            // running 116…840pt, releasing at 866 — below it, over the home
            // indicator — moved the dragged block to the end and restamped
            // every row's `orderModified`, and releasing at 54, inside the
            // navigation bar, put the dragged tracker on top. Both commit.
            //
            // The price is that a drag abandoned by dragging away still moves
            // something. It is recoverable by dragging it back, it is visible
            // while the finger is down — the carried rows fade and the target
            // tints — and it is on a screen nobody's day runs through. Said out
            // loud in docs/PRODUCT.md, under Screens, because the next person to
            // meet it will otherwise read it as a bug.
            .onEnded { value in
                guard let targetID = row(nearest: value.location.y) else { return }
                apply(sourceID, onto: targetID)
            }
    }

    /// The rows a drop right now would carry, which is the same question
    /// `Store.move` answers: one tracker inside its run, the whole group
    /// across a boundary. Empty when nothing is being dragged, and empty over
    /// the dragged row itself, where letting go moves nothing.
    ///
    /// Read once per body pass and handed to the rows, rather than asked again
    /// by every row: it is the same answer for all of them.
    private var carriedByDrop: Set<UUID> {
        guard let drag, let target = drag.target, target != drag.source else { return [] }
        return Set(store.trackersCarried(moving: drag.source, onto: target))
    }

    private func row(nearest y: CGFloat) -> UUID? {
        dropTarget(at: y,
                   rows: runs.flatMap { $0 }.compactMap { tracker in
                       rowFrames[tracker.id].map { (tracker.id, $0) }
                   },
                   visible: visibleBounds)
    }
}

/// The visible row whose middle is closest to `y`. Rows scrolled out of sight
/// are not candidates: their frames are still recorded, and a drop belongs on
/// something the finger could see. Overlapping the band is enough — a row
/// scrolled half out of it is still half on screen, and a drop aimed at the
/// half you can see should land on it rather than on its neighbour.
///
/// That is about a *scrolled* list. It used to be justified by the first row
/// sitting half under the navigation bar, and that is measurably untrue — at
/// rest the band is 116…840 and the first row is 160.3…204.3, wholly inside it.
/// See the release comment in `reorderGesture(for:)`, which carries both that
/// reading and the pre-item-28 one it replaced.
///
/// Pulled out of the view and free of SwiftUI so it can be tested without a
/// simulator. Settings has now got this answer wrong twice, in two different
/// ways, and neither showed up in a screenshot of the list at rest: the first
/// compared two coordinate spaces that were never the same one, the second
/// shrank the band by a safe-area inset that had already been applied and made
/// the first row impossible to drop on. Both silently rewrote the stored order
/// and stamped it as a decision (docs/TECH.md, "Mergeable by design"), which is
/// the kind of wrong this app cannot afford to find out about by eye.
///
/// Rows are passed in the order they are drawn, so equidistant rows resolve to
/// the higher one rather than to whatever the layout happened to hand over.
func dropTarget(at y: CGFloat, rows: [(id: UUID, frame: CGRect)], visible: CGRect) -> UUID? {
    rows.lazy
        .filter { $0.frame.maxY >= visible.minY && $0.frame.minY <= visible.maxY }
        .min { abs($0.frame.midY - y) < abs($1.frame.midY - y) }?
        .id
}

#Preview {
    let store = Store(
        document: StoreDocument(trackers: Tracker.starterSet),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-settings"))
    )
    return NavigationStack {
        SettingsView().environment(store)
    }
}
