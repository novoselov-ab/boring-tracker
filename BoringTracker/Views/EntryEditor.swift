import SwiftUI

/// Fixing one entry: the number, when it happened, the name, or all of it.
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
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // No value field for a `lastTime` entry: its date is the
                    // whole record, so *when* is the thing there is to fix, and
                    // a keypad here would be offering to edit the 0 that the
                    // rest of the app works to keep off the screen.
                    if takesAmount {
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
                    }
                    DatePicker("When", selection: $date)
                    TextField("Name", text: $name)
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
                    Button("Cancel") { dismiss() }.navBarAccent()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(takesAmount && NumberInput.parse(typed) == nil)
                        .navBarAccent()
                }
            }
        }
        .onAppear {
            typed = tracker?.editText(entry.value) ?? "\(entry.value)"
            date = entry.date
            name = entry.name ?? ""
            focused = takesAmount
        }
    }

    private var tracker: Tracker? { store.tracker(entry.trackerID) }

    /// True where a tracker has been deleted, deliberately: the entry still
    /// holds whatever number it was written with, and that is the one screen
    /// left that can show it.
    private var takesAmount: Bool { tracker?.kind != .lastTime }

    private func save() {
        var updated = entry
        if takesAmount {
            guard let value = NumberInput.parse(typed) else { return }
            updated.value = value
        }
        updated.date = date.canonicalized
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.name = trimmed.isEmpty ? nil : trimmed
        store.update(updated)
        dismiss()
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal")
    let entry = Entry(trackerID: calories.id, value: 620, date: .now, name: "dinner")
    let store = Store(
        document: StoreDocument(trackers: [calories], entries: [entry]),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-edit"))
    )
    return EntryEditor(entry: entry).environment(store)
}
