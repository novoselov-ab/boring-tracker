import SwiftUI

extension View {
    /// The names search field, on the two screens that have one — and only
    /// where the screen holds something a query could ever match.
    ///
    /// **This is item 25b's rule, applied to the other control on the screen.**
    /// History's jump-to-date button is absent when there is nowhere to jump
    /// to; the field beside it was left drawing itself under "Nothing logged
    /// yet" and under "Nothing to log again yet", in the thumb's arc, matching
    /// nothing by construction (docs/TODO.md item 25b). Absent rather than
    /// disabled, for the same reason the jump control is: a control you can put
    /// a finger on and cannot use is worse than one that is not there.
    ///
    /// **The condition is "there is nothing here at all", never "this query
    /// matched nothing".** Somebody who typed something and got no results
    /// needs the field more than anyone — it is the only way to change or clear
    /// what they typed — so it is keyed off the same emptiness that draws the
    /// screen's own empty state, and each screen passes the cheapest exact form
    /// of it that it has: `Store.entries` on History, the snapshot the Log
    /// again sheet already built on the other.
    ///
    /// One modifier rather than a `.searchable` on each screen, because the
    /// prompt is a promise about what the field looks at — names, not the
    /// identity line — and `HistoryItem.matches` answers that for both screens
    /// precisely so the two cannot disagree (docs/TODO.md item 16b). The words
    /// on the field are the other half of that and were written out twice.
    ///
    /// A branch, so the field is genuinely gone rather than hidden: SwiftUI has
    /// no "searchable, but off". What that costs is the identity of what it
    /// wraps across the flip, and **one direction of that flip is not free on a
    /// sheet**: taking the Log again sheet from no-field to field after it was
    /// already up left the sheet **blank** — no title, no list, nothing — on
    /// every fixture and every text size. Photographed. The other direction is
    /// fine there, and both directions are fine on a pushed screen: History
    /// with the store going from empty to logged underneath it (the undo of the
    /// last deletion) draws its rows and gets its field back, checked on a
    /// probe build that wrote an entry while the screen was up.
    ///
    /// So a caller whose condition can turn *on* while its screen is presented
    /// must ask the question in a form that starts true — see `RepeatView`,
    /// which counts its unbuilt snapshot as "something to search" for exactly
    /// this reason.
    @ViewBuilder
    func searchableNames(_ text: Binding<String>, when hasAnythingToSearch: Bool) -> some View {
        if hasAnythingToSearch {
            searchable(text: text, prompt: "Search names")
        } else {
            self
        }
    }
}
