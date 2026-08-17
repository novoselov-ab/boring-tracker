import SwiftUI

extension Color {

    /// The accent. A fill everywhere except the nav bar — see `navBarAccent()`.
    ///
    /// **Mint, and it is a fill because it can only be a fill.** Twelve
    /// candidates were rendered on these screens and sampled
    /// (docs/accent-options.md). Mint behaves like the teal it replaces: it is a
    /// light colour, so it is excellent behind a dark label and illegal behind a
    /// white one — **1.78:1** with white, against a 3:1 floor, and **11.82:1**
    /// with the black `Color.onAccent` this app already forces. That pairing is
    /// not a preference here, it is load-bearing: item 13b banned white labels on
    /// the accent, and **this colour is only legal because that ban exists.**
    ///
    /// So the two decisions are now coupled, which the blue this replaced would
    /// not have been. Blue clears the floor with either label; mint clears it
    /// with one. Anything that puts a white label back on an accent fill —
    /// dropping `onAccentFill()`, a new prominent button that forgets it, a
    /// third-party control drawing its own label — does not merely look
    /// different, it takes the accent under the floor with it.
    ///
    /// **Not because a system colour "desaturates itself for dark mode".** That
    /// claim stood in this comment and does not survive measurement: blue, teal
    /// and mint are `S = 1.00` in *both* appearances and green goes *up*. What
    /// Apple changes in dark is brightness. The reason to name a system colour
    /// is that both its values are Apple's, tuned against Apple's own
    /// backgrounds, and there is nothing to keep in step by hand.
    ///
    /// **`Color(.systemMint)` rather than `Color.mint`.** The two are the same
    /// fill to the byte: both builds render `#00DAC3` in dark, every pixel of the
    /// Log pill identical. Where they differ is a *bar glyph*, and only some of
    /// them — under `Color.mint` both nav bar buttons come out `#0DE7D0`, a flat
    /// `+13/255` on every channel; under this value home's gear draws the fill
    /// unchanged while History's clock still comes out `+13`. So the offset
    /// belongs to the button as much as to the constant, which is not what
    /// docs/accent-options.md concluded from the gear alone. Both sides are 9.89
    /// and 11.18 against the bar, so nothing rides on it; the UIKit value is kept
    /// because it is the one Apple tuned that bar background for.
    ///
    /// Named rather than read from the environment tint, because the tint is no
    /// longer this colour (docs/TODO.md item 13c). Mint is light in both
    /// appearances, which is what makes it a good fill behind a dark label and a
    /// bad colour to write with: as a *foreground* the teal before it measured
    /// 1.95:1 on the ordinary background in light mode, under the same 3:1 floor
    /// item 13b fixed the fills against, and mint is a shade worse — 2.05:1 on
    /// the bar circle today where the teal read 2.13:1. So every
    /// control that used to be accent-coloured text is drawn in the ordinary
    /// label colour, and this name marks the places that are genuinely a fill —
    /// the prominent buttons, the two small discs that are the same idiom in
    /// miniature, and the drop highlight in settings.
    ///
    /// Anything *filled* with this needs `Color.onAccent` on top of it. The one
    /// place it is a foreground is system chrome, which has its own name below
    /// so that the exception is greppable rather than a judgement call.
    static let accentFill = Color(.systemMint)

    /// What goes *on* the accent fill.
    ///
    /// The accent fill is a light mint — `#00DAC3` in dark mode, `#00C8B3` in
    /// light — and iOS draws a prominent button's label white whatever the tint
    /// is. That pairing measures **1.78:1** dark and **2.12:1** light, against
    /// the 3:1 floor a UI element needs, on the one screen this app exists to be
    /// glanced at one-handed (docs/TODO.md item 13b). The teal before it was
    /// 1.86:1 and the blue before that 2.69:1, so no accent this app has ever
    /// shipped could carry the label iOS wants to draw.
    ///
    /// Mint is light, so the label moves rather than the fill: black on it
    /// measures **11.82:1** in dark and **9.91:1** in light — 9.57:1 if the label
    /// is softened to the `#1C1C1E` the cards use — and light-fill-with-dark-label
    /// is ordinary current practice rather than a workaround.
    ///
    /// **This is the load-bearing half of the accent, not a detail of it.**
    /// `Color.accentFill` is legal *because* this is black; put white back and
    /// the accent goes under the floor everywhere at once. See the coupling
    /// noted above it.
    ///
    /// **Black, not a dynamic colour.** The fill is light in *both* appearances,
    /// so a label that flipped with the appearance would be white on mint again
    /// half the time — the exact pairing being removed. What sits on the accent
    /// is decided by the accent, not by the mode.
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
            // ordinary label colour now, and the accent is only ever a fill
            // (docs/TODO.md item 13c).
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
    /// **The one place the accent's lightness costs rather than pays.** As a
    /// dark-mode bar glyph mint measures **9.89:1** against the `#191919` circle
    /// iOS 26 draws behind a bar button, among the best in the candidate set; in
    /// light mode, on that circle's `#FBFBFF`, it is **2.05:1**. That is the same
    /// failure the teal had at 2.13:1 and it is item 18's, not this one's: it is
    /// a property of every light hue measured, it is not fixable by moving a
    /// label the way 13b's fills were, and dark mode — where this app is used —
    /// is the appearance that passes.
    ///
    /// Per button rather than at the root on purpose. The root tint stays
    /// `.primary`, so a foreground use of the accent cannot appear by
    /// inheritance the way it did twice before — it has to name itself here, and
    /// a bar button that misses this call reads as one black word beside a mint
    /// one.
    func navBarAccent() -> some View {
        tint(Color.accentFill)
    }
}
