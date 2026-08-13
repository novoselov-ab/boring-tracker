import SwiftUI

/// Number pad, recents, when it happened, save.
///
/// Every tracker gets a field, because calories and protein come from the same
/// meal and typing them in two separate flows is the single most annoying thing
/// this app could do. Filling in one and saving is the common case; filling in
/// two costs one extra tap, not a second trip through the sheet.
struct LogSheet: View {

    struct Target: Identifiable, Hashable {
        var id = UUID()
        /// Which field starts focused — the card whose + was tapped.
        var tracker: UUID?
    }

    let target: Target

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var typed: [UUID: String] = [:]
    @State private var date = Date()
    @State private var name = ""
    @FocusState private var focused: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(store.activeTrackers) { tracker in
                        amountRow(tracker)
                    }
                }

                Section {
                    DatePicker("When", selection: $date)
                    TextField("Name", text: $name)
                } footer: {
                    Text("The name is what you ate, not what it counts towards. "
                        + "The time defaults to now — change it to log something you forgot.")
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(amounts.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            // The keypad should already be up: tapping + goes straight to a
            // focused numeric field, with no intermediate screen.
            focused = target.tracker ?? store.activeTrackers.first?.id
        }
    }

    @ViewBuilder
    private func amountRow(_ tracker: Tracker) -> some View {
        LabeledContent(tracker.name) {
            HStack(spacing: 6) {
                TextField("0", text: binding(for: tracker.id))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.monospacedDigit())
                    .focused($focused, equals: tracker.id)
                if !tracker.unit.isEmpty {
                    Text(tracker.unit).foregroundStyle(.secondary)
                }
            }
        }

        if focused == tracker.id {
            recents(for: tracker)
        }
    }

    /// One tap for a number you have logged before.
    @ViewBuilder
    private func recents(for tracker: Tracker) -> some View {
        let values = store.recentValues(for: tracker.id)
        if !values.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Button(tracker.format(value, includeUnit: false)) {
                            typed[tracker.id] = tracker.editText(value)
                        }
                        .buttonStyle(.bordered)
                        .monospacedDigit()
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .listRowSeparator(.hidden)
        }
    }

    private func binding(for tracker: UUID) -> Binding<String> {
        Binding(
            get: { typed[tracker] ?? "" },
            set: { typed[tracker] = $0 }
        )
    }

    private var amounts: [UUID: Double] {
        typed.reduce(into: [:]) { result, pair in
            if let value = NumberInput.parse(pair.value) { result[pair.key] = value }
        }
    }

    private func save() {
        let amounts = amounts
        guard !amounts.isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.add(values: amounts, at: date, name: trimmed.isEmpty ? nil : trimmed)
        dismiss()
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal")
    let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1)
    let store = Store(
        document: StoreDocument(
            trackers: [calories, protein],
            entries: [
                Entry(trackerID: calories.id, value: 450, date: .now.addingTimeInterval(-86_400)),
                Entry(trackerID: calories.id, value: 160, date: .now.addingTimeInterval(-90_000)),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-log"))
    )
    return LogSheet(target: .init(tracker: calories.id)).environment(store)
}
