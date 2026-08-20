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
/// **`.center`, and it is the trailing half this is for** (docs/TODO.md item
/// 37). The row read `.firstTextBaseline` until then, which put the number on
/// the same baseline as the *first* line of the leading half — so a card whose
/// label is two lines, "Weight" over "yesterday", hung its number off the top
/// of the row while the `+` beside it stayed centred. Measured on an iPhone 17
/// Pro against the disc's own centre, which is the row's: the digits sat
/// **5.83pt high** and now sit 0.17pt off it, the same 0.17 a one-line row
/// already measured. Row heights are unchanged — every card is 52.0pt before
/// and after.
///
/// What it costs is the shared baseline on a one-line row: "Water" and "0 ml"
/// sat on one line and the name now rides 2.67pt higher, centred against a
/// number half again its size. Photographed side by side before choosing, and
/// it is the smaller of the two: a baseline two type sizes share is a nicety on
/// the rows that were already right, and the two-line row was visibly broken.
///
/// It is one alignment for all four screens rather than a parameter, and that
/// is a decision about a *shared* view: a History row's time leaves the
/// identity line it used to sit on and lands level with the repeat disc at the
/// end of the same row, which is the same rule reading the same way. A caller
/// that wants the old pairing would be the second answer this type exists to
/// prevent — see the note about the threshold below.
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
            // `.center`: the trailing half is centred against the whole row,
            // whatever the leading half's height. See the note above for what
            // that fixes and what it costs.
            HStack(alignment: .center, spacing: 0) {
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
/// name: home dates the last reading, and settings says what tapping the row
/// would edit — the kind and the unit, plus the group on an archived row,
/// which has no heading over it to say so (docs/TODO.md item 37). `.caption2`
/// in `.secondary` — the name is what identifies the row and the caption
/// annotates it. Absent on most of home's rows and on none of settings', which
/// is why the parameter is optional and why settings' own row builder is where
/// the wording lives.
///
/// **One line until the text outgrows it, and the caller decides whether even
/// that.** A name is unbounded free text — the editor sets no limit — so on
/// home "Calories burned exercising" wrapping to three lines would put back
/// exactly the row height item 11 cut, and the number beside it still says
/// which tracker you are reading when the name truncates. **Settings has no
/// number**, so a truncated name there is the whole of what identifies the row,
/// and two trackers sharing a long prefix would be indistinguishable on the one
/// screen where you pick which to edit, archive or delete. So settings passes
/// `capped: false` and wraps, which is what it did before item 28 extracted
/// this; home keeps the cap.
///
/// The cap lifts by itself past `stacksRows` — the same threshold `StackingRow`
/// above uses, asked in the same way — because past it the row has given up on
/// one line anyway and a cap would only clip.
struct TrackerRowName: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let name: String
    var caption: String?
    /// See the note above: home caps to one line, settings does not.
    var capped = true

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
        .lineLimit(capped && !typeSize.stacksRows ? 1 : nil)
    }
}

extension EdgeInsets {

    /// A list row with a 44pt control at its trailing end — home's cards, a
    /// History row, a Log again row, a settings tracker row.
    ///
    /// **Measured once in item 11 and written out four times until item 28.**
    /// The default inset-grouped row adds 46pt of its own, which is most of a
    /// second row; home cut that to 4pt above and below a 44pt row, and the
    /// three other lists drawing the same shape copied the literal. Settings
    /// was the one that had not, at 74pt against home's 52 — which is what item
    /// 28 was reported for — so the number is here now and the fourth screen
    /// got it by naming it rather than by someone noticing.
    ///
    /// The trailing 12 is smaller than the leading 16 because what sits there
    /// is a 44pt box around a 30pt disc: 12 plus the box's own 7 is 19pt of
    /// air, against 16 at the other end.
    ///
    /// **Two settings rows have no such box** — an archived one, and an active
    /// one on a list of a single tracker, where the drag handle is absent by
    /// design. There the trailing element is a bare `chevron.right`, which lands
    /// about 15pt from the cell edge against the 21pt iOS gives the *About* row
    /// two sections below it. Left alone: it is 6pt on a screen nobody's day
    /// runs through, and the alternative is a second constant or a conditional
    /// inset, either of which is how one number becomes two.
    ///
    /// **`.listRowInsets` has to be applied outside `.onGeometryChange`, and
    /// that is not a style choice.** Settings reads every row's frame for its
    /// drop target, and insets written *under* that reader — inside the row
    /// view it wraps — are silently dropped: the build compiles, the row draws,
    /// and it keeps the platform's 74pt. Two settings builds looked identical to
    /// each other before the accessibility tree said why.
    ///
    /// **`.swipeActions` is not one of these, and that was checked rather than
    /// assumed.** The first reading of this blamed the swipe, because the fix
    /// moved the modifier past both at once. It does not: `HistoryRow` has
    /// applied its insets inside the row with `.swipeActions` outside since item
    /// 11 and measures **52pt**, and a probe build with settings' own archived
    /// rows in that same order measures 52 as well while the active rows under
    /// the geometry reader stay at 74. One binary, both answers, read off the
    /// tree.
    static let listRow = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12)
}

/// One logged row's leading half: what it was called on the first line, what it
/// was on the second.
///
/// **Extracted because History and tracker detail disagreed about the order**
/// (docs/TODO.md item 35). Item 14b put the identity first on History — the eye
/// lands on what a row *is* before it lands on its numbers — and the Log again
/// sheet followed, while tracker detail kept drawing the number on top with the
/// name grey underneath. Two screens one tap apart, the same two facts, opposite
/// orders. Three copies of one shape is how that happened, so there is one of it
/// and all three call it.
///
/// The weights are History's, unchanged: the identity is a `.footnote` in
/// `.secondary` and the values line is body text in the primary colour. Quiet
/// was asked for deliberately in item 13 and item 14b fixed the order without
/// re-loudening it, so the hierarchy here is position, not size.
///
/// **`identity` is optional, and only tracker detail passes nothing.** A History
/// or Log again row always has something to lead with — your name for it, or
/// the tracker, or the group it was logged as — because those lists mix
/// trackers and a row has to say which one it is. A tracker's own screen has
/// already said, in the navigation title, so an entry nobody named would lead
/// with the title repeated down every row. It draws the value alone instead:
/// one line, the same size and colour a named row's value line has, and the
/// number leads on exactly the rows where there is nothing else to lead with.
///
/// Blank counts as nothing, and that is here rather than at the call site: this
/// view owns what "no identity" means, and a caller passing an empty string
/// otherwise gets an empty `Text` and 2pt of spacing above the value — a line
/// of nothing that reads as a layout bug.
///
/// It is a guard on *nothing at all*, not a repair of a thin line, and the
/// difference was pointed out in review. `HistoryItem.Line.identity` can come
/// back blank on a hand-edited file whose tracker has no name, and on a row
/// whose repeat is off History appends a reason to it — so that row arrives
/// here as `" · Archived"`, which is not empty and is drawn as it is. Unchanged
/// by this extraction, and it belongs to the line's own builder rather than to
/// the view that draws it; the small-things list carries the blank-name case.
///
/// The trailing half stays with the caller: History and tracker detail put the
/// time there and the Log again sheet puts the day, and which half gives way
/// when they will not fit is `StackingRow`'s business rather than this one's.
struct LogRowLabel: View {
    var identity: String?
    let values: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let identity, !identity.isEmpty {
                Text(identity)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(values)
        }
    }
}
