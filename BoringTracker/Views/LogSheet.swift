import SwiftUI

/// One section's number pad: every tracker you log at the same time, a name,
/// when it happened, save.
///
/// The sheet is scoped to a section because that is what a section is for — the
/// trackers logged together (docs/PRODUCT.md). Calories and protein come from
/// the same meal, so they are one sheet and one save; your weight is not, so it
/// isn't in the way. Filling in one field and saving is the common case;
/// filling in two costs one extra tap, not a second trip through the sheet.
///
/// Nothing stands in front of it. Tapping + opens the last-used section
/// immediately with the keypad up, and switching sections happens *here*, from
/// the title, for the log that isn't the usual one.
struct LogSheet: View {

    /// Where the last-used section is remembered.
    ///
    /// `UserDefaults`, not the document: it is UI state, so it should not sync,
    /// export, or turn up in the store file — see "Two classes of decision" in
    /// docs/TECH.md. The default `""` is also the name of the unsectioned
    /// group, which costs nothing: if that group exists the first + lands there
    /// legitimately, and if it doesn't, the name isn't found and + falls back to
    /// the first section.
    static let lastSectionKey = "lastLoggedSection"

    struct Target: Identifiable, Hashable {
        var id = UUID()
        /// Which trackers the sheet shows. `""` is the unsectioned ones.
        var section: String
        /// Which field starts focused — the card whose + was tapped.
        var tracker: UUID?
    }

    let target: Target

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LogSheet.lastSectionKey) private var lastSection = ""
    @State private var section: String
    @State private var typed: [UUID: String] = [:]
    @State private var date = Date()
    @State private var name = ""
    @FocusState private var focused: UUID?

    init(target: Target) {
        self.target = target
        _section = State(initialValue: target.section)
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
                ToolbarItem(placement: .principal) { sectionTitle }
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
            focused = target.tracker ?? trackers.first?.id
        }
        .onChange(of: section) { _, _ in
            // Switching sections is not a reason to have to tap a field again.
            focused = trackers.first?.id
        }
    }

    /// The trackers this sheet is about, in their section order.
    private var trackers: [Tracker] {
        store.trackers(inSection: section)
    }

    /// The title is the section switcher, which is the whole trick: a menu in
    /// the place the section name has to be printed anyway costs nothing to
    /// ignore, and one tap to use for the rare log that isn't the usual one. A
    /// picker in *front* of the sheet would cost that tap every single time.
    @ViewBuilder
    private var sectionTitle: some View {
        let sections = store.activeSections
        if sections.count > 1 {
            Menu {
                Picker("Section", selection: $section) {
                    ForEach(sections, id: \.self) { name in
                        Text(label(name, among: sections)).tag(name)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(label(section, among: sections))
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
            .accessibilityLabel("Section, \(label(section, among: sections))")
        } else {
            Text(label(section, among: sections)).font(.headline)
        }
    }

    /// What to call a section on screen. The ungrouped trackers have no name to
    /// print: when they are all there is, the sheet is simply "Log", and when
    /// they sit alongside real sections they are the "Other" one.
    private func label(_ section: String, among sections: [String]) -> String {
        if !section.isEmpty { return section }
        return sections.count > 1 ? "Other" : "Log"
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

    /// Only what this sheet is showing. Switching sections keeps what was typed
    /// in the other one, so switching back doesn't lose it — but a save writes
    /// the section in front of you and nothing else. One save, one batch.
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
        // Written on save rather than on open, so cancelling out of a section
        // you only went to look at doesn't move where + lands tomorrow.
        lastSection = section
        dismiss()
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal", section: "Food")
    let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1, section: "Food")
    let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
                         sortIndex: 2, section: "Weight")
    let store = Store(
        document: StoreDocument(
            trackers: [calories, protein, weight],
            entries: [
                Entry(trackerID: calories.id, value: 450, date: .now.addingTimeInterval(-86_400)),
                Entry(trackerID: calories.id, value: 160, date: .now.addingTimeInterval(-90_000)),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-log"))
    )
    return LogSheet(target: .init(section: "Food", tracker: calories.id)).environment(store)
}
