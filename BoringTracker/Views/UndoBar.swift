import SwiftUI

/// The one undo, at the bottom of the screen that wrote the thing.
///
/// It used to be a section above History's first day, which works only while
/// you are already looking at the top — and neither thing it undoes happens
/// there. Repeating is a tap on a row you scrolled or searched to find;
/// deleting is a swipe on that same row. In both cases the top of the list is
/// off screen, so the undo appeared where the user was not, and the tap itself
/// had no visible result at all. An undo you cannot see is not an undo, and
/// this is the bar idiom home's Log already uses (docs/PHILOSOPHY.md,
/// "frequent actions live low").
///
/// One bar, because the store keeps one undo slot: two undo affordances in two
/// places on one screen is a screen saying the same thing twice, which is the
/// complaint docs/TODO.md item 13 is named after. One *view*, for the same
/// reason across screens — History and Repeat both write through `logAgain`,
/// and a second copy of this is a second chance for the two to word it
/// differently.
struct UndoBar: View {
    @Environment(Store.self) private var store
    /// Whether a pending *deletion* is offered here as well as a repeat.
    ///
    /// True on History, which is where deleting happens. False on Repeat, which
    /// cannot delete anything: a deletion's offer is deliberately never expired
    /// — undoing one only puts records back, so it can go stale harmlessly —
    /// and without this, swiping a row away on History and then opening Repeat
    /// pinned "Deleted batch" over a screen that had done nothing, offering to
    /// restore a row it would not then show. This bar is the undo of the screen
    /// that wrote the thing; History keeps the deletion undo either way,
    /// because the slot survives the trip.
    var offersDeletion = true

    var body: some View {
        if let message {
            HStack {
                Text(message)
                    .foregroundStyle(.secondary)
                    // On the message rather than on the bar. At default sizes
                    // the button's 44pt sets the height and this is slack
                    // inside it; above the accessibility sizes the message is
                    // the taller of the two and sets the height itself, and
                    // without this its wrapped lines render flush against both
                    // edges of the material. Padding the bar instead would buy
                    // the same margin by making it 12pt taller at every size,
                    // for a case that only happens at the top of the range.
                    .padding(.vertical, 6)
                Spacer()
                // It used to be the accent as *text* on the bar, which is the
                // pairing item 13c removes: 1.89:1 in light mode, on the one
                // control in the app that exists to be found in a hurry.
                // `UndoButton` carries the shape and the reasons, and the
                // tracker detail screen's own undo row draws the same one.
                UndoButton(action: undo)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    /// What the pending undo would take back. A repeat wins when both could be
    /// set, which cannot happen — the store's slot holds one — so this is the
    /// order the two are read in, not a priority between them.
    private var message: String? {
        if let logged = store.lastLoggedAgain {
            // Named honestly when the row was only partly repeatable: the tap
            // promised the row and wrote less than the row, and the alternative
            // is a button that quietly does something other than what it says.
            return logged.skipped == 0
                ? "Logged again"
                : "Logged \(logged.count) of \(logged.count + logged.skipped) again"
        }
        if offersDeletion, store.lastDeletion != nil {
            return store.lastDeletionCount == 1 ? "Deleted entry" : "Deleted batch"
        }
        return nil
    }

    private func undo() {
        if store.lastLoggedAgain != nil {
            store.undoLastLog()
        } else {
            store.undoLastDeletion()
        }
    }
}
