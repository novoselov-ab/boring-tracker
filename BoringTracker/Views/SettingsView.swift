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

    var body: some View {
        List {
            Section {
                ForEach(store.activeTrackers) { tracker in
                    row(tracker)
                }
                .onMove {
                    store.move(store.activeTrackers, fromOffsets: $0, toOffset: $1)
                }
            } header: {
                Text("Trackers")
            } footer: {
                if !store.activeTrackers.isEmpty {
                    Text("Drag to reorder. Change a tracker's group by editing it.")
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

    private func row(_ tracker: Tracker) -> some View {
        Button {
            editing = tracker
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name.isEmpty ? "Untitled" : tracker.name)
                    if !tracker.group.isEmpty {
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
