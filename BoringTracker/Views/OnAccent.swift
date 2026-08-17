import SwiftUI

extension Color {

    /// The accent. A fill everywhere except the nav bar — see `navBarAccent()`.
    ///
    /// `.teal` rather than a hex: a system colour is dynamic, so it desaturates
    /// itself on black instead of glowing there, and dark mode is where this app
    /// is used. `.mint` was the alternative and reads greener than the app's own
    /// name.
    ///
    /// Named rather than read from the environment tint, because the tint is no
    /// longer this colour (docs/TODO.md item 13c). Teal is light in both
    /// appearances, which is what makes it a good fill behind a dark label and a
    /// bad colour to write with: as a *foreground* on the ordinary background it
    /// measured 1.95:1 in light mode, under the same 3:1 floor item 13b fixed
    /// the fills against. So every control that used to be teal text is drawn in
    /// the ordinary label colour, and this name marks the places that are
    /// genuinely a fill — the prominent buttons, the two small discs that are
    /// the same idiom in miniature, and the drop highlight in settings.
    ///
    /// Anything *filled* with this needs `Color.onAccent` on top of it. The one
    /// place it is a foreground is system chrome, which has its own name below
    /// so that the exception is greppable rather than a judgement call.
    static let accentFill = Color.teal

    /// What goes *on* the accent fill.
    ///
    /// The accent fill is a light teal — `#00D2E0` in dark mode, `#00C3D0` in
    /// light — and iOS draws a prominent button's label white whatever the tint
    /// is. That pairing measures 1.86:1, against the 3:1 floor a UI element
    /// needs, on the one screen this app exists to be glanced at one-handed
    /// (docs/TODO.md item 13b). The blue it replaced was 2.69:1, so the accent
    /// change made a failing pairing worse rather than breaking a working one,
    /// and the fix is the same either way.
    ///
    /// Teal is light, so the label moves rather than the fill: near-black on it
    /// reads easily, and the tint stays a system colour that desaturates itself
    /// for dark mode instead of a hex tuned on white.
    ///
    /// **Black, not a dynamic colour.** The fill is light in *both* appearances,
    /// so a label that flipped with the appearance would be white on teal again
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
    /// Per button rather than at the root on purpose. The root tint stays
    /// `.primary`, so a foreground use of teal cannot appear by inheritance the
    /// way it did twice before — it has to name itself here, and a bar button
    /// that misses this call reads as one black word beside a teal one.
    func navBarAccent() -> some View {
        tint(Color.accentFill)
    }
}
