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
}

/// Draws a label in `Color.onAccent` while its control is enabled, and leaves a
/// disabled one exactly as iOS drew it.
///
/// The second half is the whole reason this is a modifier rather than a
/// `.foregroundStyle` at each call site. A **disabled** `.borderedProminent`
/// button is drawn from a neutral fill and never touches the tint — measured in
/// dark mode as a black pill with a grey label — so forcing the label black
/// there paints black on black, and the log sheet opens in exactly that state
/// with every field still empty.
///
/// Apply it to the button's *label*, inside the `Button`, never to the button
/// from outside. `.disabled(_:)` sets `isEnabled` for its content, so a reader
/// wrapped around the already-disabled button sees the environment of the
/// ancestors instead and always believes it is enabled.
private struct OnAccentFill: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.foregroundStyle(Color.onAccent)
        } else {
            content
        }
    }
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
                .foregroundStyle(Color.onAccent)
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(Color.accentFill, in: .capsule)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        // `.plain`, so the fill above is the whole of the styling and a list row
        // does not draw its own on top.
        .buttonStyle(.plain)
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

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: Self.symbol)
            // Fixed rather than a text style, for the reason home's + is: the
            // disc and the 44pt target do not scale, so a glyph that does
            // outgrows its own circle at the accessibility sizes.
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(isEnabled ? AnyShapeStyle(Color.onAccent) : AnyShapeStyle(.tertiary))
            .frame(width: 30, height: 30)
            // `Color.accentFill`, not `.tint`: the environment tint is the
            // ordinary label colour now, and a disc is a fill (docs/TODO.md
            // item 13c). "The accent is only ever a fill" is what this said,
            // and item 18 made it not quite true — `navBarAccent()` and
            // `formRowAccent()` write with it, on standard controls that have
            // no other way to say they are tappable. Nothing else does, and
            // this is not one of them.
            .background(
                isEnabled ? AnyShapeStyle(Color.accentFill) : AnyShapeStyle(.quaternary),
                in: .circle
            )
            .frame(width: 44, height: 44)
            .contentShape(.rect)
    }
}

extension View {

    /// For the label of a control filled with the accent — a prominent button,
    /// or the small discs that are the same idiom in miniature.
    func onAccentFill() -> some View {
        modifier(OnAccentFill())
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
