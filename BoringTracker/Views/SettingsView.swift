import SwiftUI

/// Everything that isn't logging: making trackers, changing them, putting them
/// in order, and getting rid of them.
///
/// One plain list, on purpose. Settings is not the common path — nobody's day
/// is improved by this screen being clever — and the tap budget it has to
/// respect is the one it must not spend, not the one it lives on. The only
/// subscreen is the tracker editor, which is five fields and genuinely does not
/// fit in a row.
struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var editing: Tracker?

    /// Headings are rows rather than real `Section`s so that one ordinary drag
    /// does both jobs the product asks of it: moving a tracker within its
    /// section, and moving it *between* sections by dropping it under another
    /// heading. SwiftUI cannot drag across real sections without hand-rolled
    /// drop targets, and a bespoke gesture on a settings screen would be a
    /// worse trade than a list that is one flat run of rows.
    private enum Row: Identifiable, Hashable {
        case heading(String)
        case tracker(Tracker)

        var id: String {
            switch self {
            case .heading(let name): "heading:\(name)"
            case .tracker(let tracker): "tracker:\(tracker.id)"
            }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(rows) { item in
                    switch item {
                    case .heading(let name): heading(name)
                    case .tracker(let tracker): row(tracker)
                    }
                }
                .onMove(perform: move)
            } header: {
                Text("Trackers")
            } footer: {
                if !store.activeTrackers.isEmpty {
                    Text("Drag to reorder. Dropping a tracker under another "
                        + "heading is what moves it to that section.")
                }
            }

            Section {
                Button("Add Tracker", systemImage: "plus") {
                    // No section by default. A section means "logged at the
                    // same time as these", which is a claim about the new
                    // tracker that nobody has made yet, and defaulting to
                    // whichever one happened to be first makes it silently.
                    // It costs nothing to say: the picker is right there, and
                    // once the log sheet is section-scoped (docs/TODO.md item
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Rows drag on a long press without it. This is only for people who
            // expect an Edit button to be there; it is never the only way.
            ToolbarItem(placement: .primaryAction) {
                if store.activeTrackers.count > 1 { EditButton() }
            }
        }
        .sheet(item: $editing) { tracker in
            TrackerEditor(tracker: tracker)
        }
    }

    // MARK: - Rows

    private func heading(_ name: String) -> some View {
        Text(name.isEmpty ? "No section" : name)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .listRowSeparator(.hidden)
            // A heading is a landmark to drop things under, so it has to stay
            // where it is. Dragging one would mean dragging a whole section,
            // which is a second gesture nobody asked for.
            .moveDisabled(true)
    }

    private func row(_ tracker: Tracker) -> some View {
        Button {
            editing = tracker
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name.isEmpty ? "Untitled" : tracker.name)
                    Text(caption(tracker))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
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
    }

    /// The two things a name doesn't tell you: what it counts, and what it gets
    /// logged alongside.
    private func caption(_ tracker: Tracker) -> String {
        let kind = switch tracker.kind {
        case .dailyTotal: "Daily total"
        case .measurement: "Measurement"
        }
        return tracker.unit.isEmpty ? kind : "\(kind) · \(tracker.unit)"
    }

    // MARK: - Order and sections

    private var rows: [Row] {
        let trackers = store.activeTrackers
        var result: [Row] = []
        for section in sectionOrder(of: trackers) {
            result.append(.heading(section))
            result.append(contentsOf: trackers.lazy.filter { $0.section == section }.map(Row.tracker))
        }
        return result
    }

    /// Sections in the order their first tracker appears, with the unsectioned
    /// ones gathered at the end. Nothing is stored: a section is a string on a
    /// tracker, so the headings are computed from the trackers every time.
    private func sectionOrder(of trackers: [Tracker]) -> [String] {
        var seen = Set<String>()
        var named: [String] = []
        var anyUnsectioned = false
        for tracker in trackers {
            if tracker.section.isEmpty {
                anyUnsectioned = true
            } else if seen.insert(tracker.section).inserted {
                named.append(tracker.section)
            }
        }
        return anyUnsectioned ? named + [""] : named
    }

    /// Reads the new order back off the list: each tracker belongs to the last
    /// heading above it. That single rule covers both kinds of drag, so there
    /// is no separate "changed section" case to get wrong.
    private func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var moved = rows
        moved.move(fromOffsets: offsets, toOffset: destination)

        // Anything dropped above the very first heading joins that first
        // section, rather than becoming unsectioned and jumping to the bottom
        // of the screen — which is never what the drag meant.
        var current = moved.compactMap { row -> String? in
            if case .heading(let name) = row { name } else { nil }
        }.first ?? ""

        var ordered: [Tracker] = []
        for row in moved {
            switch row {
            case .heading(let name):
                current = name
            case .tracker(var tracker):
                tracker.section = current
                ordered.append(tracker)
            }
        }
        store.reorder(ordered)
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
