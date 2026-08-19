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
    /// being here at all. The card's own argument, which lived on a
    /// `TrackerCard.isStacked` that item 28 deleted once `TrackerRowName` took
    /// the last branch on it: the fallback was pitched at the accessibility
    /// sizes because that is where the name was first seen to collapse, but the
    /// top of the *normal* slider is already past it — on an SE, "Calories
    /// burned exercising" beside "1,234,567 kcal" leaves "Calo…" at
    /// `.xxxLarge`, which does not tell that row from the "Calories" one under
    /// it. `.xxLarge` still leaves "Calorie…" and is left alone: that reads, and
    /// it is where the density is still worth having.
    ///
    /// It costs the list rows nothing to stack a step early: checked on the
    /// `many` fixture at `.xxxLarge`, a History row is three lines either way —
    /// stacked it spends one on the time and gets the identity onto one line,
    /// side by side it wraps the identity onto two.
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
///
/// Both halves go in **as the caller wrote them, in both branches** — so a
/// `layoutPriority` meant for the side-by-side row also lands in the `VStack`,
/// where it is inert only because a `List` row's height is free. Worth knowing
/// before giving either branch a height it has to divide.
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

/// A tracker's name, and the quiet line under it — drawn one way on the two
/// screens that list trackers.
///
/// **Extracted because settings and home disagreed about it** (docs/TODO.md
/// item 28). Home's card has read `.subheadline` over a `.caption2` since item
/// 11, where the point of the item was that a name and a number fit on one
/// short row; settings drew the same trackers at `.body` in a 74pt row against
/// home's 52pt, which is the same list of the same things in two sizes, on two
/// screens one tap apart. The measured answer already existed, so this is home's
/// block moved rather than a third size chosen.
///
/// The caption is what the row has to say about the tracker underneath its
/// name: home dates the last reading, settings names the group an archived
/// tracker would come back to. Absent on most rows, and `.caption2` in
/// `.secondary` when it is there — the name is what identifies the row and the
/// caption annotates it.
///
/// **One line until the text outgrows it**, at `stacksRows` — the same
/// threshold `StackingRow` above uses, asked in the same way. A name is
/// unbounded free text (the editor sets no limit), so "Calories burned
/// exercising" wrapping to three lines would put back exactly the row height
/// item 11 cut; past the threshold the row has given up on one line anyway and
/// the cap would only clip it.
struct TrackerRowName: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let name: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Primary, like the number beside it on home. Grey means
            // "secondary" and the name is not: it is the only thing on the row
            // that says which tracker you are reading. The hierarchy is carried
            // by size and weight instead — `.subheadline` against home's medium
            // `.title2` — which still puts the number first at a glance.
            Text(name)
                .font(.subheadline)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(typeSize.stacksRows ? nil : 1)
    }
}
