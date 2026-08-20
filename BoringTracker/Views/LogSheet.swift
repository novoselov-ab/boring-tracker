import SwiftUI

/// One log group's number pad: the trackers you write at the same time, a name,
/// when it happened, log.
///
/// The sheet covers a `LogGroup` — a group when the trackers are logged
/// together, and one tracker on its own when it isn't in a group. Nothing stands
/// in front of it: tapping + opens the group you logged last, immediately, with
/// the keypad up, and switching groups happens *here*, from the title.
struct LogSheet: View {

    /// `nil` makes the common-path presentation instant, and it stays that way.
    ///
    /// **Matching the keyboard's own duration was tried, measured, and
    /// reverted.** iOS will not raise the keyboard while a modal presentation
    /// animation is in flight, so the sheet's duration is added to the wait
    /// rather than hidden inside it: instant is one ramp at 0.713–0.823s over
    /// three runs, animated for the keyboard's 0.3833s is two ramps with a
    /// visible stall between them at 1.270–1.278s. Anything that does make them
    /// one movement has to own the presentation rather than ask `.sheet` for it.
    private static let presentationAnimation: Animation? = nil

    /// `UserDefaults`, not the document: UI state, so it should not sync, export
    /// or turn up in the store file. Holds `LogGroup.rawValue`; anything that no
    /// longer resolves, including the empty default on a fresh install, means +
    /// opens the first group on the home screen.
    static let lastGroupKey = "lastLoggedGroup"

    struct Target: Identifiable, Hashable {
        var id = UUID()
        var group: LogGroup
        /// Which field starts focused. `nil` from the primary action, which has
        /// no particular tracker in mind and lands on the first field.
        var tracker: UUID?
    }

    let target: Target

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The name field is part of the same walk as the amounts — the thing you
    /// reach for after the last number is what you ate. The date is deliberately
    /// not: it is a wheel, not a field, and stopping the keypad on it would be
    /// the one place the walk costs you something.
    private enum Field: Hashable {
        case amount(UUID)
        case name
    }

    @AppStorage(LogSheet.lastGroupKey) private var lastGroup = ""
    @State private var group: LogGroup
    @State private var typed: [UUID: String] = [:]
    @State private var date = Date()
    @State private var name = ""
    @FocusState private var focused: Field?

    init(target: Target) {
        self.target = target
        _group = State(initialValue: target.group)
    }

    static func present(_ target: Target, using binding: Binding<Target?>) {
        var transaction = Transaction(animation: presentationAnimation)
        transaction.disablesAnimations = presentationAnimation == nil
        withTransaction(transaction) {
            binding.wrappedValue = target
        }
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
                        .focused($focused, equals: .name)
                } footer: {
                    Text("The name is what you ate, not what it counts towards. "
                        + "The time defaults to now — change it to log something you forgot.")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { title }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // A native `.keyboard` toolbar did not render an accessory in
                // this iOS 26 sheet. The keyboard-following safe-area inset
                // keeps the action in the same thumb-reachable position.
                HStack(spacing: 8) {
                    fieldStep(-1, "chevron.up", "Previous field")
                    fieldStep(1, "chevron.down", "Next field")
                    Spacer()
                    Button(action: log) {
                        // Inside the label rather than on the button: this is the
                        // one prominent button in the app that is routinely
                        // disabled — the sheet opens that way — and
                        // `onAccentFill` reads `isEnabled` from in here, inside
                        // `.disabled`, to pick between its two states.
                        Text("Log").onAccentFill()
                    }
                    // `.accentPill` paints all three states itself; iOS draws
                    // none of them here.
                    .buttonStyle(.accentPill)
                    .disabled(amounts.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
                .background(.bar)
            }
        }
        // The only thing on this sheet that says how to leave it without
        // logging: Cancel was removed to keep the nav bar for the common case,
        // which left the swipe-down exit real and unadvertised. On the
        // `NavigationStack` rather than the `Form`, because it is a property of
        // the presentation and the stack is what the sheet presents.
        .presentationDragIndicator(.visible)
        .task {
            // Presentation deliberately has animations disabled. Let that
            // transaction finish before asking the system to animate in the
            // keypad; focusing inside it suppresses the keypad altogether.
            await Task.yield()
            focused = (target.tracker ?? trackers.first?.id).map(Field.amount)
        }
        .onChange(of: group) { _, _ in
            // What was typed belonged to the group that was on screen. Keeping
            // it looked kinder, but a log writes only the group in front of you
            // and then dismisses, so a number typed into the group you switched
            // away from was discarded in silence. Carried across, the name is
            // the same mistake wearing the other hat and louder: it files your
            // weight under "chicken rice".
            //
            // The date stays. "When it happened" is a property of the trip
            // through the sheet, not of which trackers it lands on.
            typed.removeAll()
            name = ""
            focused = (trackers.first?.id).map(Field.amount)
        }
    }

    /// The group's fields, which is everything in it that takes a number. A
    /// `lastTime` tracker in a group is logged from its own card in one tap and
    /// has nothing to type here, so it is not drawn — see `Store.amountTrackers`.
    private var trackers: [Tracker] {
        store.amountTrackers(in: group)
    }

    /// Deduplicated, because the walk steps by *value*: `@FocusState` has only
    /// the field to compare against. A store file holding two trackers with the
    /// same id — a shape nothing on the load path rejects, and one that
    /// `Store.reorderAll`, `CSVExport` and `HistoryView` all tolerate with
    /// `uniquingKeysWith` — would otherwise put the same value in twice,
    /// `firstIndex(of:)` would keep returning the first copy, and "next" would
    /// land back where it started.
    private var fields: [Field] {
        var seen = Set<Field>()
        return (trackers.map { Field.amount($0.id) } + [.name])
            .filter { seen.insert($0).inserted }
    }

    /// Wraps at both ends rather than greying out: with two or three fields a
    /// disabled chevron is a dead control most of the time.
    private func fieldStep(_ offset: Int, _ symbol: String, _ label: String) -> some View {
        Button {
            let fields = fields
            guard let focused, let index = fields.firstIndex(of: focused) else {
                // Nothing focused — the keypad went down, most likely because
                // the date picker took over. Both chevrons come back to the
                // first field rather than to the end the arrow points at:
                // sending *Previous* to the last field moved it forward, past
                // the date the user had just left.
                self.focused = fields.first
                return
            }
            self.focused = fields[(index + offset + fields.count) % fields.count]
        } label: {
            Image(systemName: symbol)
                // Fixed, not `.body`: the 44pt frame does not scale, so a text
                // style grows the glyph out of its own target. At AX5 the two
                // chevrons drew ~46pt wide inside 44pt frames and touched, so
                // aiming at the drawn up-chevron could land in the down-chevron's
                // rect.
                .font(.system(size: 17, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// The title is the switcher: a menu in the place the name has to be printed
    /// anyway costs nothing to ignore, and one tap for the rare log that isn't
    /// the usual one. A picker in *front* of the sheet would cost that tap every
    /// single time.
    @ViewBuilder
    private var title: some View {
        let groups = store.loggableGroups
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
                // happen next to a keyboard. Padded out to a full-height target;
                // the nav bar is empty either side of it.
                .padding(.vertical, 11)
                .padding(.horizontal, 8)
                .contentShape(.rect)
            }
            .accessibilityLabel("Logging \(label(group))")
            // Tinted, because the alternative is looking identical to the static
            // title in the `else` branch below — the same words, for a group you
            // cannot switch away from. A 12pt chevron is not enough difference.
            .navBarAccent()
        } else {
            Text(label(group)).font(.headline)
        }
    }

    /// A loose tracker is not "Other" or "No group" — it is Cigarettes.
    private func label(_ group: LogGroup) -> String {
        switch group {
        case .group(let name): name
        case .tracker(let id): store.tracker(id)?.name ?? "Log"
        }
    }

    private func amountRow(_ tracker: Tracker) -> some View {
        LabeledContent(tracker.name) {
            HStack(spacing: 6) {
                TextField("0", text: binding(for: tracker.id))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.monospacedDigit())
                    .focused($focused, equals: .amount(tracker.id))
                if !tracker.unit.isEmpty {
                    Text(tracker.unit).foregroundStyle(.secondary)
                }
            }
        }
    }

    // There is deliberately no row of recently-used values here. It was tried:
    // nobody logs the same *number* twice — they log the same food, and the
    // number follows from the name. The chips took the space under the field you
    // were typing into, moved the form as you focused and blurred, and were
    // tapped roughly never. Repeating a whole logged food is what they were a
    // bad guess at, and History and its repeat screen built that instead.

    private func binding(for tracker: UUID) -> Binding<String> {
        Binding(
            get: { typed[tracker] ?? "" },
            set: { typed[tracker] = $0 }
        )
    }

    private var amounts: [UUID: Double] {
        trackers.reduce(into: [:]) { result, tracker in
            if let value = NumberInput.parse(typed[tracker.id] ?? "") {
                result[tracker.id] = value
            }
        }
    }

    private func log() {
        let amounts = amounts
        guard !amounts.isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.add(values: amounts, at: date, name: trimmed.isEmpty ? nil : trimmed)
        // Written on log rather than on open, so dismissing a group you only
        // went to look at doesn't move where + lands tomorrow.
        lastGroup = group.rawValue
        dismiss()
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal", group: "Food")
    let protein = Tracker(name: "Protein", unit: "g", sortIndex: 1, group: "Food")
    let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
                         sortIndex: 2, group: "Weight")
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
    return LogSheet(target: .init(group: .group("Food"), tracker: calories.id))
        .environment(store)
}
