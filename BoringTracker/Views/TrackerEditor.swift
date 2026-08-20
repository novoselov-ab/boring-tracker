import SwiftUI

/// Making a tracker, or changing one. The five fields a tracker has, and the
/// two ways of getting rid of it.
///
/// Whether this is a new tracker is asked of the store rather than passed in:
/// a tracker the store has never seen is one being created. That removes a flag
/// that could disagree with reality.
struct TrackerEditor: View {
    let tracker: Tracker

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Tracker?
    @State private var group: GroupChoice = .none
    @State private var typedGroup = ""
    @State private var confirming: Deletion?
    @FocusState private var nameFocused: Bool

    /// A group is a string, so "pick one" and "type one" are the same field
    /// wearing two hats. Keeping them apart in the picker is what stops a
    /// mistyped `Foood` from quietly forking a group.
    private enum GroupChoice: Hashable {
        case none
        case existing(String)
        case new
    }

    var body: some View {
        NavigationStack {
            Form {
                if let binding = draftBinding {
                    fields(binding)
                    if !isNew { deletion }
                }
            }
            .navigationTitle(isNew ? "New Tracker" : "Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.navBarAccent()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave).navBarAccent()
                }
            }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func fields(_ draft: Binding<Tracker>) -> some View {
        Section {
            TextField("Name", text: draft.name)
                .focused($nameFocused)
            TextField("Unit", text: draft.unit)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } footer: {
            Text("Calories in kcal, protein in g, weight in kg. A unit is optional.")
        }

        Section {
            Picker("Kind", selection: draft.kind) {
                // `Tracker.Kind.label`, not literals: a settings row says the
                // same two words underneath a tracker's name.
                ForEach(Tracker.Kind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(draft.wrappedValue.kind == .dailyTotal
                 ? "Entries add up over the day and start again at \(resetsAt)."
                 : "Each entry is a reading on its own. Nothing resets.")
        }

        Section {
            Picker("Decimals", selection: draft.decimals) {
                ForEach(0...3, id: \.self) { places in
                    Text(places.formatted()).tag(places)
                }
            }
        } footer: {
            Text("How the number is shown: \(preview(draft.wrappedValue)).")
        }

        Section {
            Picker("Group", selection: $group) {
                Text("None").tag(GroupChoice.none)
                ForEach(offeredGroups, id: \.self) { name in
                    Text(name).tag(GroupChoice.existing(name))
                }
                Text("New Group…").tag(GroupChoice.new)
            }
            if group == .new {
                TextField("Group name", text: $typedGroup)
            }
        } footer: {
            Text("Trackers in a group are logged together, in one sheet — "
                + "calories and protein come from the same meal.")
        }
    }

    /// **Not the word "midnight".** It was hard-coded here, and the day start
    /// became settable — so the one screen that explains what a daily total *is*
    /// went on promising a boundary the app had stopped using.
    private var resetsAt: String {
        store.dayStartHour == DayStart.midnight
            ? "midnight"
            : DayStart.label(store.dayStartHour, calendar: store.calendar)
    }

    /// The one place deleting a tracker is offered, because it is the only one
    /// with room to say which is which. The distinction is the whole point:
    /// one throws away the tracker, the other throws away everything you ever
    /// logged with it.
    @ViewBuilder
    private var deletion: some View {
        let count = store.entries(for: tracker.id).count
        Section {
            if count == 0 {
                // Nothing to weigh up: no history to keep or lose, and the four
                // fields above are a few seconds to type again. A confirmation
                // here would be ceremony, not protection.
                Button("Delete Tracker", systemImage: "trash", role: .destructive) {
                    store.delete(tracker)
                    dismiss()
                }
            } else {
                Button("Delete Tracker, Keep History",
                       systemImage: "trash", role: .destructive) {
                    confirming = .keepingHistory
                }
                Button("Delete Tracker and \(count.formatted()) \(count == 1 ? "Entry" : "Entries")",
                       systemImage: "trash.fill", role: .destructive) {
                    confirming = .withHistory
                }
            }
        } footer: {
            if count == 0 {
                Text("Nothing has ever been logged against this tracker.")
            } else {
                Text("Keeping the history leaves the \(count.formatted()) entries in the file, "
                    + "so an export still has them and a later import can put them back. "
                    + "Deleting the history removes them for good.")
            }
        }
        // Both are asked about, because neither can be undone: there is no undo
        // for a tracker the way there is for an entry, and a new one made with
        // the same name is a different tracker with a new id, which the old
        // entries do not belong to. The two dialogs say plainly what survives,
        // which is the part the labels alone cannot carry.
        .confirmationDialog(
            confirming.map { $0.title(name: displayName, count: count) } ?? "",
            isPresented: Binding(get: { confirming != nil },
                                 set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { choice in
            Button(choice.confirmation, role: .destructive) {
                switch choice {
                case .keepingHistory: store.delete(tracker)
                case .withHistory: store.deleteWithHistory(tracker)
                }
                dismiss()
            }
        } message: { choice in
            Text(choice.consequence(count: count))
        }
    }

    /// Which of the two deletions is being confirmed. One type rather than two
    /// flags, so the pair cannot both be true and the wording cannot drift out
    /// of step with the button that opened it.
    private enum Deletion: Identifiable {
        case keepingHistory
        case withHistory

        var id: Self { self }

        var confirmation: String {
            switch self {
            case .keepingHistory: "Delete Tracker"
            case .withHistory: "Delete Everything"
            }
        }

        func title(name: String, count: Int) -> String {
            switch self {
            case .keepingHistory: "Delete \(name)?"
            case .withHistory: "Delete \(name) and its \(count.formatted()) entries?"
            }
        }

        func consequence(count: Int) -> String {
            let entries = "\(count.formatted()) \(count == 1 ? "entry" : "entries")"
            switch self {
            case .keepingHistory:
                return "The \(entries) stay in your data and in any export, but nothing in "
                    + "the app will show them once the tracker is gone. This cannot be undone."
            case .withHistory:
                return "The \(entries) are removed for good. This cannot be undone."
            }
        }
    }

    /// Edits go into a copy, so backing out with Cancel really does change
    /// nothing. Optional only because it is filled in `onAppear`.
    private var draftBinding: Binding<Tracker>? {
        guard draft != nil else { return nil }
        return Binding(get: { draft ?? tracker }, set: { draft = $0 })
    }

    private var isNew: Bool { store.tracker(tracker.id) == nil }

    private var displayName: String {
        let trimmed = (draft ?? tracker).name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "this tracker" : trimmed
    }

    /// Every group that exists, plus this tracker's own — which is not in the
    /// store's list yet if the tracker is being created.
    private var offeredGroups: [String] {
        var names = store.groups
        let mine = tracker.group
        if !mine.isEmpty, !names.contains(mine) { names.append(mine) }
        return names
    }

    private var resolvedGroup: String {
        switch group {
        case .none: ""
        case .existing(let name): name
        case .new: typedGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var canSave: Bool {
        guard let draft else { return false }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        // A half-typed new group is not a group. Picking "New Group…" and
        // leaving it blank would otherwise save as no group at all, silently.
        return group != .new || !resolvedGroup.isEmpty
    }

    private func preview(_ tracker: Tracker) -> String {
        tracker.format(1_234.5)
    }

    private func load() {
        draft = tracker
        group = tracker.group.isEmpty ? .none : .existing(tracker.group)
        nameFocused = isNew
    }

    private func save() {
        guard var draft, canSave else { return }
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.unit = draft.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.group = resolvedGroup
        if isNew {
            store.add(draft)
        } else {
            store.update(draft)
        }
        dismiss()
    }
}

#Preview {
    let store = Store(
        document: StoreDocument(trackers: Tracker.starterSet),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-tracker"))
    )
    return TrackerEditor(tracker: store.trackers[0]).environment(store)
}
