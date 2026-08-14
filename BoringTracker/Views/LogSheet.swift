import SwiftUI

/// One log group's number pad: the trackers you write at the same time, a name,
/// when it happened, save.
///
/// The sheet covers a `LogGroup` — a section when the trackers are logged
/// together, and one tracker on its own when it isn't in a section. Calories and
/// protein come from the same meal, so they are one sheet and one save; your
/// weight is not, and your cigarettes are not, so neither is in the way. Filling
/// in a second field costs one extra tap, not a second trip through the sheet.
///
/// Nothing stands in front of it. Tapping + opens the group you logged last,
/// immediately, with the keypad up, and switching groups happens *here*, from
/// the title, for the log that isn't the usual one.
struct LogSheet: View {

    /// Where the last-used group is remembered.
    ///
    /// `UserDefaults`, not the document: it is UI state, so it should not sync,
    /// export, or turn up in the store file — see "Two classes of decision" in
    /// docs/TECH.md. Holds `LogGroup.rawValue`; anything that no longer resolves,
    /// including the empty default on a fresh install, means + opens the first
    /// group on the home screen.
    static let lastGroupKey = "lastLoggedGroup"

    struct Target: Identifiable, Hashable {
        var id = UUID()
        /// Which trackers the sheet shows.
        var group: LogGroup
        /// Which field starts focused — the card whose + was tapped.
        var tracker: UUID?
    }

    let target: Target

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LogSheet.lastGroupKey) private var lastGroup = ""
    @State private var group: LogGroup
    @State private var typed: [UUID: String] = [:]
    @State private var date = Date()
    @State private var name = ""
    @FocusState private var focused: UUID?

    init(target: Target) {
        self.target = target
        _group = State(initialValue: target.group)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(trackers) { tracker in
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { title }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(amounts.isEmpty)
                }
            }
        }
        .onAppear {
            // The keypad should already be up: tapping + goes straight to a
            // focused numeric field, with no intermediate screen.
            focused = target.tracker ?? trackers.first?.id
        }
        .onChange(of: group) { _, _ in
            // What was typed belonged to the group that was on screen when it
            // was typed, so it goes with it. Keeping it looked like the kinder
            // option — switch back and it is still there — but a save writes
            // only the group in front of you and then dismisses, so a number
            // typed into the group you switched away from was discarded in
            // silence, with the sheet closing over it. The name is the same
            // mistake wearing the other hat, and louder: carried across, it
            // files your weight under "chicken rice", which is exactly what
            // this field's own footer says it is not.
            //
            // The date stays. "When it happened" is a property of the trip
            // through the sheet, not of which trackers it lands on, so
            // backdating and then switching is not a mistake to undo.
            typed.removeAll()
            name = ""
            // Switching is not a reason to have to tap a field again.
            focused = trackers.first?.id
        }
    }

    /// The trackers this sheet is about, in the order they are drawn.
    private var trackers: [Tracker] {
        store.trackers(in: group)
    }

    /// The title is the switcher, which is the whole trick: a menu in the place
    /// the name has to be printed anyway costs nothing to ignore, and one tap to
    /// use for the rare log that isn't the usual one. A picker in *front* of the
    /// sheet would cost that tap every single time.
    ///
    /// The menu lists every section and every loose tracker — with a dozen
    /// trackers that is a dozen rows, which is exactly the list PRODUCT.md says
    /// must never be in the way. Behind the title it isn't: the common path
    /// never opens it.
    @ViewBuilder
    private var title: some View {
        let groups = store.logGroups
        if groups.count > 1 {
            Menu {
                Picker("Log", selection: $group) {
                    ForEach(groups, id: \.self) { group in
                        Text(label(group)).tag(group)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(label(group))
                    Image(systemName: "chevron.down").imageScale(.small)
                }
                .font(.headline)
                // The label alone is 21pt tall, which is a miss waiting to
                // happen next to a keyboard. Padded out to a full-height
                // target: it costs nothing, since the nav bar is empty either
                // side of it.
                .padding(.vertical, 11)
                .padding(.horizontal, 8)
                .contentShape(.rect)
            }
            .accessibilityLabel("Logging \(label(group))")
        } else {
            Text(label(group)).font(.headline)
        }
    }

    /// What to call a group on screen: the section's name, or the tracker's own.
    /// A loose tracker is not "Other" or "No section" — it is Cigarettes.
    private func label(_ group: LogGroup) -> String {
        switch group {
        case .section(let name): name
        case .tracker(let id): store.tracker(id)?.name ?? "Log"
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

    /// Only what this sheet is showing — one save, one batch. Switching clears
    /// the fields, so there is nothing else it could be hiding.
    private var amounts: [UUID: Double] {
        trackers.reduce(into: [:]) { result, tracker in
            if let value = NumberInput.parse(typed[tracker.id] ?? "") {
                result[tracker.id] = value
            }
        }
    }

    private func save() {
        let amounts = amounts
        guard !amounts.isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.add(values: amounts, at: date, name: trimmed.isEmpty ? nil : trimmed)
        // Written on save rather than on open, so cancelling out of a group you
        // only went to look at doesn't move where + lands tomorrow.
        lastGroup = group.rawValue
        dismiss()
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal", section: "Food")
    let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1, section: "Food")
    let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
                         sortIndex: 2, section: "Weight")
    // Loose, so its sheet is one field — the case the menu has to name properly.
    let cigarettes = Tracker(name: "Cigarettes", sortIndex: 3)
    let store = Store(
        document: StoreDocument(
            trackers: [calories, protein, weight, cigarettes],
            entries: [
                Entry(trackerID: calories.id, value: 450, date: .now.addingTimeInterval(-86_400)),
                Entry(trackerID: calories.id, value: 160, date: .now.addingTimeInterval(-90_000)),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-log"))
    )
    return LogSheet(target: .init(group: .section("Food"), tracker: calories.id))
        .environment(store)
}
