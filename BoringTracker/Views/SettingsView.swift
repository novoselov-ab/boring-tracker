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
    @State private var orderingHeight: CGFloat = 0
    @State private var autoScrollDirection = 0

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                ForEach(runs, id: \.first?.id) { run in
                    Section {
                        ForEach(run) { tracker in
                            reorderableRow(tracker, scrollProxy: scrollProxy)
                                .id(tracker.id)
                                .onGeometryChange(for: CGRect.self) {
                                    $0.frame(in: .named("tracker-ordering"))
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
            }
            .coordinateSpace(name: "tracker-ordering")
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                orderingHeight = $0
            }
            .task(id: autoScrollDirection) {
                let direction = autoScrollDirection
                guard direction != 0 else { return }
                while !Task.isCancelled {
                    scrollOneStep(direction, using: scrollProxy)
                    do {
                        try await Task.sleep(for: .milliseconds(150))
                    } catch {
                        return
                    }
                }
            }
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

    private func reorderableRow(_ tracker: Tracker, scrollProxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            rowButton(tracker)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .highPriorityGesture(reorderGesture(for: tracker.id, scrollProxy: scrollProxy))
                .accessibilityLabel("Reorder \(tracker.name.isEmpty ? "Untitled" : tracker.name)")
                .accessibilityHint("Drag onto another tracker")
                .accessibilityActions {
                    if canMove(tracker.id, by: -1) {
                        Button("Move earlier") { move(tracker.id, by: -1) }
                    }
                    if canMove(tracker.id, by: 1) {
                        Button("Move later") { move(tracker.id, by: 1) }
                    }
                }
        }
        .swipeActions(edge: .trailing) {
            archiveButton(tracker)
        }
    }

    private func rowButton(_ tracker: Tracker) -> some View {
        Button {
            editing = tracker
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name.isEmpty ? "Untitled" : tracker.name)
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

    private func canMove(_ sourceID: UUID, by distance: Int) -> Bool {
        let ids = runs.flatMap { $0 }.map(\.id)
        guard let source = ids.firstIndex(of: sourceID) else { return false }
        return ids.indices.contains(source + distance)
    }

    private func move(_ sourceID: UUID, by distance: Int) {
        let ids = runs.flatMap { $0 }.map(\.id)
        guard let source = ids.firstIndex(of: sourceID),
              ids.indices.contains(source + distance) else { return }
        withAnimation {
            store.move(sourceID, onto: ids[source + distance])
        }
    }

    private func reorderGesture(for sourceID: UUID, scrollProxy: ScrollViewProxy) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("tracker-ordering"))
            .onChanged { value in
                autoScrollDirection = edgeDirection(at: value.location.y)
            }
            .onEnded { value in
                autoScrollDirection = 0
                let targetID = visibleRows
                    .min { abs($0.1 - value.location.y) < abs($1.1 - value.location.y) }?
                    .0
                guard let targetID else { return }
                withAnimation {
                    store.move(sourceID, onto: targetID)
                }
            }
    }

    private var visibleRows: [(UUID, CGFloat)] {
        runs.flatMap { $0 }.compactMap { tracker in
            guard let frame = rowFrames[tracker.id],
                  frame.maxY >= 0, frame.minY <= orderingHeight else { return nil }
            return (tracker.id, frame.midY)
        }
    }

    private func edgeDirection(at y: CGFloat) -> Int {
        guard orderingHeight > 0 else { return 0 }
        if y < 60 { return -1 }
        if y > orderingHeight - 60 { return 1 }
        return 0
    }

    private func scrollOneStep(_ direction: Int, using scrollProxy: ScrollViewProxy) {
        let ids = runs.flatMap { $0 }.map(\.id)
        let visible = visibleRows.sorted { $0.1 < $1.1 }
        if direction < 0, let first = visible.first?.0,
           let index = ids.firstIndex(of: first), index > ids.startIndex {
            scrollProxy.scrollTo(ids[index - 1], anchor: .top)
        } else if direction > 0, let last = visible.last?.0,
                  let index = ids.firstIndex(of: last), index < ids.index(before: ids.endIndex) {
            scrollProxy.scrollTo(ids[index + 1], anchor: .bottom)
        }
    }

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
