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

/// How a row's press is drawn.
///
/// **The same press the accent fills got in item 27, in the one place they
/// could not reach** (docs/TODO.md item 28). A row is a control on five screens
/// in this app and behaved like a label on all of them: no colour, no movement,
/// nothing under the thumb saying the tap had been received. Item 26 already
/// established that a pressed state which passes a measurement and still is not
/// noticed means the mechanism is wrong, and item 27 answered that for the
/// fills with a scale. This is the same answer with a row's own colour.
///
/// **Both halves, and neither on its own.** The fill is `Color.rowPressed`,
/// which is what iOS presses its own rows to; the movement is
/// `AccentFillPress`, the app's existing 2pt travel, read from the same place
/// the pill and the discs read it. So a row and a button go down by the same
/// distance in the same 0.12s curve, which is what "as unmistakable as a
/// button's, and the same everywhere" has to mean if it is to survive the next
/// screen someone adds.
///
/// **Reduce Motion is asked once, by `AccentFillPress.scale(for:reduceMotion:)`
/// and not again here.** That gate already returns 1 for the setting, so a row
/// under it recolours and does not move — item 27's decision, reused rather
/// than re-argued, and the reason this type has no accessibility environment of
/// its own to get out of step. Checked as a counterfactual on one binary rather
/// than by reading the key back: holding a home card with the setting off moves
/// the total's right edge from 961 to 955 device pixels at 3x, and with it on
/// the same press leaves it at 961 while still painting `#3A3A3C` behind the
/// row.
///
/// **The `visualEffect` is not free at rest, and the price is 14,485 pixels.**
/// A row wearing this draws into its own layer whether or not it is pressed, and
/// text rasterised in that layer lands fractionally differently: home at rest is
/// pixel-identical to the build before item 28 with the `visualEffect` line
/// deleted and differs in **14,485 of 3,162,132 pixels** with it — 0.46%, spread
/// over the four cards' text, the widest single move being a card's total one
/// point narrower on its leading edge with its trailing edge unmoved. Nothing in
/// the layout changes and it is not visible at arm's length; it is written down
/// because the next person to pixel-diff this screen will find it and should not
/// have to work out where it came from. The alternative was a row press with no
/// movement in it, which is half of what item 28 asked for.
struct RowButtonStyle: ButtonStyle {
    /// Read here and handed to `AccentFillPress`, which owns the answer — see
    /// the type's doc. It is in this style rather than in the background below
    /// because the scale is applied here.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        // Out of the environment once, into the `@Sendable` closure below, for
        // the reason `AccentFilled` does the same: reaching into main-actor
        // state from inside it is a warning in a target built with strict
        // concurrency complete.
        let isPressed = configuration.isPressed
        let reduceMotion = reduceMotion
        return configuration.label
            .background(RowPressBackground(isPressed: isPressed))
            // `visualEffect`, not `.scaleEffect`, and for the reason the fills
            // use it: the scale is worked out from the size the row laid out
            // at, and hit testing keeps the unscaled geometry — a thumb resting
            // at the edge of a row does not fall out of a target that shrank
            // under it.
            .visualEffect { effect, proxy in
                effect.scaleEffect(
                    isPressed
                        ? AccentFillPress.scale(for: proxy.size, reduceMotion: reduceMotion)
                        : 1
                )
            }
            .animation(AccentFillPress.animation, value: isPressed)
            .pressHaptic(isPressed)
    }
}

/// The wash behind a pressed row.
///
/// **Drawn behind the row's content rather than as the row's background**, and
/// that is a real difference: `listRowBackground` would fill the cell edge to
/// edge the way iOS's own does, but it is applied *outside* the button, so the
/// press state would have to be lifted into a `@State` on every row on five
/// screens — including two that build their rows in methods on the enclosing
/// view and have nowhere to put one. One `ButtonStyle` that every call site
/// names is the thing that keeps these five rows agreeing, which is the whole
/// point of the item; a highlight two points wider is not worth five copies of
/// a boolean.
///
/// The corner radius is the one settings already draws a full-row wash at —
/// `SettingsView`'s drop target has tinted the row it would land on at
/// `.rect(cornerRadius: 8)` since the reorder gesture shipped, so the app has
/// an answer for "a rounded fill behind a row" and this is it rather than a
/// second one.
private struct RowPressBackground: View {
    let isPressed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.rowPressed)
            // An opacity rather than a choice between two fills, as the drop
            // target does one file over: a fill at zero draws exactly what
            // `.clear` did, and there is no branch for the animation to
            // interpolate across.
            .opacity(isPressed ? 1 : 0)
    }
}

extension ButtonStyle where Self == RowButtonStyle {

    /// See `RowButtonStyle`. This is what a list row that does something wears,
    /// in place of `.buttonStyle(.plain)`.
    static var row: RowButtonStyle { RowButtonStyle() }
}
