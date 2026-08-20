import SwiftUI

extension Color {

    /// The accent. A fill nearly everywhere, and a foreground on the two
    /// controls where colour is the OS saying "tappable" rather than the app
    /// writing in colour — see `navBarAccent()` and `formRowAccent()`.
    ///
    /// **A colour set with two deliberate values, because one mint could not
    /// serve both appearances** (docs/TODO.md item 18). Until this it was
    /// `Color(.systemMint)`, chosen from twelve candidates measured on these
    /// screens — but that comparison was dark-mode only, at the user's
    /// direction, because dark is what this app is used in. Light was measured
    /// afterwards and the mint failed it, on both of the places the accent is a
    /// foreground rather than a fill:
    ///
    ///     appearance  fill      bar glyph   Form row fg   black label
    ///     light       #00C8B3   2.05        2.12          9.91
    ///     dark        #00DAC3   9.89        9.57          11.82
    ///
    /// Against the 3:1 floor a UI element needs, and against the system blue
    /// Apple ships and tuned for, which measures 3.41 and 3.52 on those same
    /// two surfaces in light. So the light value is not the system mint any
    /// more; it is `#009888`, and the dark value is the system mint's own
    /// `#00DAC3`, written out so both halves are explicit.
    ///
    /// **`#009888` is the system mint darkened, not a new hue.** Same hue
    /// (173.7°) and the same full saturation as `Color(.systemMint)`, taken
    /// down in brightness only, and taken down exactly as far as it had to go:
    /// it measures **3.48** as a bar glyph and **3.59** as a Form row
    /// foreground, which is what the system blue control measures on those
    /// surfaces (3.41, 3.52). Two neighbours were rendered and rejected —
    /// `#00A493` clears the bar by 0.02 and `#009081` is deeper than the mint
    /// needs to be. As a fill it still carries the black `Color.onAccent` at
    /// **5.85**, against system blue's 5.97.
    ///
    /// **Dark did not change.** The dark value is the byte the system mint
    /// already rendered: the settings screen before and after is a
    /// byte-identical PNG, and home differs only in six near-black
    /// anti-aliasing pixels off by one.
    ///
    /// **Named `AccentFill`, not `AccentColor`.** A colour set called
    /// `AccentColor` becomes `Color.accentColor` and the default tint of every
    /// standard control in the app, which is the inheritance item 13c removed
    /// and `BoringTrackerApp` pins to `.primary` to keep removed. The accent
    /// arrives here by name or not at all.
    ///
    /// **Anything filled with this needs `Color.onAccent` on top of it.** Both
    /// values are light enough that iOS's own white label is illegal on the
    /// dark one — 1.78:1 — so the pairing below is load-bearing rather than a
    /// preference, and it is what makes a light accent legal at all.
    static let accentFill = Color("AccentFill")

    /// The accent fill while its control is held down.
    ///
    /// **A pressed accent fill recedes toward the surface it sits on.** Light
    /// mode's surface is white, so pressed is lighter; dark mode's is
    /// near-black, so pressed is darker. That is the whole rule, and it is why
    /// the two values below move in opposite directions from `accentFill`
    /// rather than both darkening (docs/TODO.md item 26).
    ///
    /// **Neither value is invented.** They are what iOS already rendered for a
    /// `.plain` button on this accent — a press there composites the fill at
    /// 75% over what is behind it, and `#009888` at 75% over white is exactly
    /// `#40B2A6` while `#00DAC3` at 75% over the card's `#1C1C1E` is `#07AA9A`,
    /// both confirmed to the byte off screenshots of a real press. So the three
    /// controls that were already right keep their exact appearance; naming the
    /// values makes them a decision instead of a side effect of whatever
    /// happens to be behind the button.
    ///
    /// **The one that was wrong was the prominent Log button in dark mode.**
    /// Pressed, iOS drew it `#33E1CF` — the fill at 80% under a white wash —
    /// which is **1.08:1** against its own rest colour and *lighter*, while
    /// every other accent fill on the same screen darkened. Measured pressed
    /// against rest, across the whole screen:
    ///
    ///     appearance  control    style               rest      pressed   ratio
    ///     light       Log pill   .borderedProminent  #009888   #3FB0A5   1.36
    ///     light       card disc  .plain              #009888   #40B2A6   1.39
    ///     light       Log again  .plain              #009888   #3FB1A5   1.38
    ///     dark        Log pill   .borderedProminent  #00DAC3   #33E1CF   1.08
    ///     dark        card disc  .plain              #00DAC3   #07AA9A   1.64
    ///     dark        Log again  .plain              #00DAC3   #05A897   1.68
    ///
    /// A prominent button cannot be re-tinted on press — a `ButtonStyle`
    /// replaces `.borderedProminent` rather than adding to it — so matching it
    /// means drawing the fill, which is what `AccentPillButtonStyle` does.
    static let accentFillPressed = Color("AccentFillPressed")

    /// The accent fill's off state: no accent in it at all.
    ///
    /// `.quaternary` was here, and it drew **`#E8E8E8` on the History row's
    /// `#FFFFFF` — 1.23:1**, and `#313132` on the dark row's `#1C1C1E` at
    /// 1.31:1. That is the "nearly invisible" docs/TODO.md item 26 was
    /// reported for. A disabled control should read as an affordance that is
    /// off, not as nothing.
    ///
    /// `.systemGray2` **rendered and sampled, not trusted by name**: it draws
    /// `#AEAEB2` on the light row and `#636366` on the dark one, which measure
    /// **2.21:1 and 2.84:1** against History's rows. Both clear the 1.8:1 this
    /// was aimed at, and both stay well under the enabled fill's 3.59:1 and
    /// 9.57:1, so off still reads quieter than on. A grey with no hue in it,
    /// because the one thing a disabled control must not look like is a mint
    /// one.
    ///
    /// **The 1.8 is met on the rows it was measured against, and not on every
    /// row in the app** (found in review, on the screen this was not sampled
    /// on). The Log again sheet is a `.medium` detent whose inset-grouped rows
    /// are `#DBDBDD` in light and `#2C2C2C` in dark, not white and near-black,
    /// and an archived row's disc measures **1.60:1** there in light — under
    /// the aim — and 2.33:1 in dark. It is left as it is: no fixed grey clears
    /// 1.8 on both `#FFFFFF` and `#DBDBDD` without arriving at `.systemGray`,
    /// which is 2.36 on the sheet but **3.26 on white against the enabled
    /// fill's 3.59**, and a disabled control that loud is the opposite
    /// mistake. The glyph on top of it is 9.50 either way, so what the sheet
    /// loses is the disc's edge and not the control.
    ///
    /// Two neighbours were ruled out arithmetically, from Apple's own sRGB
    /// values rather than from a render: `.systemGray3` is the nearer grey and
    /// misses at 1.68:1 on white, and `.systemGray` clears both but is nearly
    /// as loud as the accent itself in light — 3.26:1 against 3.59 — which is
    /// the opposite mistake.
    static let accentFillDisabled = Color(.systemGray2)

    /// What goes *on* the accent fill.
    ///
    /// The accent fill in dark mode is a light mint, `#00DAC3`, and iOS draws a
    /// prominent button's label white whatever the tint is. That pairing
    /// measures **1.78:1**, against the 3:1 floor a UI element needs, on the one
    /// screen this app exists to be glanced at one-handed (docs/TODO.md item
    /// 13b). The teal before it was 1.86:1 and the blue before that 2.69:1, so
    /// no accent this app has ever shipped could carry the label iOS wants to
    /// draw in the appearance it is used in.
    ///
    /// The fill is light, so the label moves rather than the fill: black on it
    /// measures **11.82:1** in dark — 9.57:1 if the label is softened to the
    /// `#1C1C1E` the cards use — and light-fill-with-dark-label is ordinary
    /// current practice rather than a workaround.
    ///
    /// **This is the load-bearing half of the accent, not a detail of it.**
    /// `Color.accentFill` is legal *because* this is black; put white back and
    /// the accent goes under the floor in dark mode everywhere at once. See the
    /// coupling noted above it.
    ///
    /// **Still black, and item 18's colour set is the reason to say why again.**
    /// The light value is now `#009888`, dark enough that iOS's white label
    /// would in fact be legal on it — 3.59:1 — so for the first time a label
    /// that flipped with the appearance would clear the floor in both. It stays
    /// black anyway, and not out of inertia: what sits on the accent is decided
    /// by the accent, not by the mode, and the dark value has no such choice at
    /// 1.78:1. A `Log` button whose word changed colour with the appearance
    /// would be two designs for one control, bought for nothing — black
    /// measures **5.85:1** on the light fill and 11.82:1 on the dark one, and
    /// clears the floor on both.
    static let onAccent = Color.black

    /// What goes on `accentFillDisabled`.
    ///
    /// The ordinary label colour, and it has to flip with the appearance: on
    /// `#AEAEB2` only a dark glyph clears 2.5:1 and on `#636366` only a light
    /// one does. Sampled off a disabled History disc it draws `#000000` and
    /// `#FFFFFF`, which measure **9.50:1** and **5.99:1** against the grey
    /// under them — where `.tertiary`, which `RepeatDisc` drew before this,
    /// rendered `#CBCBCB` on `#E8E8E8` for **1.32:1** and was the second half
    /// of a disc you could not see.
    ///
    /// `.secondary` was the obvious middle and is ruled out by the light half
    /// alone. Composited over the same two greys — `UIColor.secondaryLabel` is
    /// `#3C3C43` at 60% in light and `#EBEBF5` at 60% in dark — it draws
    /// `#6A6A6F` on `#AEAEB2` for **2.43:1**, under the 2.5 above, and
    /// `#B5B5BC` on `#636366` for **2.94:1**, which clears it.
    ///
    /// **That dark number read 2.29 here and was arithmetic that did not work
    /// out** (found in review, recomputed from the same two values that give
    /// the light figure exactly). It does not move the answer: one colour has
    /// to serve both appearances, light is where `.secondary` fails, and the
    /// label colour clears both by a distance — 9.50 and 5.99 against 2.43 and
    /// 2.94.
    static let onAccentDisabled = Color.primary
}

/// Draws a label in `Color.onAccent`, or in `Color.onAccentDisabled` when its
/// control is off.
///
/// It used to stand aside for a disabled control instead of colouring it, and
/// that was right while iOS drew the disabled state: a **disabled**
/// `.borderedProminent` button is built from a neutral fill and never touches
/// the tint, so forcing the label black there painted black on black, and the
/// log sheet opens in exactly that state with every field still empty. Since
/// item 26 the app draws all three states itself — `AccentPillButtonStyle` and
/// `AccentFillBackground` — so there is no longer an iOS drawing to stand
/// aside for, and a label left alone on the grey fill would be the only part
/// of the control nothing had decided.
///
/// Apply it to the button's *label*, inside the `Button`, never to the button
/// from outside. `.disabled(_:)` sets `isEnabled` for its content, so a reader
/// wrapped around the already-disabled button sees the environment of the
/// ancestors instead and always believes it is enabled.
private struct OnAccentFill: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.foregroundStyle(isEnabled ? Color.onAccent : Color.onAccentDisabled)
    }
}

/// True while the button around this view is being held down.
///
/// **The pressed colour has to reach a fill drawn inside a button's label** —
/// `RepeatDisc`, `UndoButton`, a home card's + — and a `ButtonStyle` cannot
/// reach in there. It publishes the state here and the fill reads it back,
/// which is exactly how the disabled state already travels: `\.isEnabled`,
/// read from inside the label.
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
/// **A `View` and not a `Color`, because two of the three states are read from
/// the environment** and a `ShapeStyle` has nowhere to read them from. Every
/// accent-filled control in the app backs itself with this, so "pressed" and
/// "off" are one decision in one place rather than six.
///
/// Private, and reached only through `View.accentFilled(_:)`: item 27 added a
/// second half to a press and a call site that draws this directly is a
/// control that changes colour without moving.
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

/// The accent fill and its press, applied together.
///
/// See `View.accentFilled(_:)`, which is how this is reached, and
/// `AccentFillPress` for the numbers.
private struct AccentFilled<S: Shape>: ViewModifier {
    @Environment(\.accentFillPressed) private var isPressed
    /// The press is a movement, so it is the second thing in the app that has
    /// to ask — see `AccentFillPress.scale(for:reduceMotion:)`, which is where
    /// the answer is applied so that a test can hold it.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let shape: S

    func body(content: Content) -> some View {
        // Read out of the environment once, into the closure below: it is a
        // `@Sendable` one, and reaching into main-actor state from inside it is
        // a strict-concurrency warning in a project built with it complete.
        let isPressed = isPressed
        let reduceMotion = reduceMotion
        return content
            .background(AccentFillBackground(shape))
            // `visualEffect` rather than a plain `.scaleEffect`, for the size:
            // the scale is worked out from what the fill laid out at, and this
            // is the way to read that without a `GeometryReader` around every
            // control. It is also *only* visual — hit testing keeps the
            // unscaled geometry, which a `.scaleEffect` would not: it moved the
            // target out from under a resting thumb while the press shrank, and
            // since item 37 it would grow a target 2pt past the control anybody
            // can see at rest.
            .visualEffect { effect, proxy in
                effect.scaleEffect(
                    isPressed
                        ? AccentFillPress.scale(for: proxy.size, reduceMotion: reduceMotion)
                        : 1
                )
            }
            // **Nothing going down, 0.12s coming back**, which is item 32 and
            // is argued in `AccentFillPress.animation(pressed:)`. The fill
            // reaches `Color.accentFillPressed` on the frame the touch lands,
            // and the ramp that used to be there — seven frames of it, recorded
            // at 60fps for item 27 — is now only on the release.
            //
            // Kept on under Reduce Motion, and it is the colour it carries
            // then: the scale above is already 1, so what a release animates is
            // `AccentFillBackground`'s fill crossing back from the pressed
            // value. Turning this off as well would take away the half of the
            // press that setting does not object to.
            .animation(AccentFillPress.animation(pressed: isPressed), value: isPressed)
    }
}

/// How a press is drawn: the fill moves.
///
/// **Item 26 gave every accent fill a measured pressed colour and it was still
/// hard to notice**, on the Log pill and the Log again disc most of all. The
/// measurement passed and the goal did not, so the mechanism is what changes
/// here rather than the number — the control physically moves under the thumb,
/// and the colour stays as the second signal (docs/TODO.md item 27).
///
/// **iOS does not do this, and the item said it did.** `.borderedProminent`
/// was rebuilt in this simulator to check: on an iPhone 17 Pro in dark, held
/// down, iOS's own prominent button renders **876x151 px at the same origin as
/// at rest, to the pixel**, and changes only its fill — `#00DAC3` to
/// `#33E1CF`. So a scale on press is this app's decision, not the platform's
/// convention, and it is worth the paragraph: the argument for it is that a
/// colour alone was tried and missed, not that Apple does it.
///
/// **The travel is in points, not in a ratio, because the fills are not the
/// same size.** One ratio cannot serve both: 0.97 takes 4.7pt off each end of
/// the 312pt Log pill and 0.45pt off a 30pt disc, which is nothing — and the
/// disc is half of what item 27 was reported for. So the constant is how far
/// the ends of the fill's longest edge move, and the scale is worked out from
/// the size the fill actually laid out at:
///
///     control                  size (pt)   scale    each end moves
///     Log / home bar           312 x 50    1.0128   2.00pt
///     Log / log sheet          52.7 x 34   1.0759   2.00pt
///     Add Tracker (small)      81.7 x 28   1.0490   2.00pt
///     Undo                     ~60 x 32    1.0667   2.00pt
///     Log again / home bar     50 x 50     1.0800   2.00pt
///     a disc on a row          30 x 30     1.1333   2.00pt
///
/// The pill and the bar's disc are the sizes item 33 gave them; the pill was
/// 292 x 50 at 0.9863 and the disc was not in this table at all, and the table
/// stayed as it was for a commit after the app had moved, which is what a
/// derived scale hides.
///
/// The short edge moves less, which is the one thing a uniform scale cannot
/// help — a 312x50 pill that gained 2pt of height as well would be doing
/// something the eye reads as a swell rather than a press.
///
/// **It grows, and that is a decision rather than a convention**
/// (docs/TODO.md item 37). Every attempt before this one shrank the fill,
/// which is what iOS-shaped controls do elsewhere and what a finger pressing
/// a physical button does; the ask throughout has been that a press *feel*
/// like something, and growing reads as the control coming toward the thumb
/// rather than retreating from it. Nothing about the mechanism changed with
/// the direction — the same travel, the same two call sites, the same gate —
/// so a row and a fill still cannot disagree about it, which matters more
/// here than before: a mix of the two directions on one screen would be worse
/// than either of them everywhere.
enum AccentFillPress {

    /// Points each end of the fill's longest edge travels on a press.
    ///
    /// **2 rather than 3 or 4, and all three were rendered held down** by a
    /// synthesized press on an iPhone 17 Pro, screenshotted mid-press. That was
    /// item 27, when the ends moved inward: at 4pt a disc went 30pt to 22 and
    /// lost a quarter of its width, which read as a different-sized control
    /// rather than the same one pressed, and the pill at 4pt pulled visibly
    /// away from its 16pt margins. At 2pt each end moves 6 device pixels at 3x.
    ///
    /// **The distance survived the direction changing and the argument for it
    /// half did.** Item 37 turned the travel outward, and the reason 4pt was
    /// too much is not symmetric: a pill that grows past its 16pt margins is
    /// crowding the screen edge rather than losing a quarter of itself. What
    /// still holds at 2 is that this is the same control pressed, and what a
    /// grown fill has that a shrunk one did not is somewhere to go — so if this
    /// number is ever revisited, it is the *upward* room around each fill that
    /// bounds it, not the fill's own size.
    static let travel: CGFloat = 2

    /// The scale for a fill that laid out at this size, or `1` for the three
    /// cases where the fill does not move at all.
    ///
    /// **Reduce Motion is one of them, and the app already had this argument
    /// once.** `HomeView`'s counting number goes to no animation at all under
    /// it, on the reasoning that somebody who asked the system for less motion
    /// did not ask for this — and a scale is motion by any reading, where a
    /// recoloured fill is not. So the movement is what the setting takes and
    /// `Color.accentFillPressed` is what it leaves, which is item 26's whole
    /// mechanism still intact rather than a control with no pressed state.
    /// That comment said this was the app's only animation and the only place
    /// that had to ask; item 27 made both halves untrue, and this is the second
    /// place.
    ///
    /// **It is answered here rather than in the modifier** so that a test can
    /// hold it, for the same reason the travel is pinned rather than the ratio:
    /// a later edit that moves the gate up into the `visualEffect` closure, or
    /// drops it, breaks something no screenshot of a default simulator shows.
    /// It is also why item 28 could give list rows the same press without
    /// writing a second gate — `RowButtonStyle` calls this, so a row and a fill
    /// answer Reduce Motion identically by construction.
    ///
    /// The other two are sizes the rule cannot describe. A fill that has not
    /// been measured yet is `.zero`, and scaling from that would draw a
    /// control's first frame mid-press. And a fill shorter than the 4pt this
    /// adds to it **more than doubles** on a press, which reads as a control
    /// appearing rather than a control pressed.
    ///
    /// `2 * travel` is that second boundary, and it is the same constant it was
    /// while the fill shrank — `1 - 2 * travel / longest` was zero at 4pt and
    /// negative below it, so a 3pt fill was mirrored through its own centre
    /// (`9b21d82`). Growing cannot invert anything, so the guard is a milder
    /// rule about the same number: below it a press at least doubles the fill.
    /// Nothing in the app is within 26pt of either reading — the smallest fill
    /// is a 30pt disc — and it is guarded because the doc above sells this
    /// modifier as what a fifth fill gets by writing it rather than by
    /// remembering, and a fifth fill is exactly who would find it.
    static func scale(for size: CGSize, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion else { return 1 }
        let longest = max(size.width, size.height)
        guard longest > 2 * travel else { return 1 }
        return 1 + 2 * travel / longest
    }

    /// The press is not animated. Only the release is.
    ///
    /// **This is item 32, and it is the whole of it.** Item 26 measured a
    /// pressed colour and the press still could not be seen; item 27 added a
    /// scale and it still could not be seen. The mechanism was not the problem
    /// either time — the *timing* was, and both attempts were judged by
    /// pressing and holding, which is the one way of touching a control that a
    /// fade-in survives. Item 27 measured this curve at 66ms to settle going
    /// down. A tap is shorter than that, so a tap reversed a press that had
    /// never arrived, and the app looked deadest exactly when it was used
    /// fastest.
    ///
    /// So the state applies on the frame the touch lands, and only the way out
    /// is drawn. The release is also what carries a fast tap past the lift:
    /// what is on screen is the pressed state for as long as the finger is
    /// down, and then `release` on top of it.
    ///
    /// **A function of the value being moved *to*, not the one being left.**
    /// `.animation(_:value:)` takes its animation from the same body evaluation
    /// as the new value, so `pressed` here is the state arriving: `nil` going
    /// down, `release` coming back up. Written as one function so a fill and a
    /// row cannot answer this differently, which is the same reason
    /// `scale(for:reduceMotion:)` is here rather than in the modifiers.
    ///
    /// `PHILOSOPHY.md` rules out animations you have to wait for, and neither
    /// half is one: the action fires on the lift, and the release is drawn
    /// after it.
    static func animation(pressed: Bool) -> Animation? {
        pressed ? nil : release
    }

    /// What a release takes, and the only animation left in a press.
    ///
    /// 0.12s, unchanged from item 27, which measured this curve at **82ms
    /// coming back** off a 60fps capture of the Log pill — the tail of an
    /// easeOut is sub-pixel, so less of it shows than is asked for. That number
    /// was taken while the same curve ran in both directions; the release half
    /// of it is the half that is left.
    static let release: Animation = .easeOut(duration: 0.12)

    /// How long a press stays on screen once it has arrived, however briefly
    /// the finger was down.
    ///
    /// **A list withholds a touch, and hands a fast tap over as a single
    /// instant.** `UIScrollView` delays a touch reaching the control under it
    /// so that a flick scrolls rather than pressing — the same delay this
    /// repo already measured from the other side, as the reason a scroll does
    /// not fire the press haptic. What it does with a tap *shorter* than that
    /// delay is deliver the down and the up together: the button's pressed
    /// state goes true and false inside one update, so there is nothing for
    /// any amount of instant drawing to render.
    ///
    /// Measured on an iPhone 17 Pro, synthesized taps on a settings row, the
    /// row's own band read off a 60fps capture — a row at rest averages
    /// `28,28,30` there and a pressed one `56,56,58`:
    ///
    ///     tap     what rendered
    ///     60ms    nothing
    ///     100ms   nothing
    ///     200ms   56,56,58 on the first frame after the touch
    ///     400ms   56,56,58 on the first frame after the touch
    ///
    /// Both edges were logged for the 60ms tap, in the same millisecond, which
    /// is what says this is a coalesced press rather than no press. So the fix
    /// is to hold what arrived: the state latches on, and the release waits out
    /// whatever is left of this.
    ///
    /// **0.1s, and it is a floor rather than a duration** — a press longer than
    /// this is unaffected, and what a fast tap gets is 0.1s of pressed row and
    /// then `release` on top of it. It is only on rows: a fill outside a list
    /// gets its touch immediately and stays down for as long as the finger is,
    /// so there is nothing there to hold.
    static let minimumHold: Duration = .milliseconds(100)
}

/// For a `.plain`-shaped button whose label draws its own accent fill.
///
/// It replaces `.buttonStyle(.plain)` at those call sites and does one thing:
/// hand `configuration.isPressed` to the `AccentFillBackground` inside. What
/// it deliberately does not do is `.plain`'s own press effect — the whole
/// label at 75% opacity — because that is the surface-dependent composite
/// item 26 replaced with a named colour, and applying both would fade the
/// pressed value a second time.
///
/// **Four call sites, and it was five until item 28.** The Log again row took
/// this until rows got a press of their own — see `RowButtonStyle` — because
/// there the whole row is the button and the press belongs to the whole row.
/// What is left is every control whose label *is* an accent fill: `UndoButton`,
/// home's bottom-bar Log again disc, a home card's `+`, and History's repeat
/// disc. Counted rather than remembered, because the sentence here said "three"
/// after an edit meant to say "three discs", and a comment that undercounts its
/// own call sites is how two of the four get audited and the others do not.
///
/// **`.plain` dimmed a *disabled* label as well, and that half was not a
/// trade — it was missed.** A disabled Log again row greying its whole self is
/// a rule `RepeatRow`'s own doc argues for, and without `.plain` the row drew
/// its value line at the same `#000000` a live row does. `RepeatRow` dims its
/// text itself now, at the 0.5 `.plain` composited at; the numbers are there.
/// Nothing else in the app hit it, because every other `.accentFill` button's
/// label *is* the accent fill and `OnAccentFill` already colours that.
struct AccentFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.accentFillPressed, configuration.isPressed)
            .pressHaptic(configuration.isPressed)
    }
}

/// The app's prominent button: a filled capsule with a dark label.
///
/// **This is `.borderedProminent` redrawn rather than restyled, and item 26 is
/// why.** A pressed prominent button is dimmed by iOS itself and a
/// `ButtonStyle` cannot change that — applying one *replaces*
/// `.borderedProminent` instead of adding to it, and the tint is read before
/// the press effect is composited. In dark mode that effect lightens the fill
/// to `#33E1CF`, **1.08:1** against its rest colour and moving the opposite way
/// from every other accent fill on the screen. So the fill is drawn here, and
/// all three states come from `AccentFillBackground` like everything else.
///
/// **The metrics are iOS's, measured off the build before this and matched
/// deliberately**, because a Log pill two points shorter is a regression this
/// item did not ask for. On an iPhone 17 Pro Max, `.borderedProminent` paints
/// 330.00×50.33pt for home's bar at `.controlSize(.large)` and
/// 52.67×34.33pt for the log sheet's *Log* at the default size. This paints
/// 330.00×50.00 and 52.67×34.00 — the same width to the pixel in both, and a
/// third of a point shorter, which is iOS laying its own capsule out on a
/// fractional height. **Those two widths are that device and that bar layout**,
/// taken at item 26; the bar's own arithmetic changed at item 33 and the height
/// and the padding are what this style decides in any case. Outside the fills,
/// home is byte-identical apart from a single row where the bar's top edge
/// follows that third of a point.
///
/// The 12pt horizontal padding is that measurement and not a round number:
/// 11 drew the sheet's *Log* exactly 2pt narrow, which is the size of drift
/// this comment exists to have caught. The empty home screen's *Add Tracker*
/// is the third size, `.small`, and it caught a second one — see `font` below.
///
/// `\.controlSize` is read rather than taking a parameter, so the call sites
/// keep saying `.controlSize(.large)` in the platform's own vocabulary and a
/// third size later has one place to land.
struct AccentPillButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: minHeight)
            .accentFilled(.capsule)
            // The target is the capsule the pill lays out at, and not the
            // larger one it is drawn at while held — and what makes that true
            // is `visualEffect` being visual only, not the fact that this line
            // comes after it. It credited the ordering until review, which is
            // worth correcting rather than tidying: an enclosing scale
            // transforms this shape too, so if the press did move geometry,
            // writing `contentShape` out here would not have saved the target,
            // and a later swap to a plain `.scaleEffect` would keep the
            // documented order while quietly breaking it.
            //
            // **The proof is item 27's and it survives the direction
            // changing**, which is worth saying because the check itself does
            // not. While the press shrank, a synthesized press at x = 17pt was
            // inside the resting 16.0–328.0pt capsule and outside the
            // 18.0–326.0 it drew at held: it engaged, held and fired, so the
            // target was plainly not the drawn shape. That is a fact about
            // `visualEffect` rather than about a number, and the sign of a
            // scale cannot change whether a rendering modifier takes part in
            // hit testing — so the same test cannot be re-run to mean anything
            // now that the drawing is 14.0–330.0pt, *outside* the target.
            //
            // What the new direction does raise is a 2pt rim that is drawn and
            // not targeted, and the worry with it — raised in review — is a
            // thumb that lands on the edge, drifts onto the rim, and lets go
            // into nothing. It does not happen, and that was checked rather
            // than argued: pressed at x = 17pt, dragged out to x = 15pt and
            // held there, the pill stays at `#07AA9A` through the drift and
            // the release opens the log sheet. A control keeps tracking a
            // touch that leaves it by 1pt, so the rim behaves like the pill it
            // is drawn as.
            .contentShape(.capsule)
            .environment(\.accentFillPressed, configuration.isPressed)
            .pressHaptic(configuration.isPressed)
    }

    /// Three sizes because the app uses three, each number read off the build
    /// before this one rather than guessed. `.mini` and `.extraLarge` follow
    /// their neighbours and are unmeasured — nothing here asks for them, and a
    /// made-up number would look exactly like a measured one.
    private var minHeight: CGFloat {
        switch controlSize {
        case .mini, .small: 28
        case .large, .extraLarge: 50
        default: 34
        }
    }

    /// Half of what iOS left either side of the label, which is the only part
    /// of the width this style decides — home's pill is stretched by its own
    /// `maxWidth: .infinity` and does not use these at all.
    private var horizontalPadding: CGFloat {
        switch controlSize {
        case .mini, .small: 10
        case .large, .extraLarge: 20
        default: 12
        }
    }

    /// `.subheadline` at the small size, because iOS shrinks the label there
    /// too: *Add Tracker* on the empty home screen renders an 11.00pt cap
    /// height against 12.33 at the default size, and 81.67pt wide against
    /// 91.00. Padding alone cannot match a control whose text is a different
    /// size, which is how that button first came back 13pt too wide. With the
    /// font right, `.subheadline` sets it a point wider than iOS's own — hence
    /// 10 rather than the 10.5 the pill measured either side of its label.
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

/// The app's recovery control, drawn one way wherever it appears.
///
/// Filled, dark-labelled, and shaped like History's repeat disc — the same
/// idiom in a capsule, because the word is wider than it is tall. A 32pt fill
/// inside a 44pt target, so it does not set the height of the bar or the row it
/// lands in; a bare `Button("Undo")` is hit only where the word is drawn, which
/// was half the size of the mistake it exists to fix.
///
/// **Shared rather than written twice.** There are two of these — History's
/// undo bar and a tracker's own deletion row — and item 13c redesigned the
/// first without noticing the second, which left one screen's recovery as a
/// capsule and another's as a word in the label colour, indistinguishable from
/// the sentence beside it. Undo is the one control in the app that exists to be
/// found in a hurry (docs/PHILOSOPHY.md, "Forgiving"), so it is the last place
/// two design languages belong.
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
        // `.accentFill`, which is `.plain` plus the one thing `.plain` cannot
        // do: hand the press down to the capsule inside the label
        // (docs/TODO.md item 26). The fill above is still the whole of the
        // styling and a list row does not draw its own on top.
        .buttonStyle(.accentFill)
    }
}

/// "Log this again", drawn one way wherever it appears.
///
/// **Shared because it had already come apart.** The action reaches three
/// places — home's bottom bar, a History row, a row in the Log again sheet —
/// and the first of them was the app's only `.buttonStyle(.bordered)`: a grey
/// square with a *white* glyph, beside two accent discs with a black one. Same
/// glyph, same VoiceOver label, two answers about what kind of control it is
/// (docs/TODO.md item 21). The other two agreed only because one was copied
/// from the other, which is the arrangement that produced the disagreement in
/// the first place — `UndoButton` above exists for exactly this reason, one
/// item earlier.
///
/// **Prominence is carried by size and shape here, not by colour.** The worry
/// item 16 recorded about home's bar is real — a peer beside the Log pill reads
/// as a choice to make on arrival — but what makes this a secondary control is
/// that it is a 30pt disc against a full-width pill and has no word on it, not
/// that it is drawn in a different colour from the same action one screen away.
/// The card's `+` is the same disc in the same fill and does not compete with
/// the pill either.
///
/// **The glyph carries a plus**, because the tap logs something rather than
/// merely repeating it. `plus.arrow.trianglehead.clockwise` is one symbol
/// rather than a plus composited onto `arrow.clockwise`: it scales, mirrors and
/// takes a weight on its own. No repeat-ish symbol has a `.badge.plus` variant
/// — there are 64 `.badge.plus` symbols in iOS 26.3's CoreGlyphs and not one of
/// them is an arrow, a clock or a rotate — so this native composition is the
/// nearest thing, and it is available from iOS 18.0, which is the deployment
/// target.
///
/// Disabled off `\.isEnabled` rather than a parameter, so a caller says
/// `.disabled(...)` once on its button and the disc follows. **Read from
/// inside the button's label**, which is where this always sits — a reader
/// wrapped around an already-disabled button sees the ancestors' environment
/// instead and always believes it is enabled (see `OnAccentFill` above).
struct RepeatDisc: View {
    /// The glyph, named once so the three call sites cannot drift again — and
    /// so the Log again sheet's empty state can draw the same one.
    static let symbol = "plus.arrow.trianglehead.clockwise"

    /// The circle. 30 on a row, where this is one control at the end of
    /// something else, and 50 in home's bottom bar, where it is one of the two
    /// things on the screen and has to agree with the pill beside it
    /// (docs/TODO.md item 33).
    var diameter: CGFloat = 30

    /// **Not derived from `diameter`, because it is not proportional to it.**
    /// Read off the photograph the user picked: the bar's circle is 50pt with a
    /// glyph whose ink measures 20.3 × 22.3pt, against 30pt and 14.3 × 15.7 on
    /// a row — the circle grows by 1.67 and the glyph by 1.42. A proportional
    /// glyph would be `size: 23` and fills the circle in a way the chosen
    /// rendering does not.
    var glyph: CGFloat = 14

    /// Drawn as a checkmark instead of the repeat glyph, for the second after
    /// the Log again sheet has written something (docs/TODO.md item 30).
    ///
    /// **Home's bar is the only caller, and that is the point.** A repeat
    /// counts its number up on home's card and offers the undo on a bar, and
    /// item 15's animation for that is real and correct and lives at the top of
    /// a screen that was behind the sheet you were looking at. History has an
    /// answer to this already — it marks the row the write produced, for two
    /// seconds, from `store.lastLoggedAgainRow` (item 20) — and home had none.
    /// So the disc the sheet came *out* of says it, under the thumb that just
    /// tapped, in the moment the sheet uncovers it.
    ///
    /// **Not on the row inside the sheet, which was tried first and cannot
    /// work.** Marking the tapped row is item 30's own first candidate; it was
    /// built and recorded and `dismiss()` outruns it — see `HomeView`'s
    /// `loggedAgain` for what the recording showed.
    ///
    /// **No `contentTransition`.** `.symbolEffect(.replace)` was built and
    /// recorded first, and it takes about 300ms of a 60fps capture to finish —
    /// a third of the second the mark is up spent not yet being a checkmark, on
    /// a screen whose rule is that nothing animates that you have to wait for
    /// (docs/PHILOSOPHY.md). The swap is a swap.
    var confirmed = false

    var body: some View {
        Image(systemName: confirmed ? "checkmark" : Self.symbol)
            // Fixed rather than a text style, for the reason home's + is: the
            // disc and its target do not scale, so a glyph that does outgrows
            // its own circle at the accessibility sizes.
            .font(.system(size: glyph, weight: .bold))
            // `.onAccentFill()`, which is the same black on the fill and the
            // ordinary label colour on the grey one. It was `.tertiary` when
            // off, which measured 1.32:1 on a fill that was itself 1.24:1
            // against the row — a disc that was not there rather than a disc
            // that was off (docs/TODO.md item 26).
            .onAccentFill()
            .frame(width: diameter, height: diameter)
            // `accentFilled`, not `.tint`: the environment tint is the
            // ordinary label colour now, and a disc is a fill (docs/TODO.md
            // item 13c). "The accent is only ever a fill" is what this said,
            // and item 18 made it not quite true — `navBarAccent()` and
            // `formRowAccent()` write with it, on standard controls that have
            // no other way to say they are tappable. Nothing else does, and
            // this is not one of them. The modifier carries all three states
            // and the press's scale, so a disc presses and greys the same way
            // in all three places it appears (docs/TODO.md items 26 and 27).
            .accentFilled(.circle)
            // 44 where the circle is smaller than that, and the circle itself
            // where it is not: a target under 44 is one Apple would object to,
            // and one *larger* than the thing it belongs to steals the gap
            // beside it.
            .frame(width: max(44, diameter), height: max(44, diameter))
            .contentShape(.rect)
    }
}

extension View {

    /// For the label of a control filled with the accent — a prominent button,
    /// or the small discs that are the same idiom in miniature.
    func onAccentFill() -> some View {
        modifier(OnAccentFill())
    }

    /// Fill this label with the accent, in whichever of its three states its
    /// control is in, and let it go down when the control does.
    ///
    /// **One modifier rather than a background and a scale written out at each
    /// site**, because the four accent fills in the app — the pill, the undo
    /// capsule, the Log again disc, a card's `+` — have already drifted apart
    /// once each (items 21, 26, 27), and every one of those was two call sites
    /// agreeing by hand until one of them stopped. A fifth fill added later
    /// gets the press by writing this instead of by remembering it.
    ///
    /// Apply it to whatever the fill is drawn behind, and put the control's
    /// `contentShape` and its 44pt target *outside* it: the scale is drawn on
    /// the fill and the target does not move with it.
    func accentFilled<S: Shape>(_ shape: S) -> some View {
        modifier(AccentFilled(shape: shape))
    }

    /// A light impact as a control goes down.
    ///
    /// **Feedback, not celebration.** `PHILOSOPHY.md` bans haptic
    /// celebrations — a buzz for a streak, a saved entry, a job well done —
    /// and this is the other thing: the physical half of a button going down
    /// under a thumb, at the moment of the press rather than at the moment of
    /// the result. Logging a number stays silent; touching the control is what
    /// speaks.
    ///
    /// On the press and not on the release, so it arrives with the scale and
    /// the colour rather than after the action. `trigger` is the press state,
    /// and the closure fires only on the edge into it, so a lift is silent.
    ///
    /// **A scroll does not fire it**, which was the objection worth testing: a
    /// whole `RepeatRow` is a button, so a finger that starts a scroll starts
    /// it on a control. Recorded at 60fps on the Log again sheet, a flick that
    /// starts on a row never enters the pressed state at all — nor does one
    /// that rests 0.2s first — because a list delays the touch. It takes
    /// somewhere between 0.2s and 0.45s of a stationary finger before the disc
    /// goes down, by which point the gesture is a press and not a scroll.
    ///
    /// **What that recording does not cover is a press called off** (found in
    /// review): a finger that waits out the list's delay, goes down, and then
    /// slides off the row to abandon the tap has already been given the impact
    /// for an action that never runs. Left as it is — the whole point of this
    /// is feedback at the moment of the press rather than at the moment of the
    /// result, and a control that only buzzed when it succeeded would be back
    /// to reporting outcomes. But it is a press with no result that nobody has
    /// watched, so it goes to item 17 with the rest of the haptic rather than
    /// being claimed as covered.
    ///
    /// **Whether it helps is not answered here.** The simulator has no haptics
    /// — UIKit logs "Haptics: unsupported" and nothing reaches CoreHaptics — so
    /// this shipped unfelt, for the device pass in item 17 to keep or delete.
    /// It is three lines and one call site if the answer is that it is noise.
    ///
    /// **`accentFillHaptic` until item 28**, which gave list rows a press of
    /// their own and applied this to it — so the name was about the one kind of
    /// control it started on rather than about what it does. Three call sites,
    /// all of them button styles in this app.
    func pressHaptic(_ isPressed: Bool) -> some View {
        sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isPressed) { _, pressed in
            pressed
        }
    }

    /// A success notification as a log lands (docs/TODO.md item 30).
    ///
    /// **Feedback, not celebration**, and the same line `pressHaptic(_:)`
    /// draws: `PHILOSOPHY.md` bans a buzz for a streak or a job well done, and
    /// this is the other thing — the answer to "did that go in?" for a tap
    /// whose visible result is drawn on a screen behind the one you are looking
    /// at. It is the one signal that reaches you wherever you are looking, and
    /// it is why the checkmark on `RepeatDisc` is not the whole answer.
    ///
    /// `.success` rather than a second impact, deliberately: the press already
    /// carries `.impact(.light)`, and a confirmation that felt like the press
    /// again would say "touched" twice instead of "touched, then written".
    ///
    /// **Takes what was written rather than a flag**, because a `Bool` serves
    /// only the caller that clears it: History never does, so an earlier repeat
    /// would leave it `true` and the next tap would arrive in silence. Both
    /// call sites pass `Store.lastLoggedAgainRow`, which carries a fresh batch
    /// id per write and so differs between two repeats of the same row.
    ///
    /// **Not `lastLoggedAgainAt`, which both call sites used first** (found in
    /// review). It looks like the same thing and has one-second resolution:
    /// `Date.stamp()` canonicalises to whole seconds so the store file is
    /// lossless, so two repeats inside one second are the same `Date` and the
    /// second one is silent — the exact failure the paragraph above is about.
    ///
    /// Nothing fires on the way back to `nil`, and nothing fires on arrival:
    /// `sensoryFeedback` triggers on a change, so pushing a screen whose value
    /// is already set is silent.
    ///
    /// **Unfelt here, like the press.** The simulator has no haptics — UIKit
    /// logs "Haptics: unsupported" and nothing reaches CoreHaptics — so whether
    /// this helps is item 17's device pass, the same as `pressHaptic(_:)`.
    func logHaptic<Wrote: Equatable>(_ wrote: Wrote?) -> some View {
        sensoryFeedback(.success, trigger: wrote) { _, wrote in wrote != nil }
    }

    /// The accent back on a **nav bar button**, and nowhere else
    /// (docs/TODO.md item 13d).
    ///
    /// Item 13c stopped the accent being something this app *writes* with —
    /// chart bars, glyphs and labels on the ordinary background — and applying
    /// that at the root took the nav bars with it, which is the one place the
    /// rule cost something rather than buying something. A tinted bar button is
    /// not text painted in an accent; it is the standard iOS affordance for
    /// "tappable", on a bar background Apple has already tuned for it, and
    /// Cancel, Save, the gear and the clock read as chrome rather than as
    /// writing. So this is a carve-out for system chrome, not a retreat: the
    /// chart stays monochrome and every other 13c site is unchanged.
    ///
    /// **This used to be where the accent's lightness cost rather than paid,
    /// and item 18 settled it.** As a dark-mode bar glyph the accent measures
    /// **9.89:1** against the `#191919` circle iOS 26 draws behind a bar button,
    /// among the best in the candidate set; on that circle's light-mode
    /// `#FBFBFF` the system mint managed **2.05:1**, the same failure the teal
    /// had at 2.13:1. The colour set's light value measures **3.48:1** there,
    /// against the system blue control's 3.41, so both appearances now clear the
    /// floor and this call site no longer has a mode it merely survives.
    ///
    /// **`.tint`, and it has to be `.tint` here** — which is the one thing that
    /// stops this and `formRowAccent()` being the same modifier under one name.
    /// A nav bar button can be disabled (`TrackerEditor`'s *Save* with an empty
    /// name, and the two editors beside it), and a tint is dropped for a
    /// disabled bar button: it draws `#B0B0B2` grey, which is the whole point.
    /// `.foregroundStyle` is *not* dropped — measured on that same disabled
    /// *Save*, it draws the full `#009888` and the button reads as tappable when
    /// it is not.
    ///
    /// Per button rather than at the root on purpose. The root tint stays
    /// `.primary`, so a foreground use of the accent cannot appear by
    /// inheritance the way it did twice before — it has to name itself here, and
    /// a bar button that misses this call reads as one black word beside a mint
    /// one.
    func navBarAccent() -> some View {
        tint(Color.accentFill)
    }

    /// The accent on a **`Form` action row** — a `Button` or a `ShareLink` in
    /// the settings list that does something rather than going somewhere
    /// (docs/TODO.md item 13e).
    ///
    /// The same carve-out `navBarAccent()` is, at the other place the app was
    /// relying on the OS to say "tappable". Item 13c turned these rows the
    /// ordinary label colour and recorded it as a contrast win, which it was;
    /// what it cost is that **a `Button` in a `Form` has no disclosure
    /// chevron**, so a row with its label and its icon in the label colour is
    /// pixel-identical to a static one. So the affordance here is colour or it
    /// is nothing.
    ///
    /// The tracker rows above *Add Tracker* do read as tappable, and **not
    /// because the system draws them a chevron** — item 13e said
    /// `NavigationLink` and that is not what is there. `SettingsView.rowButton`
    /// is a `.plain` `Button` that draws `Image(systemName: "chevron.right")`
    /// itself, in `.tertiary`. Worth being exact about, because "the platform
    /// gives a navigating row its chevron" is a belief under which somebody
    /// deletes that image and silently strips the affordance from every tracker
    /// row at once.
    ///
    /// It was blocked on item 18 rather than on taste: restoring it needed a
    /// light-mode value that cleared 3:1 as a *foreground*, and the system mint
    /// measured **2.12:1** on the row's `#FFFFFF`. The colour set's light value
    /// measures **3.59:1** there, against the system blue control's 3.52, and
    /// **9.57:1** on the dark row's `#1C1C1E`.
    ///
    /// **`.foregroundStyle`, not `.tint`, and both halves of that were
    /// measured.** Under iOS 26 a tinted `Form` row draws its *text* in the tint
    /// and leaves the SF Symbol at the label colour — `#000000` light,
    /// `#FFFFFF` dark — so `.tint` produces a two-colour row, an accented word
    /// beside a label-coloured glyph, which is half an answer to "is this a
    /// button". `.foregroundStyle` takes the glyph with it. It also survives
    /// being disabled *here*, where a tint does not: a disabled row under
    /// `.tint` drops the accent entirely and draws plain black, indistinguishable
    /// from an ordinary row, while `.foregroundStyle` dims to `#7FCBC3`, a 50%
    /// blend that reads as off. The opposite is true one modifier up, which is
    /// why there are two of these and not one.
    ///
    /// **Per row rather than on the `Section`.** Two rows in these sections
    /// must not take it — *Delete All Data…*, whose `role` gives it red, and
    /// anything destructive added later — and a section-wide style is how a row
    /// ends up saying the wrong thing about what it does by inheritance rather
    /// than by decision. Item 13e also expected a section-level tint to reach
    /// the `.alert` and `.confirmationDialog` buttons attached to that section;
    /// that was not re-tested here, because naming each row means those buttons
    /// have nothing applied to them either way, and a button in a dialog is
    /// already unmistakably a button.
    func formRowAccent() -> some View {
        foregroundStyle(Color.accentFill)
    }
}
