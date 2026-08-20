import SwiftUI

extension View {
    /// The names search field, on the two screens that have one — and only
    /// where the screen holds something a query could ever match.
    ///
    /// The condition is "there is nothing here at all", never "this query
    /// matched nothing": somebody who typed something and got no results needs
    /// the field more than anyone, because it is the only way to clear what
    /// they typed.
    ///
    /// A branch rather than a disabled field, because SwiftUI has no
    /// "searchable, but off" — and **one direction of that flip is not free on
    /// a sheet**. Taking the Log again sheet from no-field to field after it
    /// was already up left the sheet blank — no title, no list — on every
    /// fixture and every text size. The other direction is fine there, and
    /// both are fine on a pushed screen. So a caller whose condition can turn
    /// *on* while its screen is presented must ask the question in a form that
    /// starts true — see `RepeatView`.
    @ViewBuilder
    func searchableNames(_ text: Binding<String>, when hasAnythingToSearch: Bool) -> some View {
        if hasAnythingToSearch {
            searchable(text: text, prompt: "Search names")
        } else {
            self
        }
    }
}
