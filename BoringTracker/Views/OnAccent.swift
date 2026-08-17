import SwiftUI

extension Color {

    /// What goes *on* the accent fill.
    ///
    /// The app's tint is a light teal — `#00D9E6` in dark mode, `#00CDD9` in
    /// light — and iOS draws a prominent button's label white whatever the tint
    /// is. That pairing measures 1.74:1, against the 3:1 floor a UI element
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

extension View {

    /// For the label of a control filled with the accent — a prominent button,
    /// or the small discs that are the same idiom in miniature.
    func onAccentFill() -> some View {
        modifier(OnAccentFill())
    }
}
