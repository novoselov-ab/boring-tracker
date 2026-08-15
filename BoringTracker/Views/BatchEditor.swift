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
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($drafts) { $draft in
                        LabeledContent(trackerName(for: draft.entry)) {
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
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(parsedValues == nil)
                }
            }
        }
        .onAppear(perform: prepare)
    }

    private var hasMixedMetadata: Bool {
        Set(item.entries.map(\.date)).count > 1 || Set(item.entries.map(\.name)).count > 1
    }

    private var parsedValues: [UUID: Double]? {
        var result: [UUID: Double] = [:]
        for draft in drafts {
            guard let value = NumberInput.parse(draft.typed) else { return nil }
            result[draft.id] = value
        }
        return result.count == drafts.count ? result : nil
    }

    private func trackerName(for entry: Entry) -> String {
        store.tracker(entry.trackerID)?.name ?? "Deleted tracker"
    }

    private func prepare() {
        guard drafts.isEmpty else { return }
        drafts = item.entries.map { entry in
            let text = store.tracker(entry.trackerID)?.editText(entry.value)
                ?? entry.value.formatted(.number.grouping(.never))
            return Draft(entry: entry, typed: text)
        }
        date = item.date
        name = item.entries.first?.name ?? ""
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
