import Foundation

/// Gets the document onto disk, later and elsewhere.
///
/// An actor rather than a `nonisolated async` function: under Swift 6 such a
/// call from the main actor is not guaranteed to leave it, and encoding must
/// never happen on the way to the next frame. Being serial, two saves also
/// cannot interleave onto the same file.
actor StoreSaver {

    /// A coalescing window, not a trailing debounce: the timer starts at the
    /// *first* unsaved change, so continuous typing still reaches disk every half
    /// second instead of being postponed indefinitely.
    private let window: Duration
    private let file: StoreFile

    private var pending: StoreDocument?
    private var pendingRevision: UInt64 = 0
    private var writtenRevision: UInt64 = 0
    private var writer: Task<Void, Never>?

    private(set) var lastError: (any Error)?

    /// Writes actually performed, so the debounce can be asserted rather than
    /// assumed.
    private(set) var writeCount = 0

    init(file: StoreFile, window: Duration = .milliseconds(500)) {
        self.file = file
        self.window = window
    }

    /// Takes ownership of the newest version of the document.
    ///
    /// The revision matters because the store hands documents over from the main
    /// actor through unstructured tasks, which are not delivered in the order they
    /// were created; without it a stale document arriving late would win.
    func save(_ document: StoreDocument, revision: UInt64) {
        guard revision >= pendingRevision, revision > writtenRevision else { return }
        pending = document
        pendingRevision = revision
        guard writer == nil else { return }
        writer = Task {
            // Cancellation here means "write now", not "give up" — that is how
            // `flush()` turns the pending change into an immediate write.
            try? await Task.sleep(for: self.window)
            self.writePending()
        }
    }

    /// Waits for the write that is already on its way, without hurrying it.
    ///
    /// **This is how an ordinary save finds out whether it worked.** `save` returns
    /// the moment the document is queued, so without this `lastError` went unread
    /// on every path except `flush` — a user logging all evening onto a full disk
    /// was told nothing until the app was next backgrounded.
    ///
    /// Deliberately not `flush`: it forces nothing early, so a burst of edits is
    /// still one write and everything scheduled in one window comes back together.
    func settled() async {
        await writer?.value
    }

    /// Writes anything outstanding and waits for it to land. It takes the document
    /// rather than trusting what has been scheduled: a change made microseconds
    /// before backgrounding may still be in flight, and that is exactly the change
    /// most worth not losing.
    func flush(_ document: StoreDocument, revision: UInt64) async {
        save(document, revision: revision)
        let inFlight = writer
        inFlight?.cancel()
        await inFlight?.value
        // A change scheduled while we were waiting above would have found
        // `writer` still set and not started a timer of its own.
        writePending()
    }

    private func writePending() {
        writer = nil
        guard let document = pending else { return }
        pending = nil
        do {
            try file.write(document)
            writeCount += 1
            writtenRevision = pendingRevision
            lastError = nil
        } catch {
            lastError = error
            // Hold on to it: the next change or flush retries. Dropping it would
            // leave the in-memory state and the file disagreeing forever.
            pending = document
        }
    }
}
