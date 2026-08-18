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
    /// The write whose offer has already run out, if one has.
    ///
    /// **It names the write rather than answering the question**, and that is
    /// the whole of the design. Elapsed time is not state SwiftUI observes, so
    /// something has to change to make a redraw happen at the moment the offer
    /// lapses — but a plain `false` would be a second answer to "does the offer
    /// stand", and a stale one: History mounts this bar for the life of the
    /// screen, so one instance serves every offer there, and a flag left `false`
    /// by the last one would suppress the bar for the next write until the task
    /// got round to setting it back. Naming the write cannot go stale, because
    /// the next write is a different date.
    ///
    /// It is a second condition all the same, and the clock is the one that
    /// normally decides — the pair only comes apart if the wall clock moves
    /// backwards during an offer, where this is what still ends it.
    @State private var lapsed: Date?
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

    /// How long an offer to undo a **repeat** stands, on every screen that draws
    /// this bar.
    ///
    /// **One place, because the same ten hard-coded twice is how the two screens
    /// drifted** (docs/TODO.md item 20b). Item 20 gave home's offer ten seconds
    /// and History's went on standing for the rest of the session, so one bar
    /// meant "just now" on one screen and "at some point today" on the other.
    ///
    /// Ten seconds is the count-up finishing (0.8s), plus long enough to read
    /// the number, decide it was the wrong row and reach the button — and short
    /// enough that the offer belongs to the tap that made it.
    ///
    /// **The deletion offer is deliberately not expired, here or anywhere.** The
    /// two are not symmetric and `Store.forgetRepeatUndo` already records half
    /// of why: undoing a repeat *removes* entries by id, so an offer outliving
    /// its write destroys data, while undoing a deletion only puts records back.
    /// The other half is that it is the only way back from the app's one
    /// destructive gesture — a swipe takes a row with no confirmation and
    /// nothing else restores it — so expiring it would trade a stale but
    /// harmless offer for data gone for good eleven seconds after a wrong swipe.
    static let repeatOffer: TimeInterval = 10

    var body: some View {
        content
            // The other half of the expiry, and each half covers the other's
            // hole. A predicate alone leaves the bar drawn until something else
            // invalidates the body, which nothing here would do; a sleep alone
            // hands out a fresh ten seconds every time the view comes back,
            // because pushing a screen cancels this task and restarting it is
            // indistinguishable from a new write unless the arithmetic is done
            // against the clock (docs/TODO.md item 20b, and the hole item 20
            // fell into on home).
            //
            // So it sleeps for what is *left* of the offer, recomputed each
            // time this bar reappears, and the predicate keeps any redraw in
            // between honest.
            .task(id: store.lastLoggedAgainAt) {
                guard let at = store.lastLoggedAgainAt else { return }
                let remaining = Self.repeatOffer - Date().timeIntervalSince(at)
                if remaining > 0 {
                    try? await Task.sleep(for: .seconds(remaining))
                    guard !Task.isCancelled else { return }
                }
                lapsed = at
            }
    }

    @ViewBuilder
    private var content: some View {
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
            // Expired, so nothing: the store keeps one slot, and a repeat is in
            // it. Undo is not gone — the write is an ordinary batch in History
            // and a swipe removes it — but the *offer* stops being one, which
            // is what a bar reading "Logged again" is for.
            //
            // The clock decides in every ordinary case and `lapsed` only says
            // which write the task has already seen out, so the worst a missed
            // task can do is leave the bar drawn until the next redraw — never
            // hide the offer for a write that has just happened.
            guard let at = store.lastLoggedAgainAt, lapsed != at,
                  Date().timeIntervalSince(at) < Self.repeatOffer
            else { return nil }
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
