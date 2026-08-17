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
/// immediately, with the pad already on screen, and switching groups happens
/// *here*, from the title, for the log that isn't the usual one.
///
/// **The pad is drawn, not asked for** — see `NumberPad`. Everything below
/// about keyboard timing is why, and stays because it is the reasoning the
/// design rests on rather than a description of what the code now does.
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
    /// Anything that is, has to start the keypad and the sheet together.
    ///
    /// Item 12 is that fix, and it took the cheaper of the two roads: not
    /// owning the presentation, but not asking for a keyboard at all. The
    /// constraint above binds only while one is being raised. With the pad
    /// drawn as an ordinary view, the sheet's first frame *is* the typeable
    /// frame — measured at 0.205–0.207s from the press, against 0.698–0.708s
    /// here, and nothing left after the sheet appears where 0.517s of keypad
    /// used to be.
    private static let presentationAnimation: Animation? = nil

    /// Where the last-used group is remembered.
    ///
    /// `UserDefaults`, not the document: it is UI state, so it should not sync,
    /// export, or turn up in the store file — see "Two classes of decision" in
    /// docs/TECH.md. Holds `LogGroup.rawValue`; anything that no longer resolves,
    /// including the empty default on a fresh install, means + opens the first
    /// group on the home screen.
    static let lastGroupKey = "lastLoggedGroup"

    /// Scroll identity for the name row. The amount rows use their tracker's
    /// id; the name has none, so it gets one.
    private static let nameRow = "name"

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
    /// One source for what the decimal separator is, handed to both the pad
    /// that types it and the parser that reads it back. They disagreed for
    /// free while both defaulted to `Locale.current`; now they cannot.
    @Environment(\.locale) private var locale

    @AppStorage(LogSheet.lastGroupKey) private var lastGroup = ""
    @State private var group: LogGroup
    @State private var typed: [UUID: String] = [:]
    @State private var date = Date()
    @State private var name = ""

    /// Which amount field the pad types into, once the user has moved it.
    ///
    /// `nil` is not "nowhere" — it means nobody has moved the caret yet, and
    /// `activeAmount` resolves it from the target and the store. That is the
    /// whole of what `.task { await Task.yield() }` and a `@FocusState` set
    /// after presentation used to buy: the pad is drawn, so there is no
    /// keyboard whose arrival the first field has to be ordered against, and
    /// the caret is simply where the sheet's first frame says it is.
    @State private var picked: UUID?

    /// The name field, and only the name field, still uses the system
    /// keyboard. Naming is the rare path, so it can pay the presentation this
    /// item removes from the common one; and a pad with no letters on it is no
    /// way to type "chicken rice".
    @FocusState private var nameFocused: Bool

    /// Bumped every time the caret is put on an amount field, so the hardware
    /// keyboard follows it. See `HardwareKeys.claim`.
    @State private var claim = 0

    /// The caret's height, tied to the size of the number it stands next to.
    @ScaledMetric(relativeTo: .title3) private var caretHeight: CGFloat = 24

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
            ScrollViewReader { form in
                Form {
                    Section {
                        ForEach(trackers) { tracker in
                            amountRow(tracker)
                        }
                    }

                    Section {
                        DatePicker("When", selection: $date)
                        TextField("Name", text: $name)
                            .focused($nameFocused)
                            .id(Self.nameRow)
                    } footer: {
                        Text("The name is what you ate, not what it counts towards. "
                            + "The time defaults to now — change it to log something you forgot.")
                    }
                }
                .onChange(of: activeAmount) { _, tracker in
                    // The system scrolled a focused text field above the
                    // keyboard for us, and it will not do that for a pad we
                    // drew ourselves. A group with more trackers than fit
                    // above the pad would otherwise step the caret onto a row
                    // hidden behind it — you would be typing into something
                    // you cannot see. Not animated: this happens after your
                    // tap, and there is nothing to explain about where a row
                    // went that a jump does not say faster.
                    if let tracker { form.scrollTo(tracker, anchor: .center) }
                }
                .onChange(of: nameFocused) { _, isFocused in
                    // The system scrolls a focused field clear of the
                    // *keyboard* and knows nothing about the bar we put above
                    // it, so it stopped one bar-height short and left the name
                    // half behind the chevrons — measurable at HEAD too, and
                    // fully hidden once the pad changed how far the form
                    // scrolls. Typing into a field you cannot see is not the
                    // rare path paying for itself, it is just broken.
                    guard isFocused else { return }
                    Task { form.scrollTo(Self.nameRow, anchor: .center) }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { title }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { keys }
        }
        // Zero-sized and behind everything: it is a place in the responder
        // chain, not something to look at. See `HardwareKeys`.
        .background {
            HardwareKeys(
                isActive: !nameFocused,
                claim: claim,
                insert: insert,
                delete: deleteBack,
                // `log` already refuses an empty sheet, which is the same rule
                // that greys out the button, so Return needs no second one.
                submit: log,
                next: { step(1) }
            )
            .frame(width: 0, height: 0)
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
            // Switching is not a reason to have to tap a field again. `nil`
            // rather than the new group's first tracker because that is what
            // `activeAmount` already resolves it to, and one rule for where
            // the caret starts is better than two that have to agree.
            focusAmount(nil)
        }
    }

    /// The trackers this sheet is about, in the order they are drawn.
    private var trackers: [Tracker] {
        store.trackers(in: group)
    }

    /// The amount fields the chevrons walk, in the order they are drawn. The
    /// name is the step after the last of these — it is part of the same walk,
    /// because the thing you reach for after the last number is what you ate.
    /// The date is deliberately not in it: it is a wheel, not a field, and
    /// stopping the caret on it would be the one place the walk costs you
    /// something instead of saving it.
    ///
    /// Deduplicated, because the walk steps by *value*. A store file holding
    /// two trackers with the same id — a shape nothing on the load path
    /// rejects, and one that `Store.reorderAll`, `CSVExport` and `HistoryView`
    /// all already tolerate with `uniquingKeysWith` — would otherwise put the
    /// same id in twice, `firstIndex(of:)` would keep returning the first copy,
    /// and "next" would land back where it started. A dead chevron and an
    /// unreachable name field is a worse way to meet bad data than one row
    /// drawn twice.
    private var amountIDs: [UUID] {
        var seen = Set<UUID>()
        return trackers.map(\.id).filter { seen.insert($0).inserted }
    }

    /// Where the pad types. Resolved rather than stored, so there is no moment
    /// after presentation when it is unset and nothing to sequence against the
    /// sheet appearing: the caret is on the tracker whose + was tapped, or on
    /// the first field of whatever group opened, from the very first frame.
    ///
    /// `picked` only overrides it while it names a tracker this sheet is
    /// actually showing, which is what makes switching groups safe to handle by
    /// clearing it.
    private var activeAmount: UUID? {
        let ids = amountIDs
        if let picked, ids.contains(picked) { return picked }
        if let tracker = target.tracker, ids.contains(tracker) { return tracker }
        return ids.first
    }

    /// One step of the walk, over the amount fields and then the name. Wraps at
    /// both ends rather than greying out: with two or three fields a disabled
    /// chevron is a dead control most of the time, and wrapping means the thumb
    /// never has to check which end it is at.
    ///
    /// The old "nothing is focused, so go to the first field" case is gone with
    /// the keypad that caused it. The caret is never nowhere now — tapping the
    /// date wheel cannot take it away, because the wheel and the pad no longer
    /// compete for one system focus.
    private func step(_ offset: Int) {
        let ids = amountIDs
        guard !ids.isEmpty else {
            nameFocused = true
            return
        }
        // One past the last amount field is the name.
        let count = ids.count + 1
        let current = nameFocused
            ? ids.count
            : (activeAmount.flatMap { ids.firstIndex(of: $0) } ?? 0)
        let next = (current + offset + count) % count
        if next == ids.count {
            nameFocused = true
        } else {
            focusAmount(ids[next])
        }
    }

    /// Put the caret on an amount field — `nil` meaning "wherever
    /// `activeAmount` resolves to" — and bring everything that types with it.
    ///
    /// One function because the three parts always travel together: the
    /// letters go away, the caret moves, and the hardware keyboard follows.
    /// Setting two of the three and forgetting the third is the shape of every
    /// bug this sheet's focus handling has had.
    private func focusAmount(_ tracker: UUID?) {
        picked = tracker
        nameFocused = false
        claim += 1
    }

    private func fieldStep(_ offset: Int, _ symbol: String, _ label: String) -> some View {
        Button {
            step(offset)
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
                .foregroundStyle(Color.accentColor)
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

    /// Everything below the form: the actions, then the pad.
    ///
    /// One `safeAreaInset` holds both, so they move as one and the Log button
    /// stays exactly where item 5 put it — directly above the digits, which is
    /// the shortest travel a thumb already on the pad can make.
    ///
    /// The pad steps aside while the name field is up. It has to: a
    /// `safeAreaInset` is lifted above the system keyboard, so leaving it in
    /// would stack a pad you cannot use on top of the letters you asked for.
    /// The bar stays, which is what keeps Log reachable in both states and
    /// stops the two arrangements reading as different screens.
    @ViewBuilder
    private var keys: some View {
        VStack(spacing: 0) {
            // A native `.keyboard` toolbar did not render an accessory in this
            // iOS 26 sheet. The inset keeps the action in the same
            // thumb-reachable position, and now also carries the pad.
            HStack(spacing: 8) {
                fieldStep(-1, "chevron.up", "Previous field")
                fieldStep(1, "chevron.down", "Next field")
                Spacer()
                Button("Log", action: log)
                    .buttonStyle(.borderedProminent)
                    .disabled(amounts.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
            .background(.bar)

            if !nameFocused {
                NumberPad(separator: separator, insert: insert, delete: deleteBack)
            }
        }
    }

    /// This region's decimal separator, from the same environment locale the
    /// parse uses.
    private var separator: String {
        locale.decimalSeparator ?? "."
    }

    private func insert(_ key: String) {
        guard let tracker = activeAmount else { return }
        typed[tracker] = NumberInput.appending(key, to: typed[tracker] ?? "", locale: locale)
    }

    private func deleteBack() {
        guard let tracker = activeAmount else { return }
        typed[tracker] = String((typed[tracker] ?? "").dropLast())
    }

    /// A row you tap to move the caret, with the pad doing the typing.
    ///
    /// Not a `TextField` any more, and that is the point of the item: a text
    /// field is what asks for a keyboard. What is kept is everything a text
    /// field was showing — the greyed `0` while it is empty, the value
    /// right-aligned in monospaced digits, the unit beside it, and a caret on
    /// the field being typed into.
    private func amountRow(_ tracker: Tracker) -> some View {
        let text = typed[tracker.id] ?? ""
        // `activeAmount` says which row the pad *would* type into; it stays
        // put while the name has the keyboard, on purpose, so that coming back
        // returns to the field you left. But drawing its caret meanwhile put
        // two carets on screen and told VoiceOver the selected field was the
        // one typing does not go to.
        let isActive = activeAmount == tracker.id && !nameFocused
        return Button {
            // Tapping a number puts the letters away too. Otherwise the pad
            // would come back under a keyboard that is still up.
            focusAmount(tracker.id)
        } label: {
            LabeledContent {
                HStack(spacing: 4) {
                    Text(text.isEmpty ? "0" : text)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                    caret
                        .opacity(isActive ? 1 : 0)
                    if !tracker.unit.isEmpty {
                        Text(tracker.unit).foregroundStyle(.secondary)
                    }
                }
            } label: {
                // Capped, because a tracker name is unbounded free text and
                // the row it is in has a hard ceiling now: the pad takes 43%
                // of an iPhone SE, and `LabeledContent` stacks the label over
                // the value at accessibility sizes. Measured at AX5 with
                // "Calories burned exercising", the name ran to three lines
                // and pushed the number — the one thing on this screen you are
                // typing — under the bar. The name giving way is the same call
                // HomeView's card makes, for the same reason: a truncated name
                // still says which tracker it is, an invisible number does not.
                Text(tracker.name).lineLimit(2)
            }
            // The row's own insets are moved in here so the tap target is the
            // whole row rather than the 24pt the text happens to occupy. Read
            // back off the tree, not guessed: the first version reported a
            // 338x24 button inside a 370x54 row, so half of what looks like
            // the control did nothing.
            .padding(.vertical, 15)
            .contentShape(.rect)
            // Spelled out rather than assembled from the row's parts, which
            // reads the placeholder "0" as a value that was entered. Inside
            // the button's label, not on the button: applied outside, this
            // wrapped the button in a second element and left the real one
            // announcing "Calories, 0, Calories, kcal" underneath it. Same
            // trap HomeView's card documents.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                tracker.unit.isEmpty ? tracker.name : "\(tracker.name), \(tracker.unit)"
            )
            .accessibilityValue(text.isEmpty ? "Empty" : text)
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .id(tracker.id)
        .accessibilityHint("Types here")
    }

    /// Drawn always and hidden with opacity rather than added and removed, so
    /// stepping between fields cannot shift the row's width under the thumb
    /// that is stepping.
    ///
    /// Scaled rather than fixed: it stands beside `.title3` text, and a fixed
    /// bar next to text that grows is the mismatch item 11 found three times.
    /// It does not blink — a repeating animation for a caret that is already
    /// the only coloured thing on the row buys nothing and never stops.
    private var caret: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 2, height: caretHeight)
    }

    // There is deliberately no row of recently-used values here.
    //
    // It was one tap for a number you had logged before, and it turns out
    // nobody logs the same *number* twice — they log the same food, and the
    // number follows from the name. So the chips took up the space under the
    // field you were typing into, moved the form around as you focused and
    // blurred, and were tapped roughly never. `Store.recentValues` is
    // deliberately kept: item 14's search-and-repeat is the feature these
    // chips were a bad guess at, and it wants exactly that data.

    /// Only what this sheet is showing — one log, one batch. Switching clears
    /// the fields, so there is nothing else it could be hiding.
    private var amounts: [UUID: Double] {
        trackers.reduce(into: [:]) { result, tracker in
            if let value = NumberInput.parse(typed[tracker.id] ?? "", locale: locale) {
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
