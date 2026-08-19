import SwiftUI

extension DynamicTypeSize {
    /// Whether a row has given up on fitting what it is and what it says on one
    /// line.
    ///
    /// **Home's card decided this and three list screens never got the
    /// answer.** The threshold was measured for the card — see `StackingRow`
    /// and `TrackerCard` — and the rows on History, tracker detail and the Log
    /// again sheet are the same shape with the same problem: an identity on the
    /// left, a time or a date on the right, and one line's width between them.
    /// At AX5 a History row read `Body fat ·` / `Mea-` / `sure-` / `ment` down
    /// the left while `12:20` / `AM` came down the right, one row filling most
    /// of a screen with the word *Measurement* hyphenated across three lines.
    ///
    /// `.xxxLarge`, not `isAccessibilitySize`, because that is where the card
    /// put it and one threshold read from four places is the point of this
    /// being here at all. It costs the list rows nothing to stack a step early:
    /// checked on the `many` fixture at `.xxxLarge`, a History row is three
    /// lines either way — stacked it spends one on the time and gets the
    /// identity onto one line, side by side it wraps the identity onto two.
    var stacksRows: Bool { self >= .xxxLarge }
}

/// One row's two halves — what it is on the leading side, what it was or when
/// it happened on the trailing one — beside each other while they both fit, and
/// stacked once they do not.
///
/// **This is home's card, extracted rather than copied.** The card has read
/// name-beside-number since item 11 and fell back to name-over-number at
/// `.xxxLarge`, on the argument that density is worth having only while the row
/// is still readable: the number is sized first, the name absorbs the entire
/// shortfall, and at AX3 and up "Calories" rendered as a single clipped glyph.
/// The three list screens draw the same two halves and never got the fallback,
/// which is what the pass-2 review found. Four copies of one layout rule is how
/// they come apart, so there is one of it and all four call it.
///
/// `spacing: 0` on the side-by-side branch, with the whole gap coming from the
/// `Spacer`, and that number is measured: an `HStack` inserts its spacing on
/// *both* sides of a spacer, so the card's `spacing: 8` around
/// `Spacer(minLength: 8)` reserved 24pt rather than 8 — and since the trailing
/// half is sized first, the surplus came out of the leading half's truncation
/// budget, which is the width a row has least of. The three list rows carried
/// the same default-spaced shape and inherit the fix with the layout.
///
/// Nothing here is priority: which half gives way is the caller's decision and
/// differs between them — the card gives the number `layoutPriority(1)` because
/// a total has to be legible across a kitchen, and a History row lets the time
/// take what it needs because a truncated timestamp is not a timestamp. What
/// this owns is the arrangement and the threshold, which is the part that must
/// not disagree.
struct StackingRow<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        if typeSize.stacksRows {
            // Full width even when the content is short, because the row is a
            // button on every screen that draws one and its tap target should
            // not shrink to the length of a word. Free on the branch below,
            // where the `Spacer` already does it.
            VStack(alignment: .leading, spacing: 2) {
                leading
                trailing
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                leading
                Spacer(minLength: 8)
                trailing
            }
        }
    }
}
