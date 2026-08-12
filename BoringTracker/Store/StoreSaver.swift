import Foundation

/// Gets the document onto disk, later and elsewhere.
///
/// An actor rather than a plain `async` function, and deliberately so: under
/// Swift 6 a `nonisolated async` call from the main actor is not guaranteed to
/// leave it, and the whole point here is that encoding and writing must never
/// happen on the way to the next frame. An actor has its own executor, so the
/// work provably runs off the main actor and, being serial, two saves can never
/// interleave onto the same file.
actor StoreSaver {

    /// How long a change may sit in memory before it is written.
    ///
    /// This is a coalescing window, not a trailing debounce: the timer starts
    /// at the *first* unsaved change, so continuous typing still reaches disk
    /// every half second instead of being postponed indefinitely.
    private let window: Duration
    private let file: StoreFile

    private var pending: StoreDocument?
    private var pendingRevision: UInt64 = 0
    private var writtenRevision: UInt64 = 0
    private var writer: Task<Void, Never>?

    /// The last write failure, if any. Kept so the app can say so out loud
    /// rather than quietly losing data.
    private(set) var lastError: (any Error)?

    /// How many times the file has actually been written. The debounce is only
    /// worth having if this stays far below the number of edits, so it is
    /// something to assert rather than assume.
    private(set) var writeCount = 0

    init(file: StoreFile, window: Duration = .milliseconds(500)) {
        self.file = file
        self.window = window
    }

    /// Takes ownership of the newest version of the document.
    ///
    /// The revision matters because the store hands documents over from the
    /// main actor through unstructured tasks, which are not delivered in the
    /// order they were created. Without it, a stale document that arrived late
    /// would overwrite a newer one.
    func save(_ document: StoreDocument, revision: UInt64) {
        // Older than what is queued, or older than what is already on disk:
        // either way there is nothing here worth writing.
        guard revision >= pendingRevision, revision > writtenRevision else { return }
        pending = document
        pendingRevision = revision
        guard writer == nil else { return }  // a write is already on its way
        writer = Task {
            // Cancellation here means "write now", not "give up" — that is how
            // `flush()` turns the pending change into an immediate write.
            try? await Task.sleep(for: self.window)
            self.writePending()
        }
    }

    /// Writes anything outstanding and waits for it to land. Called when the
    /// app leaves the foreground, so backgrounding or force-quitting can lose
    /// at most the last moment of typing.
    ///
    /// It takes the document rather than trusting what has been scheduled: a
    /// change made microseconds before backgrounding may still be in flight,
    /// and that is exactly the change most worth not losing.
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
            // Hold on to it: the next change or flush retries. Dropping it
            // would mean the in-memory state and the file disagree forever.
            pending = document
        }
    }
}
