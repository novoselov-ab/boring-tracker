import SwiftUI

/// Edits the values one history row represents, then commits them together.
struct BatchEditor: View {
    let item: HistoryItem

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [Draft] = []
    @State private var date = Date.now
    @State private var name = ""

    private struct Draft: Identifiable {
        var id: UUID { entry.id }
        var entry: Entry
        var typed: String
        /// False for a `lastTime` member, which has no number to edit. Decided
        /// once in `prepare` rather than asked of the store per redraw, so a
        /// kind changed while this sheet is open cannot leave a field on screen
        /// that `parsedValues` has stopped reading.
        var takesAmount: Bool
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($drafts) { $draft in
                        LabeledContent(trackerName(for: draft.entry)) {
                            if draft.takesAmount {
                                HStack(spacing: 6) {
                                    TextField("0", text: $draft.typed)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.body.monospacedDigit())
                                    if let unit = store.tracker(draft.entry.trackerID)?.unit,
                                       !unit.isEmpty {
                                        Text(unit).foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text(draft.typed).foregroundStyle(.secondary)
                            }
                        }
                    }
                    DatePicker("When", selection: $date)
                    TextField("Name", text: $name)
                } footer: {
                    if hasMixedMetadata {
                        Text("These entries have different names or times. Saving will use the name and time shown here for the whole batch.")
                    }
                }

                Section {
                    Button(item.entries.count == 1 ? "Delete Entry" : "Delete Batch",
                           systemImage: "trash", role: .destructive, action: delete)
                }
            }
            .navigationTitle(item.entries.count == 1 ? "Edit Entry" : "Edit Batch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction).navBarAccent()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(parsedValues == nil)
                        .navBarAccent()
                }
            }
        }
        .onAppear(perform: prepare)
    }

    private var hasMixedMetadata: Bool {
        Set(item.entries.map(\.date)).count > 1 || Set(item.entries.map(\.name)).count > 1
    }

    /// Only the members that have a number. A `lastTime` member is left out and
    /// keeps the value it was written with — `save` writes the date and the name
    /// over the whole batch either way, which is the edit it came here to make.
    private var parsedValues: [UUID: Double]? {
        var result: [UUID: Double] = [:]
        for draft in drafts where draft.takesAmount {
            guard let value = NumberInput.parse(draft.typed) else { return nil }
            result[draft.id] = value
        }
        return result.count == drafts.count(where: \.takesAmount) ? result : nil
    }

    private func trackerName(for entry: Entry) -> String {
        store.tracker(entry.trackerID)?.name ?? "Deleted tracker"
    }

    private func prepare() {
        guard drafts.isEmpty else { return }
        drafts = item.entries.map { entry in
            let tracker = store.tracker(entry.trackerID)
            let text = tracker?.kind == .lastTime
                ? tracker?.entryText(entry.value) ?? ""
                : tracker?.editText(entry.value) ?? entry.value.formatted(.number.grouping(.never))
            return Draft(entry: entry, typed: text, takesAmount: tracker?.kind != .lastTime)
        }
        date = item.date
        // `item.names`, the same list the row reads, so a batch whose newest
        // member had its name cleared elsewhere no longer opens blank while the
        // row shows a name — which is how saving any number used to write that
        // blank over every member.
        //
        // Not the same *answer* as the row, deliberately: where members disagree
        // the row says "Mixed names", which is a description and would be saved
        // as a literal name, so this seeds the newest one and saving flattens the
        // rest onto it. The footer above says so when it happens.
        name = item.names.first ?? ""
    }

    private func save() {
        guard let values = parsedValues else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedName = trimmed.isEmpty ? nil : trimmed
        let updated = drafts.map { draft in
            var entry = draft.entry
            entry.value = values[draft.id] ?? entry.value
            entry.date = date.canonicalized
            entry.name = savedName
            return entry
        }
        if store.update(updated) { dismiss() }
    }

    private func delete() {
        guard let entry = item.entries.first else { return }
        store.deleteBatch(containing: entry)
        dismiss()
    }
}
