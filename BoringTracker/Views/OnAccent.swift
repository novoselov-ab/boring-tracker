import SwiftUI

extension Color {

    /// The accent: a fill nearly everywhere, and a foreground only on the two
    /// controls where colour is the OS saying "tappable" — `navBarAccent()` and
    /// `formRowAccent()`.
    ///
    /// **Named `AccentFill`, not `AccentColor`.** A colour set called
    /// `AccentColor` becomes `Color.accentColor` and the default tint of every
    /// standard control in the app, which `BoringTrackerApp` pins to `.primary`
    /// to keep removed. The accent arrives by name or not at all.
    ///
    /// **Anything filled with this needs `Color.onAccent` on top of it.** Both
    /// values are light enough that iOS's own white label measures 1.78:1 on the
    /// dark one, so the pairing is load-bearing rather than a preference.
    static let accentFill = Color("AccentFill")

    /// The accent fill while its control is held down.
    ///
    /// **A pressed accent fill recedes toward the surface it sits on**: light
    /// mode's is white so pressed is lighter, dark mode's is near-black so
    /// pressed is darker. Both values are what iOS itself composited for a
    /// `.plain` button on this accent, not colours picked by hand.
    ///
    /// iOS gets a *prominent* button wrong — in dark mode its press lightens the
    /// fill, moving the opposite way from every other accent fill on the screen
    /// — and one cannot be re-tinted, because a `ButtonStyle` replaces
    /// `.borderedProminent` rather than adding to it. Hence
    /// `AccentPillButtonStyle`.
    static let accentFillPressed = Color("AccentFillPressed")

    /// The accent fill's off state: no accent in it at all, and no hue, because
    /// the one thing a disabled control must not look like is a mint one.
    ///
    /// `.quaternary` was here and measured 1.23:1 against a light History row — a
    /// control that read as nothing rather than as an affordance that is off.
    /// This was **rendered and sampled, not trusted by name**: 2.21:1 and 2.84:1
    /// against those same rows.
    static let accentFillDisabled = Color(.systemGray2)

    /// What goes *on* the accent fill.
    ///
    /// iOS draws a prominent button's label white whatever the tint is, and on
    /// the dark accent that measures **1.78:1** against the 3:1 floor. No accent
    /// this app has shipped could carry it — the teal before was 1.86 and the
    /// blue before that 2.69 — so the label moves rather than the fill.
    ///
    /// Black in both appearances rather than flipped with the mode: the dark
    /// value has no such choice, and a `Log` button whose word changed colour
    /// with the appearance would be two designs for one control.
    static let onAccent = Color.black

    /// What goes on `accentFillDisabled`. It has to flip with the appearance: on
    /// the light grey only a dark glyph clears 2.5:1 and on the dark one only a
    /// light one does. `.secondary` is the obvious middle and fails the light
    /// half at 2.43:1; this measures 9.50 and 5.99.
    static let onAccentDisabled = Color.primary
}

/// Draws a label in `Color.onAccent`, or in `Color.onAccentDisabled` when its
/// control is off.
///
/// Apply it to the button's *label*, inside the `Button`, never to the button
/// from outside: `.disabled(_:)` sets `isEnabled` for its content, so a reader
/// wrapped around the already-disabled button sees the ancestors' environment
/// and always believes it is enabled.
private struct OnAccentFill: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.foregroundStyle(isEnabled ? Color.onAccent : Color.onAccentDisabled)
    }
}

/// True while the button around this view is being held down.
///
/// The pressed colour has to reach a fill drawn *inside* a button's label —
/// `RepeatDisc`, `UndoButton`, a home card's + — and a `ButtonStyle` cannot reach
/// in there. It publishes the state here and the fill reads it back, which is how
/// `\.isEnabled` already travels.
private struct AccentFillPressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var accentFillPressed: Bool {
        get { self[AccentFillPressedKey.self] }
        set { self[AccentFillPressedKey.self] = newValue }
    }
}

/// The accent fill, in whichever of its three states its control is in.
///
/// A `View` and not a `Color`, because two of the three states are read from the
/// environment and a `ShapeStyle` has nowhere to read them from. Private, and
/// reached only through `View.accentFilled(_:)`, which adds the movement — a call
/// site that draws this directly is a control that changes colour without moving.
private struct AccentFillBackground<S: Shape>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accentFillPressed) private var isPressed

    private let shape: S

    init(_ shape: S) {
        self.shape = shape
    }

    var body: some View {
        shape.fill(fill)
    }

    private var fill: Color {
        guard isEnabled else { return .accentFillDisabled }
        return isPressed ? .accentFillPressed : .accentFill
    }
}

/// The accent fill and its press, applied together. See `View.accentFilled(_:)`,
/// which is how this is reached, and `AccentFillPress` for the numbers.
private struct AccentFilled<S: Shape>: ViewModifier {
    @Environment(\.accentFillPressed) private var isPressed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let shape: S

    func body(content: Content) -> some View {
        // Read out of the environment once, into the closure below: it is a
        // `@Sendable` one, and reaching into main-actor state from inside it is a
        // strict-concurrency warning in a project built with it complete.
        let isPressed = isPressed
        let reduceMotion = reduceMotion
        return content
            .background(AccentFillBackground(shape))
            // `visualEffect` rather than `.scaleEffect`: the scale is worked out
            // from what the fill laid out at, without a `GeometryReader` around
            // every control, and it is *only* visual — hit testing keeps the
            // unscaled geometry, where a `.scaleEffect` would grow the target 2pt
            // past the control anybody can see at rest.
            .visualEffect { effect, proxy in
                effect.scaleEffect(
                    isPressed
                        ? AccentFillPress.scale(for: proxy.size, reduceMotion: reduceMotion)
                        : 1
                )
            }
            // Kept on under Reduce Motion, where it is the colour it carries: the
            // scale above is already 1, so what a release animates is the fill
            // crossing back from the pressed value.
            .animation(AccentFillPress.animation(pressed: isPressed), value: isPressed)
    }
}

/// How a press is drawn: the fill moves, because a measured pressed colour alone
/// was still hard to notice.
///
/// **iOS does not do this**, which was checked rather than assumed: held down,
/// `.borderedProminent` renders at the same size and origin as at rest, to the
/// pixel, and changes only its fill. A scale on press is this app's decision.
///
/// **The travel is in points, not a ratio, because the fills are not the same
/// size.** 0.97 takes 4.7pt off each end of a 312pt pill and 0.45pt off a 30pt
/// disc, which is nothing.
enum AccentFillPress {

    /// Points each end of the fill's longest edge travels on a press.
    ///
    /// **2 rather than 3 or 4, and all three were rendered held down.** At 4pt a
    /// disc went 30pt to 22 and lost a quarter of its width, reading as a
    /// different-sized control rather than the same one pressed. Now that the
    /// travel is outward, what bounds it is the room *around* each fill: a pill
    /// that grows past its 16pt margins crowds the screen edge.
    static let travel: CGFloat = 2

    /// The scale for a fill that laid out at this size, or `1` for the three
    /// cases where the fill does not move at all.
    ///
    /// **Reduce Motion is one of them**: the setting takes the movement and
    /// leaves `Color.accentFillPressed`. It is answered here rather than in the
    /// modifiers so that a test can hold it, and so a row and a fill cannot
    /// disagree — `RowButtonStyle` calls this too. A later edit that moves the
    /// gate into a `visualEffect` closure, or drops it, breaks something no
    /// screenshot of a default simulator shows.
    ///
    /// The other two are sizes the rule cannot describe: an unmeasured fill is
    /// `.zero`, and scaling from that draws a control's first frame mid-press;
    /// and a fill shorter than the 4pt this adds more than doubles on a press.
    /// Nothing in the app is within 26pt of that, and it is guarded because a
    /// fifth fill added later is who would find it.
    static func scale(for size: CGSize, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion else { return 1 }
        let longest = max(size.width, size.height)
        guard longest > 2 * travel else { return 1 }
        return 1 + 2 * travel / longest
    }

    /// The press is not animated. Only the release is.
    ///
    /// A pressed colour could not be seen, and a scale on top of it still could
    /// not. The mechanism was not the problem either time — the *timing* was: the
    /// curve took 66ms to settle going down, and a tap is shorter than that, so a
    /// tap reversed a press that had never arrived.
    ///
    /// **A function of the value being moved *to*, not the one being left**:
    /// `.animation(_:value:)` takes its animation from the same body evaluation
    /// as the new value.
    static func animation(pressed: Bool) -> Animation? {
        pressed ? nil : release
    }

    /// What a release takes, and the only animation left in a press. Measured at
    /// **82ms** off a 60fps capture — the tail of an easeOut is sub-pixel, so
    /// less of it shows than is asked for.
    static let release: Animation = .easeOut(duration: 0.12)

    /// How long a press stays on screen once it has arrived, however briefly the
    /// finger was down.
    ///
    /// **A fast tap is two frames, and two frames is not a pressed state.** This
    /// was first needed because a list withheld the touch and handed a short tap
    /// over as its down and up inside one update, so there was nothing to draw at
    /// all; `BoringTrackerApp.init` has since turned that delay off, and what is
    /// left is the ordinary case of a 40ms tap on a 60Hz screen.
    ///
    /// **What it costs is a flick.** A press cancelled by the list starting to
    /// scroll is held here for the rest of the floor — see `RowPressState.set`.
    ///
    /// **A floor rather than a duration**, and only rows have one — the fills
    /// never did. What made a row different was that its touch arrived late;
    /// item 40 took that delay away, so whether a row still needs a floor is an
    /// open question there.
    static let minimumHold: Duration = .milliseconds(100)
}

/// For a `.plain`-shaped button whose label draws its own accent fill: it hands
/// `configuration.isPressed` to the `AccentFillBackground` inside.
///
/// What it deliberately does not do is `.plain`'s own press effect, the whole
/// label at 75% opacity, because that is the surface-dependent composite
/// `Color.accentFillPressed` replaced with a named colour — applying both would
/// fade the pressed value a second time. It also drops `.plain`'s dimming of a
/// *disabled* label, which nothing here hits; `RowButtonStyle` carries that
/// caveat for the six call sites that do.
struct AccentFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.accentFillPressed, configuration.isPressed)
            .pressHaptic(configuration.isPressed)
    }
}

/// The app's prominent button: a filled capsule with a dark label.
///
/// **This is `.borderedProminent` redrawn rather than restyled.** A pressed
/// prominent button is dimmed by iOS itself and a `ButtonStyle` cannot change
/// that — applying one *replaces* `.borderedProminent`, and the tint is read
/// before the press effect is composited — so the fill is drawn here and all
/// three states come from `AccentFillBackground` like everything else.
///
/// The metrics are iOS's own, matched off the build before this. The 12pt
/// horizontal padding is a measurement and not a round number — 11 drew the log
/// sheet's *Log* exactly 2pt narrow.
struct AccentPillButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: minHeight)
            .accentFilled(.capsule)
            // The target is the capsule the pill lays out at rather than the
            // larger one it is drawn at while held — and what makes that true is
            // `visualEffect` being visual only, not the fact that this line comes
            // after it. An enclosing scale would transform this shape too, so a
            // later swap to a plain `.scaleEffect` would keep the ordering while
            // quietly breaking the target.
            //
            // That leaves a 2pt rim drawn and not targeted. A thumb that drifts
            // onto it keeps the control: pressed at x = 17pt and dragged out to
            // 15, the pill stays pressed and the release opens the log sheet.
            .contentShape(.capsule)
            .environment(\.accentFillPressed, configuration.isPressed)
            .pressHaptic(configuration.isPressed)
    }

    /// `.mini` and `.extraLarge` follow their neighbours and are unmeasured —
    /// nothing asks for them, and a made-up number would look exactly like a
    /// measured one.
    private var minHeight: CGFloat {
        switch controlSize {
        case .mini, .small: 28
        case .large, .extraLarge: 50
        default: 34
        }
    }

    /// Half of what iOS left either side of the label, which is the only part of
    /// the width this style decides — home's pill is stretched by its own
    /// `maxWidth: .infinity` and does not use these.
    private var horizontalPadding: CGFloat {
        switch controlSize {
        case .mini, .small: 10
        case .large, .extraLarge: 20
        default: 12
        }
    }

    /// `.subheadline` at the small size, because iOS shrinks the label there too:
    /// *Add Tracker* renders an 11.00pt cap height against 12.33 at the default
    /// size. Padding alone cannot match a control whose text is a different size,
    /// which is how that button first came back 13pt too wide.
    private var font: Font? {
        switch controlSize {
        case .mini, .small: .subheadline
        default: nil
        }
    }
}

extension ButtonStyle where Self == AccentFillButtonStyle {

    /// See `AccentFillButtonStyle`.
    static var accentFill: AccentFillButtonStyle { AccentFillButtonStyle() }
}

extension ButtonStyle where Self == AccentPillButtonStyle {

    /// See `AccentPillButtonStyle`.
    static var accentPill: AccentPillButtonStyle { AccentPillButtonStyle() }
}

/// The app's recovery control, drawn one way wherever it appears: a 32pt fill
/// inside a 44pt target, so it does not set the height of the bar or row it lands
/// in. A bare `Button("Undo")` is hit only where the word is drawn, which was
/// half the size of the mistake it exists to fix.
struct UndoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Undo")
                .onAccentFill()
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .accentFilled(.capsule)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        // `.accentFill`, which is `.plain` plus the one thing `.plain` cannot do:
        // hand the press down to the capsule inside the label.
        .buttonStyle(.accentFill)
    }
}

/// "Log this again", drawn one way in the three places the action reaches —
/// home's bottom bar, a History row, a row in the Log again sheet.
///
/// **The glyph carries a plus**, because the tap logs something rather than
/// merely repeating it, and `plus.arrow.trianglehead.clockwise` is one symbol
/// rather than a plus composited onto `arrow.clockwise`: it scales, mirrors and
/// takes a weight on its own. No repeat-ish symbol has a `.badge.plus` variant —
/// there are 64 `.badge.plus` symbols in iOS 26.3's CoreGlyphs and not one is an
/// arrow, a clock or a rotate — and this one is available from iOS 18.0, the
/// deployment target.
///
/// Disabled off `\.isEnabled` rather than a parameter, so a caller says
/// `.disabled(…)` once on its button and the disc follows. **Read from inside the
/// button's label**, which is where this always sits — see `OnAccentFill`.
struct RepeatDisc: View {
    /// Named once so the three call sites cannot drift again — and so the Log
    /// again sheet's empty state can draw the same one.
    static let symbol = "plus.arrow.trianglehead.clockwise"

    /// 30 on a row, where this is one control at the end of something else, and
    /// 50 in home's bottom bar, where it is one of the two things on the screen
    /// and has to agree with the pill beside it.
    var diameter: CGFloat = 30

    /// **Not derived from `diameter`, because it is not proportional to it.** Read
    /// off the photograph the user picked: the bar's 50pt circle carries a glyph
    /// whose ink measures 20.3 × 22.3pt against 14.3 × 15.7 on a 30pt row disc —
    /// the circle grows by 1.67 and the glyph by 1.42. A proportional glyph would
    /// be `size: 23` and fills the circle in a way the chosen rendering does not.
    var glyph: CGFloat = 14

    /// Drawn as a checkmark for the second after the Log again sheet has written
    /// something. **Home's bar is the only caller**: a repeat counts its number up
    /// at the top of a screen that was behind the sheet you were looking at, so
    /// the disc the sheet came *out* of says it instead, under the thumb that just
    /// tapped.
    ///
    /// **Not on the row inside the sheet, which was tried first and cannot work**:
    /// `dismiss()` outruns it — see `HomeView`'s `loggedAgain`.
    ///
    /// **No `contentTransition`.** `.symbolEffect(.replace)` was built and
    /// recorded first and takes about 300ms of a 60fps capture to finish, a third
    /// of the second the mark is up spent not yet being a checkmark.
    var confirmed = false

    var body: some View {
        Image(systemName: confirmed ? "checkmark" : Self.symbol)
            // Fixed rather than a text style: the disc and its target do not
            // scale, so a glyph that does outgrows its own circle at the
            // accessibility sizes.
            .font(.system(size: glyph, weight: .bold))
            .onAccentFill()
            .frame(width: diameter, height: diameter)
            // `accentFilled`, not `.tint`: the environment tint is the ordinary
            // label colour, and a disc is a fill. The modifier carries all three
            // states and the press, so a disc behaves the same way in all three
            // places it appears.
            .accentFilled(.circle)
            // 44 where the circle is smaller, and the circle itself where it is
            // not: a target under 44 is one Apple would object to, and one
            // *larger* than the thing it belongs to steals the gap beside it.
            .frame(width: max(44, diameter), height: max(44, diameter))
            .contentShape(.rect)
    }
}

extension View {

    /// For the label of a control filled with the accent — a prominent button, or
    /// the small discs that are the same idiom in miniature.
    func onAccentFill() -> some View {
        modifier(OnAccentFill())
    }

    /// Fill this label with the accent, in whichever of its three states its
    /// control is in, and let it move when the control is pressed.
    ///
    /// Apply it to whatever the fill is drawn behind, and put the control's
    /// `contentShape` and its 44pt target *outside* it: the scale is drawn on the
    /// fill and the target does not move with it.
    ///
    /// **Which means the fill is drawn 2pt past its own target while it is held.**
    /// Not a bug to fix at the call site — a press is what makes the rim appear,
    /// so nobody aims at it, and a touch that drifts onto it keeps the control
    /// (`AccentPillButtonStyle` carries the check). What it does mean is that a
    /// fifth fill must not read its own held size back as a target.
    func accentFilled<S: Shape>(_ shape: S) -> some View {
        modifier(AccentFilled(shape: shape))
    }

    /// A light impact as a control takes a press.
    ///
    /// **Feedback, not celebration**: `PHILOSOPHY.md` bans haptic celebrations,
    /// and this is the physical half of a control answering a thumb, at the moment
    /// of the press rather than of the result.
    ///
    /// **A scroll fires it now, and that used to be the reason this was safe.** A
    /// list held a row's touch back until the gesture had already declared itself
    /// a scroll, so a flick never entered the pressed state; `BoringTrackerApp`
    /// turned that delay off (docs/TODO.md item 40) and a flick that starts on a
    /// row now presses it, briefly, on the way. Since a whole `RepeatRow` is a
    /// button, that is most of the app's touch area.
    ///
    /// **Whether either half helps is unanswered**: the simulator has no haptics,
    /// so this shipped unfelt, and item 17 is the pass that keeps it or deletes
    /// it.
    func pressHaptic(_ isPressed: Bool) -> some View {
        sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isPressed) { _, pressed in
            pressed
        }
    }

    /// A success notification as a log lands — the answer to "did that go in?" for
    /// a tap whose visible result is drawn on a screen behind the one you are
    /// looking at.
    ///
    /// **Takes what was written rather than a flag**, because a `Bool` serves only
    /// the caller that clears it: History never does, so an earlier repeat would
    /// leave it `true` and the next tap would arrive in silence.
    ///
    /// **Not `lastLoggedAgainAt`, which both call sites used first.** It looks
    /// like the same thing and has one-second resolution — `Date.stamp()`
    /// canonicalises to whole seconds so the store file is lossless — so two
    /// repeats inside one second are the same `Date` and the second is silent.
    /// Both pass `Store.lastLoggedAgainRow`, which carries a fresh batch id.
    func logHaptic<Wrote: Equatable>(_ wrote: Wrote?) -> some View {
        sensoryFeedback(.success, trigger: wrote) { _, wrote in wrote != nil }
    }

    /// The accent back on a **nav bar button**, and nowhere else.
    ///
    /// **`.tint`, and it has to be `.tint` here** — which is the one thing that
    /// stops this and `formRowAccent()` being one modifier. A nav bar button can
    /// be disabled (`TrackerEditor`'s *Save* with an empty name), and a tint is
    /// dropped for a disabled bar button, which is the whole point.
    /// `.foregroundStyle` is *not* dropped: measured on that same disabled *Save*,
    /// it draws the full accent and the button reads as tappable when it is not.
    ///
    /// Per button rather than at the root: the root tint stays `.primary`, so a
    /// foreground use of the accent cannot appear by inheritance the way it did
    /// twice before.
    func navBarAccent() -> some View {
        tint(Color.accentFill)
    }

    /// The accent on a **`Form` action row** — a `Button` or a `ShareLink` in the
    /// settings list that does something rather than going somewhere.
    ///
    /// **A `Button` in a `Form` has no disclosure chevron**, so a row with its
    /// label and icon in the ordinary label colour is pixel-identical to a static
    /// one. The affordance here is colour or it is nothing.
    ///
    /// **`.foregroundStyle`, not `.tint`, and both halves were measured.** Under
    /// iOS 26 a tinted `Form` row draws its *text* in the tint and leaves the SF
    /// Symbol at the label colour; `.foregroundStyle` takes the glyph with it. It
    /// also survives being disabled *here*, where a tint does not: a disabled row
    /// under `.tint` drops the accent entirely and draws plain black, while
    /// `.foregroundStyle` dims to a 50% blend that reads as off. The opposite is
    /// true one modifier up, which is why there are two of these and not one.
    ///
    /// **Per row rather than on the `Section`**, because *Delete All Data…* must
    /// keep the red its `role` gives it, and so must anything destructive added
    /// later.
    func formRowAccent() -> some View {
        foregroundStyle(Color.accentFill)
    }
}
