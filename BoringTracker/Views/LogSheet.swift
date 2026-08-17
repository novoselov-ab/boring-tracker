import SwiftUI

/// One log group's number pad: the trackers you write at the same time, a name,
/// when it happened, log.
///
/// The sheet covers a `LogGroup` — a group when the trackers are logged
/// together, and one tracker on its own when it isn't in a group. Calories and
/// protein come from the same meal, so they are one sheet and one log; your
/// weight is not, and your cigarettes are not, so neither is in the way. Filling
/// in a second field costs one extra tap, not a second trip through the sheet.
///
/// Nothing stands in front of it. Tapping + opens the group you logged last,
/// immediately, with the keypad up, and switching groups happens *here*, from
/// the title, for the log that isn't the usual one.
struct LogSheet: View {

    /// `nil` makes the common-path presentation instant, and it stays that way.
    ///
    /// **Matching the keyboard was tried here, measured, and reverted.** Item 11
    /// asked for the sheet and the keypad to arrive as one movement, on the
    /// reasoning that a move finishing exactly when the keypad does costs
    /// nothing extra. It costs everything extra, because the two do not
    /// overlap: iOS will not raise the keyboard while a modal presentation
    /// animation is in flight, so the sheet's duration is added to the wait
    /// rather than hidden inside it.
    ///
    /// The recording says it plainly. The keypad always begins ~0.22s after the
    /// sheet is *presented*, whatever the sheet did to get there, so the total
    /// is sheet + 0.22 + keypad. Instant: one ramp, **0.713–0.823s** over three
    /// runs. Animated for 0.3833s — the keyboard's own duration, read from
    /// `keyboardAnimationDurationUserInfoKey` with a temporary probe rather
    /// than assumed — two ramps with a visible stall between them, and
    /// **1.270–1.278s**. That is not one movement that happens to take longer;
    /// it is the same two movements, further apart, for half a second more.
    ///
    /// So the glitch item 11 describes is real and this is not the fix for it.
    /// Anything that is, has to start the keypad and the sheet together, which
    /// means owning the presentation rather than asking `.sheet` for it — a
    /// much larger change than the one this item was scoped for.
    private static let presentationAnimation: Animation? = nil

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
        /// Which field starts focused — the tracker whose + was tapped. `nil`
        /// from the primary action, which has no particular tracker in mind
        /// and lands on the first field of whatever group it opened.
        var tracker: UUID?
    }

    let target: Target

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Which field the keypad is attached to.
    ///
    /// An enum rather than a bare tracker id because the name field is part of
    /// the same walk: the chevrons in the bar step through everything you can
    /// type into, and the thing you reach for after the last number is what you
    /// ate. The date is deliberately not in here — it is a wheel, not a field,
    /// and stopping the keypad on it would be the one place the walk costs you
    /// something instead of saving it.
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

    /// Present without making the user wait for the standard sheet slide.
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
                        // Dark on the teal (see `Color.onAccent`), and inside
                        // the label rather than on the button: this is the one
                        // prominent button in the app that is routinely
                        // disabled — the sheet opens that way, with no number
                        // typed yet — and a disabled prominent button is drawn
                        // from a neutral near-black fill that ignores the tint
                        // entirely. `onAccentFill` reads `isEnabled` from here,
                        // inside `.disabled`, and stands aside for it.
                        Text("Log").onAccentFill()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(amounts.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
                .background(.bar)
            }
        }
        .task {
            // Presentation deliberately has animations disabled. Let that
            // transaction finish before asking the system to animate in the
            // keypad; focusing inside it suppresses the keypad altogether.
            await Task.yield()
            // The keypad should already be up: tapping + goes straight to a
            // focused numeric field, with no intermediate screen.
            focused = (target.tracker ?? trackers.first?.id).map(Field.amount)
        }
        .onChange(of: group) { _, _ in
            // What was typed belonged to the group that was on screen when it
            // was typed, so it goes with it. Keeping it looked like the kinder
            // option — switch back and it is still there — but a log writes
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
            focused = (trackers.first?.id).map(Field.amount)
        }
    }

    /// The trackers this sheet is about, in the order they are drawn.
    private var trackers: [Tracker] {
        store.trackers(in: group)
    }

    /// Everything the chevrons walk, in the order it is drawn. Every typeable
    /// field is in it and nothing is skipped, so "next" never jumps over a
    /// number you were about to fill in.
    ///
    /// Deduplicated, because the walk steps by *value*: `@FocusState` has only
    /// the field to compare against. A store file holding two trackers with the
    /// same id — a shape nothing on the load path rejects, and one that
    /// `Store.reorderAll`, `CSVExport` and `HistoryView` all already tolerate
    /// with `uniquingKeysWith` — would otherwise put the same value in twice,
    /// `firstIndex(of:)` would keep returning the first copy, and "next" would
    /// land back where it started. A dead chevron and an unreachable name field
    /// is a worse way to meet bad data than one row drawn twice.
    private var fields: [Field] {
        var seen = Set<Field>()
        return (trackers.map { Field.amount($0.id) } + [.name])
            .filter { seen.insert($0).inserted }
    }

    /// One step of the walk. Wraps at both ends rather than greying out: with
    /// two or three fields a disabled chevron is a dead control most of the
    /// time, and wrapping means the thumb never has to check which end it is at.
    private func fieldStep(_ offset: Int, _ symbol: String, _ label: String) -> some View {
        Button {
            let fields = fields
            guard let focused, let index = fields.firstIndex(of: focused) else {
                // Nothing focused — the keypad went down, most likely because
                // the date picker took over. Both chevrons come back to the
                // first field rather than to the end the arrow points at:
                // there is no "previous" to a cursor that isn't anywhere, and
                // sending *Previous* to the last field moved it forward, past
                // the date the user had just left.
                self.focused = fields.first
                return
            }
            self.focused = fields[(index + offset + fields.count) % fields.count]
        } label: {
            Image(systemName: symbol)
                // Fixed, not `.body`: the 44pt frame it sits in does not
                // scale, so a text style grows the glyph out of its own target.
                // At AX5 the two chevrons drew ~46pt wide inside 44pt frames
                // and touched, so aiming at the *drawn* up-chevron could land
                // in the down-chevron's rect — a previous/next control that
                // does the opposite of what it looks like.
                .font(.system(size: 17, weight: .medium))
                // Tinted, like every other system form accessory: `.plain` is
                // here for the 44pt `contentShape`, not for its colour, and it
                // would otherwise paint these the same black as the labels.
                // `.tint`, not `Color.accentColor` — the accent lives as an
                // environment tint (see `BoringTrackerApp`), and the catalog
                // colour that name resolves is still the system blue.
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// The title is the switcher, which is the whole trick: a menu in the place
    /// the name has to be printed anyway costs nothing to ignore, and one tap to
    /// use for the rare log that isn't the usual one. A picker in *front* of the
    /// sheet would cost that tap every single time.
    ///
    /// The menu lists every group and every loose tracker — with a dozen
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

    /// What to call a group on screen: the group's name, or the tracker's own.
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

    // There is deliberately no row of recently-used values here.
    //
    // It was one tap for a number you had logged before, and it turns out
    // nobody logs the same *number* twice — they log the same food, and the
    // number follows from the name. So the chips took up the space under the
    // field you were typing into, moved the form around as you focused and
    // blurred, and were tapped roughly never. The feature these chips were a
    // bad guess at is repeating a whole logged food, and item 14 built the
    // first half of it on the History screen without needing
    // `Store.recentValues` at all — see the note on that method.

    private func binding(for tracker: UUID) -> Binding<String> {
        Binding(
            get: { typed[tracker] ?? "" },
            set: { typed[tracker] = $0 }
        )
    }

    /// Only what this sheet is showing — one log, one batch. Switching clears
    /// the fields, so there is nothing else it could be hiding.
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
        // The two frozen snapshots that used to live here went with the recents
        // row they existed to hold still. Nothing on this screen reflows on save
        // any more, because nothing on it is computed from the entries.
        store.add(values: amounts, at: date, name: trimmed.isEmpty ? nil : trimmed)
        // Written on log rather than on open, so dismissing a group you
        // only went to look at doesn't move where + lands tomorrow.
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
