import SwiftUI

extension Color {

    /// What a list row goes while it is held down.
    ///
    /// **iOS's own answer, read off iOS rather than chosen.** The app draws its
    /// rows as `.plain` buttons, which is why they had no pressed state to
    /// begin with — but settings still has one row the platform draws itself,
    /// the `NavigationLink` to *About*, and that row does press. Held down on an
    /// iPhone 17 Pro and screenshotted mid-press, sampled out of the PNG's own
    /// IDAT bytes:
    ///
    ///     appearance  row at rest   row held
    ///     light       #FFFFFF       #D1D1D6
    ///     dark        #1C1C1E       #3A3A3C
    ///
    /// Both of those held values are `UIColor.systemGray4` exactly, in both
    /// appearances, so this is that colour and not a match for it. Which is the
    /// whole reason to measure: a hand-picked grey that merely looked right
    /// would have put the app's rows a shade away from the one row on the same
    /// screen that iOS presses for us.
    static let rowPressed = Color(.systemGray4)
}

/// The button half of a row press: the target, the haptic, and nothing drawn.
///
/// **A row is a control on five screens** and until item 28 its whole press was
/// whatever `.buttonStyle(.plain)` does — the label composited at 75% over what
/// is behind it, which nobody noticed was there. Item 28 replaced that with a
/// wash and a scale drawn *here*, inside the button, and item 32 moved the
/// drawing out to the cell: see `rowPress(rest:)`, which is where the press now
/// lives and where the argument for splitting them is. What is left in the
/// style is the two things that really do belong to the button.
///
/// **The haptic is one of them, and its open question comes with it.**
/// `pressHaptic` was on three small, deliberate targets — a 30pt disc, a 44pt
/// `+`, the Log pill — and is on every row of five screens, which is most of
/// the app's touch area. A flick does not fire it: the list delays the touch,
/// and a drag started with no pause leaves a settings row at `#1C1C1E` through
/// the whole gesture. A finger that *rests* does — a stationary finger has the
/// row at `#3A3A3C` within 0.3s, and dragging away after that cancels the tap
/// but not the impact it already gave. That is exactly the "press called off"
/// case item 27 recorded and could not judge in a simulator, on a much larger
/// surface; item 17's device pass keeps the haptic or deletes it, and this is
/// the strongest reason it might be deleted.
///
/// **It drops `.plain`'s dimming of a *disabled* label, and that is a trap with
/// six call sites.** `.plain` composites a disabled button's whole label at
/// about 0.5; no custom `ButtonStyle` does, so a `.row` button under
/// `.disabled(…)` draws at full contrast and reads as live. `RepeatRow` is the
/// one that needs it and puts the opacity on by hand — the number and the
/// pixels are in its own comment — and it needs it because item 26 shipped
/// exactly this bug on exactly that row. The same caveat is on
/// `AccentFillButtonStyle`, which after item 28 has no disable-able call site
/// left; this is where it matters now.
struct RowButtonStyle: ButtonStyle {
    /// Where the press goes. Put there by `rowPress()` on the cell, which is
    /// the view that draws it — see that modifier for why the state lives a
    /// level up from the button instead of here.
    @Environment(\.rowPress) private var press

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // **44pt, so the target is one iOS would accept**, and it buys two
            // rows one they did not have: a tracker detail row's label was
            // 40pt and home's *Add Tracker* about 22. What it costs is height
            // on those two — measured against a build with this one line
            // deleted, detail's entry rows go **68pt to 74** and *Add Tracker*
            // **51 to 55**, while every row that already had a 44pt control in
            // it — home's cards, History, the Log again sheet, settings —
            // stays at 52 to the point.
            //
            // It was also what made the old wash the same height on every
            // screen. That reason has gone with the wash: what is drawn now is
            // drawn on the cell, which is the same height by construction.
            .frame(minHeight: 44)
            // The one thing this style does with the press, other than hand it
            // upward: the same feedback the accent fills get, with the same
            // open question on it — see the note on this type about what it
            // puts on item 17's list.
            .pressHaptic(configuration.isPressed)
            // **`onChange`, because a `ButtonStyle` cannot write state while it
            // is being asked what to draw.** Setting `press` inside `makeBody`
            // is a mutation during a view update, which SwiftUI warns about and
            // is entitled to drop. This runs after the update instead, and what
            // it costs is measured in `rowPress()`.
            .onChange(of: configuration.isPressed) { _, isPressed in
                press?.set(isPressed)
            }
    }
}

extension EnvironmentValues {
    /// How a row's button tells the cell it is in that it has been pressed.
    ///
    /// A `ButtonStyle` sees only its own label, and on three of the five
    /// screens that is not the whole row: home's card keeps its `+` outside the
    /// button, History its repeat disc, settings its drag handle. A press drawn
    /// inside the button therefore stopped short of them — **282pt of a
    /// settings card's 366**, measured, with a hard edge where the rest of the
    /// row began. That is the wash item 32 was reported for, and no amount of
    /// styling inside the button reaches past it.
    ///
    /// So the state is owned by `rowPress()`, which is applied to the cell, and
    /// handed *down* to the style through the environment. Down is the only
    /// direction SwiftUI offers here: a preference would go up but arrives a
    /// render later, and a `@State` on every call site is six copies of one
    /// boolean, two of which have nowhere to live because their rows are built
    /// by a method rather than a view.
    ///
    /// **An object rather than a `Binding`, and that is a performance fix
    /// rather than a style** (found in review). SwiftUI compares environment
    /// values to decide what a change invalidates, and `Binding` is not
    /// `Equatable` — so a binding built fresh in `RowPress.body` read as a new
    /// value on every pass and invalidated every row's button subtree with it.
    /// The screen where that bites is settings: a reorder drag updates
    /// `@GestureState` on every touch move, so each row would re-render its
    /// label per frame of a drag that changes nothing below the button.
    /// `RowPressState` is one instance per row, `Equatable` by identity, and
    /// the same value every pass.
    @Entry var rowPress: RowPressState? = nil
}

extension View {

    /// Draw this whole list row going down when the button in it is pressed.
    ///
    /// Applied to the cell — the `HStack`, or whatever the row's outermost view
    /// is — and paired with `.buttonStyle(.row)` on the button inside it.
    /// Without it a `.row` button still takes its 44pt target and its haptic
    /// and draws no press at all, which is the one failure mode of splitting
    /// these in two, and is why every call site names them together.
    ///
    /// - Parameter rest: what the row draws when it is *not* pressed. This
    ///   modifier owns `listRowBackground`, because filling the cell is the
    ///   whole point of it, and a row cannot have two — so the two rows in the
    ///   app that already spent theirs hand it over here instead: home's *Add
    ///   Tracker*, which is deliberately not a card, and a History row, which
    ///   fades an accent wash behind itself after a jump (docs/TODO.md item
    ///   25). The default is the colour an inset-grouped list draws a row in,
    ///   named rather than inherited for the reason above.
    func rowPress(rest: some View = Color(.secondarySystemGroupedBackground)) -> some View {
        modifier(RowPress(rest: rest))
    }
}

/// A row going down under a thumb.
///
/// **The whole cell, not a box behind the text** (docs/TODO.md item 32). Item
/// 28 drew a `Color.rowPressed` wash behind the *button's label*, and that was
/// reported back as reading like a text field — a lighter rounded rectangle
/// appearing around a tracker's name is the shape of a thing you type into, and
/// it stopped dead where the button did, 282pt into a 366pt settings card. What
/// it is now is the row's own background, which the list fills edge to edge and
/// clips to the card exactly as it does for a `NavigationLink` it presses
/// itself. On top of that the cell takes `AccentFillPress`'s 2pt travel, so a
/// card, a pill and a disc all move the same distance — outward since item 37,
/// which is one decision in one function and not a row's to make.
///
/// **It applies on the frame the touch lands** —
/// `AccentFillPress.animation(pressed:)` carries that argument — and on a row
/// that is not enough on its own, which is what `AccentFillPress.minimumHold`
/// is for. Between them, a **40ms** synthesized tap on a settings row now draws
/// the full pressed colour on the first frame after the touch, holds it, and
/// fades out over seven frames; before this item the same tap, and a 150ms one,
/// drew nothing at all. The band, the method and the rest of the numbers are on
/// `minimumHold`.
///
/// **Reduce Motion takes the movement and leaves the colour.** The gate is
/// `AccentFillPress.scale(for:reduceMotion:)`, the same one the fills ask.
/// Checked both ways on one binary rather than by reading the key back, on a
/// held settings row at 3x: with the setting off the row's name starts at
/// x = 98px at rest and x = 92 held — 6 device pixels *outward*, which is the
/// 2pt travel — and with it on the name is at x = 98 in both while the row
/// still fills with `#3A3A3C`. Item 27 took the same reading while the press
/// shrank and the name moved the other way, to x = 105.
///
/// **What owning the row's background costs is two units of blue on one
/// screen.** At rest this draws `rest`, whose default is
/// `Color(.secondarySystemGroupedBackground)` rather than whatever the list
/// would have drawn, and on four of the five screens that is the same byte:
/// home's cards stay `#1C1C1E`. Inside the Log again sheet the list drew
/// `#2C2C2C` and this draws `#2C2C2E`. It is a change and it is written down
/// for that reason; it is not a visible one.
///
/// **The `visualEffect` does not cost the scroll**, which was measured for item
/// 28 when the effect was on the button's label rather than on the cell, and is
/// the reason it is on rows at all in a screen whose row count is your whole
/// history. A `CADisplayLink` in a temporary probe, eight scripted flings over
/// a **3,200-row History** (8,000 entries) on an iPhone 17 Pro simulator, 960
/// frame intervals per run, against a build with only the `visualEffect` line
/// deleted:
///
///     build              median  p95     >20ms          >33ms
///     Debug, with        16.67   16.67   25, 27, 24     18, 18, 17
///     Debug, without     16.67   16.67   20, 21, 24     12, 13, 14
///     Release, with      16.67   16.67   20, 19         14, 12
///     Release, without   16.67   16.67   20, 26         16, 16
///
/// The median and the p95 are a full 60fps frame in every run of both builds.
/// The tails do not separate: Debug leans against the scale by about five
/// frames in 960, Release leans the other way by about the same, so the honest
/// reading is noise rather than a cost. That run is item 28's and has not been
/// repeated for this placement.
private struct RowPress<Rest: View>: ViewModifier {
    /// One per row, for as long as the row exists. See `RowPressState`.
    @State private var press = RowPressState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// See `rowPress(rest:)`.
    let rest: Rest

    func body(content: Content) -> some View {
        // Out of the environment once, into the `@Sendable` closure below, for
        // the reason `AccentFilled` does the same: reaching into main-actor
        // state from inside it is a warning in a target built with strict
        // concurrency complete.
        let isPressed = press.isPressed
        let reduceMotion = reduceMotion
        return content
            .listRowBackground(
                ZStack {
                    rest
                    // An opacity rather than a choice between two backgrounds,
                    // as `SettingsView`'s drop target does one file over: a
                    // fill at zero draws exactly what `.clear` did, and there
                    // is no branch for the release to interpolate across —
                    // which matters here, because the release is the only half
                    // of the press that animates.
                    Color.rowPressed.opacity(isPressed ? 1 : 0)
                }
            )
            // `visualEffect`, not `.scaleEffect`, and for the reason the fills
            // use it: the scale is worked out from the size the row laid out
            // at, and hit testing keeps the unscaled geometry. That mattered
            // more when the press shrank — a thumb at the edge of a row would
            // have fallen out of a target that moved under it — and it is what
            // stops the outward version growing the target instead: what a row
            // responds to is the row, pressed or not.
            .visualEffect { effect, proxy in
                effect.scaleEffect(
                    isPressed
                        ? AccentFillPress.scale(for: proxy.size, reduceMotion: reduceMotion)
                        : 1
                )
            }
            .animation(AccentFillPress.animation(pressed: isPressed), value: isPressed)
            .environment(\.rowPress, press)
    }
}

/// One row's press, and the floor under it.
///
/// **A class so that the environment value is one stable, comparable thing** —
/// see `EnvironmentValues.rowPress` for what a fresh `Binding` there was
/// costing. It also gives the hold below somewhere to keep its two pieces of
/// bookkeeping without either of them being a `@State` that a view has to
/// thread anywhere.
@Observable
@MainActor
final class RowPressState: Equatable {

    /// What the row draws. Written only by `set(_:)`.
    private(set) var isPressed = false

    /// When the press arrived, so a release can wait out
    /// `AccentFillPress.minimumHold`.
    @ObservationIgnored private var since: ContinuousClock.Instant?

    /// Which press a pending release belongs to. A release that wakes up to
    /// find the row pressed again is a release for the press before this one,
    /// and letting it through would blink the row out under a finger that never
    /// lifted.
    @ObservationIgnored private var generation = 0

    /// Take the button's press, and keep it on screen long enough to be seen.
    ///
    /// The press itself is immediate — this never delays one arriving. What it
    /// delays is the *release*, and only when the touch was shorter than
    /// `AccentFillPress.minimumHold`; the argument and the measurement are
    /// there. A tap that outlasts the floor releases on the frame the finger
    /// lifts, which is every press a thumb rests through.
    ///
    /// **It cannot tell a release from a cancellation, and that is a known
    /// edge** (found in review). SwiftUI reports both as the pressed state
    /// going false, so a finger that rests long enough for the list to hand the
    /// touch over — 0.2s to 0.45s, measured for the haptic — and *then* flicks
    /// within the floor leaves the row washed for the rest of it while the list
    /// is already scrolling. It is a narrow window and it is cosmetic, and the
    /// fix would be a second gesture watching for movement, which is the thing
    /// this file has twice decided not to add. **It goes on item 17's list next
    /// to the haptic**, because both are questions about a thumb that a
    /// simulator cannot answer.
    func set(_ isPressed: Bool) {
        guard isPressed else {
            let held = since.map { ContinuousClock.now - $0 } ?? .seconds(1)
            guard held < AccentFillPress.minimumHold else {
                self.isPressed = false
                return
            }
            let generation = generation
            Task { @MainActor in
                try? await Task.sleep(for: AccentFillPress.minimumHold - held)
                guard generation == self.generation else { return }
                self.isPressed = false
            }
            return
        }
        generation += 1
        since = .now
        self.isPressed = true
    }

    /// By identity: two rows are never the same press, and one row's state is
    /// the same object for as long as the row is on screen. This is what the
    /// environment compares.
    nonisolated static func == (lhs: RowPressState, rhs: RowPressState) -> Bool {
        lhs === rhs
    }
}

extension ButtonStyle where Self == RowButtonStyle {

    /// See `RowButtonStyle`. This is what a list row that does something wears,
    /// in place of `.buttonStyle(.plain)` — together with `rowPress()` on the
    /// cell around it, which is what draws the press.
    static var row: RowButtonStyle { RowButtonStyle() }
}
