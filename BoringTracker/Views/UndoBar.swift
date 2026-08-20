import SwiftUI

/// The one undo, at the bottom of the screen that wrote the thing.
///
/// One bar and one view across screens, because the store keeps one undo slot
/// and History and Repeat both write through `logAgain`.
struct UndoBar: View {
    @Environment(Store.self) private var store
    /// The write whose offer has already run out, if one has.
    ///
    /// **It names the write rather than answering the question.** Elapsed time
    /// is not state SwiftUI observes, so something has to change to make a
    /// redraw happen when the offer lapses — but a plain `false` would go
    /// stale: History mounts this bar for the life of the screen, so one
    /// instance serves every offer there, and a flag left `false` by the last
    /// one would suppress the bar for the next write. A date cannot go stale,
    /// because the next write is a different one.
    @State private var lapsed: Date?
    /// Whether a pending *deletion* is offered here as well as a repeat.
    ///
    /// False on home, which has deleted nothing: without this, swiping a row
    /// away on History and going back pinned "Deleted batch" over a screen
    /// that had done nothing, offering to restore a row it would not show.
    ///
    /// It is deliberately a switch and not a *scope*. The slot is global, so a
    /// screen that must offer some deletions and not others gates the bar
    /// itself — `TrackerDetailView.offersUndo`.
    var offersDeletion = true

    /// How long an offer to undo a **repeat** stands, on every screen that
    /// draws this bar. Ten seconds is the count-up finishing (0.8s) plus long
    /// enough to read the number, decide it was the wrong row and reach the
    /// button.
    ///
    /// **The deletion offer is deliberately not expired, here or anywhere.**
    /// Undoing a repeat *removes* entries by id, so an offer outliving its
    /// write destroys data; undoing a deletion only puts records back, and it
    /// is the only way back from the app's one destructive gesture — a swipe
    /// takes a row with no confirmation and nothing else restores it.
    static let repeatOffer: TimeInterval = 10

    var body: some View {
        content
            // The other half of the expiry, and each half covers the other's
            // hole. A predicate alone leaves the bar drawn until something
            // else invalidates the body, which nothing here would do; a sleep
            // alone hands out a fresh ten seconds every time the view comes
            // back, because pushing a screen cancels this task and restarting
            // it is indistinguishable from a new write unless the arithmetic
            // is done against the clock.
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
                    // inside it; at the accessibility sizes the message is the
                    // taller of the two and its wrapped lines would otherwise
                    // render flush against both edges of the material. Padding
                    // the bar instead would buy the same margin by making it
                    // 12pt taller at every size.
                    .padding(.vertical, 6)
                Spacer()
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
            // Expired, so nothing: the store keeps one slot and a repeat is in
            // it. Undo is not gone — the write is an ordinary batch in History
            // and a swipe removes it — but the *offer* stops being one.
            //
            // `lapsed` only says which write the task has already seen out, so
            // the worst a missed task can do is leave the bar drawn until the
            // next redraw, never hide the offer for a write that just landed.
            guard let at = store.lastLoggedAgainAt, lapsed != at,
                  Date().timeIntervalSince(at) < Self.repeatOffer
            else { return nil }
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
