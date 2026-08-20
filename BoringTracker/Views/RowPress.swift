import SwiftUI

extension Color {

    /// What a list row goes while it is held down.
    ///
    /// **iOS's own answer, read off iOS rather than chosen.** The app's rows are
    /// `.plain` buttons and have no pressed state of their own, but settings has
    /// one row the platform draws itself — the `NavigationLink` to *About* — and
    /// that row does press. Sampled mid-press it draws `#D1D1D6` on light and
    /// `#3A3A3C` on dark, which are `UIColor.systemGray4` exactly in both
    /// appearances. So this is that colour rather than a match for it, and the
    /// app's rows cannot end up a shade away from the one row on the same screen
    /// iOS presses for us.
    static let rowPressed = Color(.systemGray4)
}

/// The button half of a row press: the target, the haptic, and nothing drawn.
/// The drawing is `rowPress(rest:)`, on the cell.
///
/// **It drops `.plain`'s dimming of a *disabled* label, and that is a trap with
/// six call sites.** `.plain` composites a disabled button's whole label at
/// about 0.5; no custom `ButtonStyle` does, so a `.row` button under
/// `.disabled(…)` draws at full contrast and reads as live. `RepeatRow` is the
/// one that needs it and puts the opacity on by hand.
struct RowButtonStyle: ButtonStyle {
    /// Where the press goes. Put there by `rowPress()` on the cell, which is
    /// the view that draws it.
    @Environment(\.rowPress) private var press

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // **44pt, so the target is one iOS would accept**, and it buys two
            // rows one they did not have: a tracker detail row's label was 40pt
            // and home's *Add Tracker* about 22. What it costs is height on
            // those two — measured against a build with this one line deleted,
            // detail's entry rows go **68pt to 74** and *Add Tracker* **51 to
            // 55**, while every row that already had a 44pt control in it stays
            // at 52 to the point.
            .frame(minHeight: 44)
            .pressHaptic(configuration.isPressed)
            // **`onChange`, because a `ButtonStyle` cannot write state while it
            // is being asked what to draw.** Setting `press` inside `makeBody`
            // is a mutation during a view update, which SwiftUI warns about and
            // is entitled to drop. This runs after the update instead.
            .onChange(of: configuration.isPressed) { _, isPressed in
                press?.set(isPressed)
            }
    }
}

extension EnvironmentValues {
    /// How a row's button tells the cell it is in that it has been pressed.
    ///
    /// A `ButtonStyle` sees only its own label, and on three of the five screens
    /// that is not the whole row: home's card keeps its `+` outside the button,
    /// History its repeat disc, settings its drag handle. A press drawn inside
    /// the button therefore stopped short of them — **282pt of a settings card's
    /// 366**, measured, with a hard edge where the rest of the row began.
    ///
    /// So the state is owned by `rowPress()` on the cell and handed *down*
    /// through the environment. Down is the only direction SwiftUI offers here:
    /// a preference would go up but arrives a render later, and a `@State` on
    /// every call site is six copies of one boolean, two of which have nowhere
    /// to live because their rows are built by a method rather than a view.
    ///
    /// **An object rather than a `Binding`, and that is a performance fix rather
    /// than a style.** SwiftUI compares environment values to decide what a
    /// change invalidates, and `Binding` is not `Equatable` — so a binding built
    /// fresh in `RowPress.body` read as a new value on every pass and
    /// invalidated every row's button subtree with it. The screen where that
    /// bites is settings: a reorder drag updates `@GestureState` on every touch
    /// move, so each row would re-render its label per frame of a drag that
    /// changes nothing below the button.
    @Entry var rowPress: RowPressState? = nil
}

extension View {

    /// Draw this whole list row moving under the thumb when the button in it is
    /// pressed. `AccentFillPress` owns the distance and the direction.
    ///
    /// Applied to the cell — the `HStack`, or whatever the row's outermost view
    /// is — and paired with `.buttonStyle(.row)` on the button inside it.
    /// Without it a `.row` button still takes its 44pt target and its haptic and
    /// draws no press at all, which is why every call site names them together.
    ///
    /// - Parameter rest: what the row draws when it is *not* pressed. This
    ///   modifier owns `listRowBackground`, and a row cannot have two — so the
    ///   two rows in the app that already spent theirs hand it over here
    ///   instead: home's *Add Tracker*, which is deliberately not a card, and a
    ///   History row, which fades an accent wash behind itself after a jump.
    func rowPress(rest: some View = Color(.secondarySystemGroupedBackground)) -> some View {
        modifier(RowPress(rest: rest))
    }
}

/// A row moving under a thumb.
///
/// **The whole cell, not a box behind the text.** A `Color.rowPressed` wash
/// behind the *button's label* was reported back as reading like a text field —
/// a lighter rounded rectangle appearing around a tracker's name is the shape of
/// a thing you type into — and it stopped dead where the button did, 282pt into
/// a 366pt settings card. What is drawn now is the row's own background, which
/// the list fills edge to edge and clips to the card exactly as it does for a
/// `NavigationLink` it presses itself.
///
/// **It applies on the frame the touch lands**, and on a row that is not enough
/// on its own — see `AccentFillPress.minimumHold`. Between them, a **40ms**
/// synthesized tap on a settings row draws the full pressed colour on the first
/// frame after the touch, holds it, and fades out over seven frames; before
/// this, the same tap and a 150ms one drew nothing at all.
///
/// **Reduce Motion takes the movement and leaves the colour**, through
/// `AccentFillPress.scale(for:reduceMotion:)` — the same gate the fills ask.
/// Checked both ways on one binary on a held settings row at 3x: with the
/// setting off the row's name moves 6 device pixels outward, which is the 2pt
/// travel; with it on the name does not move while the row still fills with
/// `#3A3A3C`.
///
/// **What owning the row's background costs is two units of blue on one
/// screen.** At rest this draws `rest` rather than whatever the list would have
/// drawn, and on four of the five screens that is the same byte. Inside the Log
/// again sheet the list drew `#2C2C2C` and this draws `#2C2C2E`.
private struct RowPress<Rest: View>: ViewModifier {
    @State private var press = RowPressState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// See `rowPress(rest:)`.
    let rest: Rest

    func body(content: Content) -> some View {
        // Out of the environment once, into the `@Sendable` closure below:
        // reaching into main-actor state from inside it is a warning in a target
        // built with strict concurrency complete.
        let isPressed = press.isPressed
        let reduceMotion = reduceMotion
        return content
            .listRowBackground(
                ZStack {
                    rest
                    // An opacity rather than a choice between two backgrounds: a
                    // fill at zero draws exactly what `.clear` did, and there is
                    // no branch for the release to interpolate across — which
                    // matters here, because the release is the only half of the
                    // press that animates.
                    Color.rowPressed.opacity(isPressed ? 1 : 0)
                }
            )
            // `visualEffect`, not `.scaleEffect`, and for the reason the fills
            // use it: the scale is worked out from the size the row laid out at,
            // and hit testing keeps the unscaled geometry. What a row responds
            // to is the row, pressed or not.
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
/// costing.
@Observable
@MainActor
final class RowPressState: Equatable {

    /// What the row draws. Written only by `set(_:)`.
    private(set) var isPressed = false

    /// When the press arrived, so a release can wait out
    /// `AccentFillPress.minimumHold`.
    @ObservationIgnored private var since: ContinuousClock.Instant?

    /// Which press a pending release belongs to. A release that wakes up to find
    /// the row pressed again is a release for the press before this one, and
    /// letting it through would blink the row out under a finger that never
    /// lifted.
    @ObservationIgnored private var generation = 0

    /// Take the button's press, and keep it on screen long enough to be seen.
    ///
    /// The press itself is immediate — this never delays one arriving. What it
    /// delays is the *release*, and only when the touch was shorter than
    /// `AccentFillPress.minimumHold`, where the measurement is.
    ///
    /// **It cannot tell a release from a cancellation.** SwiftUI reports both as
    /// the pressed state going false, so a flick that starts on a row leaves that
    /// row washed while the list is already scrolling. That used to be rare,
    /// because the list withheld the touch until the flick had already been
    /// recognised as a scroll; since `BoringTrackerApp.init` turned that delay
    /// off it happens on every flick that starts on a row, and docs/TODO.md item
    /// 40 has the measurement. Still cosmetic, and the fix is still a second
    /// gesture watching for movement, which this file has now three times
    /// decided not to add.
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

    /// By identity: two rows are never the same press, and one row's state is the
    /// same object for as long as the row is on screen. This is what the
    /// environment compares.
    nonisolated static func == (lhs: RowPressState, rhs: RowPressState) -> Bool {
        lhs === rhs
    }
}

extension ButtonStyle where Self == RowButtonStyle {

    /// See `RowButtonStyle`. Wear it together with `rowPress()` on the cell
    /// around the button, which is what draws the press.
    static var row: RowButtonStyle { RowButtonStyle() }
}
