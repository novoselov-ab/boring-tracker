import SwiftUI

extension DynamicTypeSize {
    /// Whether a row has given up on fitting what it is and what it says on one
    /// line.
    ///
    /// `.xxxLarge`, not `isAccessibilitySize`: on an SE, "Calories burned
    /// exercising" beside "1,234,567 kcal" leaves "Calo…" at `.xxxLarge`, which
    /// does not tell that row from the "Calories" one under it. `.xxLarge`
    /// still leaves "Calorie…", which reads, and is where the density is still
    /// worth having.
    ///
    /// One threshold read from four places, so the card and the three list
    /// screens cannot answer it differently.
    var stacksRows: Bool { self >= .xxxLarge }
}

/// One row's two halves — what it is on the leading side, what it was or when
/// it happened on the trailing one — beside each other while they both fit, and
/// stacked once they do not.
///
/// `spacing: 0` on the side-by-side branch, with the whole gap coming from the
/// `Spacer`, and that number is measured: an `HStack` inserts its spacing on
/// *both* sides of a spacer, so `spacing: 8` around `Spacer(minLength: 8)`
/// reserved 24pt rather than 8 — and since the trailing half is sized first,
/// the surplus came out of the leading half's truncation budget.
///
/// Nothing here is priority: which half gives way is the caller's decision and
/// differs between them. What this owns is the arrangement and the threshold,
/// which is the part that must not disagree — so the alignment is not a
/// parameter either.
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
            // `.center` rather than `.firstTextBaseline`, which put the number
            // on the same baseline as the *first* line of the leading half — so
            // a card whose label is two lines, "Weight" over "yesterday", hung
            // its number off the top of the row while the `+` beside it stayed
            // centred. What it costs is the shared baseline on a one-line row.
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
struct TrackerRowName: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let name: String
    var caption: String?
    /// Home caps to one line: a name is unbounded free text, and "Calories
    /// burned exercising" wrapping to three lines puts back exactly the row
    /// height item 11 cut — the number beside it still says which tracker you
    /// are reading. **Settings has no number**, so a truncated name there is
    /// the whole of what identifies the row, and two trackers sharing a long
    /// prefix would be indistinguishable on the one screen where you pick which
    /// to edit, archive or delete.
    ///
    /// The cap lifts by itself past `stacksRows`: past it the row has given up
    /// on one line anyway and a cap would only clip.
    var capped = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Primary, like the number beside it on home: the name is the only
            // thing on the row that says which tracker you are reading. The
            // hierarchy is carried by size and weight instead.
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
    /// The default inset-grouped row adds 46pt of its own, which is most of a
    /// second row; this cuts it to 4pt above and below a 44pt row. The trailing
    /// 12 is smaller than the leading 16 because what sits there is a 44pt box
    /// around a 30pt disc: 12 plus the box's own 7 is 19pt of air, against 16 at
    /// the other end.
    ///
    /// **`.listRowInsets` has to be applied outside `.onGeometryChange`, and
    /// that is not a style choice.** Settings reads every row's frame for its
    /// drop target, and insets written *under* that reader — inside the row view
    /// it wraps — are silently dropped: the build compiles, the row draws, and
    /// it keeps the platform's 74pt.
    ///
    /// **`.swipeActions` is not one of these, and that was checked rather than
    /// assumed.** `HistoryRow` applies its insets inside the row with
    /// `.swipeActions` outside and measures 52pt; a probe build with settings'
    /// own archived rows in that same order measures 52 as well, while the
    /// active rows under the geometry reader stay at 74.
    static let listRow = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12)
}

/// One logged row's leading half: what it was called on the first line, what it
/// was on the second. The identity leads because the eye lands on what a row
/// *is* before it lands on its numbers.
///
/// **`identity` is optional, and only tracker detail passes nothing.** A
/// tracker's own screen has already said which tracker it is, in the navigation
/// title, so an entry nobody named would lead with the title repeated down every
/// row.
///
/// Blank counts as nothing, and it is a guard on *nothing at all* rather than a
/// repair of a thin line: on a row whose repeat is off, History appends a reason
/// to the identity, so that row arrives as `" · Archived"` — not empty, and
/// drawn as it is. Fixing a blank name belongs to the line's own builder.
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
