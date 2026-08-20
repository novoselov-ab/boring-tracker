import SwiftUI

/// Everything that isn't logging: making trackers, changing them, putting them
/// in order, and getting rid of them.
struct SettingsView: View {
    @Environment(Store.self) private var store
    @AppStorage(Appearance.key) private var appearance = Appearance.system
    @State private var editing: Tracker?
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var visibleBounds: CGRect = .zero

    private struct Drag: Equatable {
        var source: UUID
        var target: UUID?
    }

    /// `@GestureState` rather than `@State`: SwiftUI clears it when a drag is
    /// cancelled — the list rebuilt, the row torn down — and `onEnded` does not
    /// run in that case, so plain state would leave rows faded and tinted with
    /// nothing being dragged until the next completed drag.
    @GestureState private var drag: Drag?

    var body: some View {
        let carried = carriedByDrop
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
                            // Both must stay outside `.onGeometryChange` and
                            // outside `reorderableRow`: written under the reader
                            // they are silently dropped — the row keeps the
                            // platform's 74pt inset and the press scales with no
                            // background wash.
                            .listRowInsets(.listRow)
                            .rowPress()
                    }
                } header: {
                    if let group = run.first?.group, !group.isEmpty {
                        Text(group)
                    }
                }
            }

            if canReorder {
                Section {
                    EmptyView()
                } footer: {
                    Text("Drag a tracker's handle to reorder. Between sections, its whole group moves with it.")
                }
            }

            Section {
                Button("Add Tracker", systemImage: "plus") {
                    // No group by default: a group means "logged at the same
                    // time as these", and guessing one puts Steps in your meal
                    // sheet.
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

            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                // The segmented style drops the picker's own label, so without a
                // heading nothing on screen says what is being chosen.
                Text("Appearance")
            } footer: {
                Text("System follows the phone, including its own per-app setting. This is stored on this device only — it is not part of your data and does not export.")
            }

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

            Section {
                NavigationLink("About", destination: AboutView())
            }
        }
        // Both ends of the comparison a drop makes — every row's frame and the
        // finger's location — read `.global` and nothing else. A named coordinate
        // space declared on the `List` is not reachable from inside its rows:
        // each side falls back to a different default, which is how every drop
        // landed on a row nobody dropped anything on.
        //
        // The band is this frame as reported, with nothing added. Measured on an
        // iPhone 17 the proxy says `(0, 116, 402, 724)` with `safeAreaInsets` of
        // 116 and 34 — the frame is *already* the safe area, and adding
        // `insets.top` back on counted it twice and put the first row outside the
        // band.
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

    /// Bound to the store rather than to `@AppStorage`, because moving the day
    /// start has to re-derive the totals index and `today` in the same breath —
    /// see `Store.setDayStartHour`. A second writer here would change the number
    /// without changing any of the numbers that depend on it.
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
        .opacity(carried.contains(tracker.id) ? 0.4 : 1)
        // `Color.accentFill`, not `.tint` and not `Color.accentColor`: the
        // environment tint is the ordinary label colour here and
        // `Color.accentColor` is still the system blue — see `BoringTrackerApp`.
        // One style with a switched opacity rather than two: a fill at zero
        // opacity draws what `.clear` did, with no `AnyShapeStyle` box.
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

    /// `contentShape` is load-bearing: a `Button` hit-tests its label's drawn
    /// content unless given a shape, so without it the gap between the name and
    /// the chevron — most of the row's width — is dead.
    ///
    /// `spacing: 0` likewise: an `HStack` puts its spacing on *both* sides of a
    /// `Spacer`, which `StackingRow` measured at 24pt where 8 was meant.
    private func rowButton(_ tracker: Tracker) -> some View {
        Button {
            editing = tracker
        } label: {
            HStack(spacing: 0) {
                // `capped: false`: the caption says what kind of tracker this
                // is, not which one, so a truncated name is unreadable here in a
                // way home's card never is.
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

    /// The separator carries a non-breaking space in front of it, which is a
    /// wrap and not a typographic preference: at AX5 a caption takes two lines,
    /// and with an ordinary space "Daily total · kcal" broke as `Daily total` /
    /// `· kcal`, a line starting with a dot.
    ///
    /// "in Vices", not "Vices": a unit is free text, so an archived *Cigarettes*
    /// reading "Daily total · Vices" is a row saying its readings are counted in
    /// vices.
    private func editableSummary(of tracker: Tracker) -> String {
        var parts = [tracker.kind.label]
        if !tracker.unit.isEmpty { parts.append(tracker.unit) }
        if tracker.isArchived, !tracker.group.isEmpty { parts.append("in \(tracker.group)") }
        return parts.joined(separator: "\u{00A0}· ")
    }

    private func archiveButton(_ tracker: Tracker) -> some View {
        // Archiving is the reversible one, so it is the one a swipe does.
        // Deleting asks which of the two deletions you meant, and that question
        // needs more room than a swipe has — see `TrackerEditor`.
        Button(tracker.isArchived ? "Unarchive" : "Archive",
               systemImage: tracker.isArchived ? "tray.and.arrow.up" : "archivebox") {
            var updated = tracker
            updated.isArchived.toggle()
            store.update(updated)
        }
        .tint(tracker.isArchived ? .green : .orange)
    }

    /// Member and block moves are offered apart because a row's neighbour can be
    /// another tracker or another whole group, and "Move later" cannot honestly
    /// mean both: said together, moving a member later and then earlier lands
    /// somewhere neither step asked for.
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

    private func blockName(of tracker: Tracker) -> String {
        tracker.group.isEmpty ? name(of: tracker) : tracker.group
    }

    private func memberNeighbour(of sourceID: UUID, by distance: Int) -> UUID? {
        guard let run = runs.first(where: { $0.contains { $0.id == sourceID } }),
              let index = run.firstIndex(where: { $0.id == sourceID }),
              run.indices.contains(index + distance) else { return nil }
        return run[index + distance].id
    }

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
            // **Letting go anywhere commits, including outside the list, and
            // that is a decision rather than a missing check.** Do not "fix" it.
            // Requiring the finger inside would cost a drag released a few points
            // past an edge it cannot see — likeliest at the ends of the list,
            // which is where a long drag is going — and `row(nearest:)` is
            // defined at every y, so no drop is ever ambiguous enough to refuse.
            //
            // Checked on an iPhone 17, list running 116…840pt: releasing at 866
            // moved the block to the end, releasing at 54 put it on top. The
            // price — a drag abandoned by dragging away still moves something —
            // is said out loud in docs/PRODUCT.md.
            .onEnded { value in
                guard let targetID = row(nearest: value.location.y) else { return }
                apply(sourceID, onto: targetID)
            }
    }

    /// The rows a drop right now would carry, which is the same question
    /// `Store.move` answers: one tracker inside its run, the whole group across
    /// a boundary. Read once per body pass and handed to the rows rather than
    /// asked again by every row.
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
/// are not candidates — their frames are still recorded, and a drop belongs on
/// something the finger could see — and overlapping the band is enough.
///
/// Free of SwiftUI so it can be tested without a simulator. Settings has got this
/// answer wrong twice, in two different ways, and neither showed up in a
/// screenshot of the list at rest: once comparing two coordinate spaces that were
/// never the same, once shrinking the band by an already-applied safe-area inset.
/// Both silently rewrote the stored order and stamped it as a decision.
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
