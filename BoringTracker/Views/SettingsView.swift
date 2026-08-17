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
        return List {
            ForEach(runs, id: \.first?.id) { run in
                Section {
                    ForEach(run) { tracker in
                        reorderableRow(tracker, carried: carried)
                            .onGeometryChange(for: CGRect.self) {
                                $0.frame(in: .global)
                            } action: { frame in
                                rowFrames[tracker.id] = frame
                            }
                    }
                } header: {
                    if let group = run.first?.group, !group.isEmpty {
                        Text(group)
                    }
                }
            }

            if !store.activeTrackers.isEmpty {
                Section {
                    EmptyView()
                } footer: {
                    Text("Drag a tracker's handle to reorder. Between sections, its whole group moves with it. Change membership by editing a tracker.")
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

            DataTransferView()
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

    private var runs: [[Tracker]] {
        store.activeTrackerRuns
    }

    private func row(_ tracker: Tracker) -> some View {
        rowButton(tracker)
            .swipeActions(edge: .trailing) {
                archiveButton(tracker)
            }
    }

    private func reorderableRow(_ tracker: Tracker, carried: Set<UUID>) -> some View {
        HStack(spacing: 12) {
            rowButton(tracker)
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
        // What a drop would do, while the finger is still down: the rows that
        // would move fade, and the row being dropped onto is tinted. Without
        // it the gesture is invisible — you find out where a tracker landed
        // only after letting go, which is how a drop target that resolved to
        // the wrong row survived a hand-run reproduction.
        .opacity(carried.contains(tracker.id) ? 0.4 : 1)
        // `Color.accentFill`, not `.tint` and not `Color.accentColor`: the
        // environment tint is the ordinary label colour now (docs/TODO.md item
        // 13c) and that other name still resolves a catalog that does not
        // exist. A wash behind a row is a fill, which is the one thing the
        // accent is still allowed to be — nothing is written in it, and the
        // label on top is the ordinary one at 0.18 opacity of teal.
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

    private func rowButton(_ tracker: Tracker) -> some View {
        Button {
            editing = tracker
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name(of: tracker))
                    // Only in the archived list, which has no group headings of
                    // its own. Which group a tracker rejoins when it comes back
                    // is the one thing this row would otherwise not say.
                    if tracker.isArchived, !tracker.group.isEmpty {
                        Text(tracker.group)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
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
/// something the finger could see. Overlapping the band is enough — a row half
/// under the navigation bar is half on screen, and dragging to the top edge to
/// reach the first row is exactly where a finger goes.
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
