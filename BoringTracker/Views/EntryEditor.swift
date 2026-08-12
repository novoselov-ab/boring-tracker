import SwiftUI

/// Fixing one entry: the number, when it happened, the note, or all of it.
///
/// Separate from `LogSheet` because they are different jobs — logging is about
/// several trackers at once and getting out fast, editing is about one record
/// that already exists and can also be thrown away.
struct EntryEditor: View {
    let entry: Entry

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var typed = ""
    @State private var date = Date()
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(tracker?.name ?? "Value") {
                        HStack(spacing: 6) {
                            TextField("0", text: $typed)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.title3.monospacedDigit())
                                .focused($focused)
                            if let unit = tracker?.unit, !unit.isEmpty {
                                Text(unit).foregroundStyle(.secondary)
                            }
                        }
                    }
                    DatePicker("When", selection: $date)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        store.delete(entry)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(NumberInput.parse(typed) == nil)
                }
            }
        }
        .onAppear {
            typed = tracker?.editText(entry.value) ?? "\(entry.value)"
            date = entry.date
            note = entry.note ?? ""
            focused = true
        }
    }

    private var tracker: Tracker? { store.tracker(entry.trackerID) }

    private func save() {
        guard let value = NumberInput.parse(typed) else { return }
        var updated = entry
        updated.value = value
        updated.date = date.canonicalized
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = trimmed.isEmpty ? nil : trimmed
        store.update(updated)
        dismiss()
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal")
    let entry = Entry(trackerID: calories.id, value: 620, date: .now, note: "dinner")
    let store = Store(
        document: StoreDocument(trackers: [calories], entries: [entry]),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-edit"))
    )
    return EntryEditor(entry: entry).environment(store)
}
