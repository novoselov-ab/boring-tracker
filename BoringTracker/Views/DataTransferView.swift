import SwiftUI
import UniformTypeIdentifiers

/// The escape hatch promised by rule 6: complete JSON out and back in, plus a
/// CSV view for spreadsheets, and the one action that ends with nothing left.
/// These are the app's destructive workflows, so merge and replace are said
/// apart before either one runs and a clear says what it is about to remove.
struct DataTransferView: View {
    @Environment(Store.self) private var store

    @State private var isImporting = false
    @State private var pendingImport: Data?
    @State private var isRestoringBackup = false
    @State private var isChoosingImportMode = false
    /// Whether the document a destructive action is about to replace could come
    /// back out of the recovery slot — see `Store.currentDocumentIsRestorable`.
    ///
    /// Captured when the button is tapped rather than read from inside the
    /// alert: the check walks every tracker and entry, and an alert's content
    /// is not somewhere to put an O(n) question about a document that cannot
    /// change while the alert is up.
    @State private var isRecoverable = true
    @State private var presentedAlert: PresentedAlert?

    private enum PresentedAlert: Identifiable {
        case confirmReplace
        case confirmClear
        case message(title: String, detail: String)

        var id: String {
            switch self {
            case .confirmReplace: "confirm-replace"
            case .confirmClear: "confirm-clear"
            case .message(let title, let detail): "message:\(title):\(detail)"
            }
        }
    }

    /// Two sections, and the split is load-bearing rather than tidy-mindedness.
    ///
    /// **A `ShareLink` will not present from a container that carries a
    /// `.confirmationDialog`.** No sheet, no error, nothing in the log; a
    /// `Button` beside it works on the same tap. That dialog is the import
    /// merge/replace chooser, and while export and import shared one *Data*
    /// section it silently took the share sheet with it — which is why the
    /// export left through Files only and why `531d71c` recorded the share
    /// sheet as impossible in SwiftUI. It is not: give the dialog its own
    /// section and the `ShareLink` above presents.
    ///
    /// So the two directions are two sections, and the import section owns
    /// every presentation that belongs to importing. **Do not "simplify" these
    /// back into one section** — nothing about the result looks broken, the
    /// rows still draw, and the button just stops working (docs/TODO.md item
    /// 18b, docs/TECH.md).
    var body: some View {
        let json = exportFile(.json)
        let csv = exportFile(.csv)
        return Group {
            Section {
                ShareLink(item: json, preview: SharePreview(json.filename)) {
                    Label("Share JSON…", systemImage: "square.and.arrow.up")
                }
                ShareLink(item: csv, preview: SharePreview(csv.filename)) {
                    Label("Share CSV…", systemImage: "square.and.arrow.up")
                }
            } header: {
                Text("Export")
            } footer: {
                Text("JSON contains the complete document and can be imported again. CSV is one row per entry for spreadsheets.")
            }

            Section {
                Button("Import JSON", systemImage: "square.and.arrow.down") {
                    isRestoringBackup = false
                    isImporting = true
                }
                // "Previous Data", not "Data Before Last Import", since item 24:
                // the slot is filled by a clear as well as by an import, and a
                // row offering to undo the import you did last week when what
                // it holds is the document you cleared a minute ago is a wrong
                // sentence about the one action that undoes a destructive one.
                // The alert this row raises has always called it that.
                if store.hasImportBackup {
                    Button("Restore Previous Data…", systemImage: "arrow.uturn.backward") {
                        isRestoringBackup = true
                        presentedAlert = .confirmReplace
                    }
                }
            } header: {
                Text("Import")
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: selectImport
            )
            .confirmationDialog(
                "How should this file be imported?",
                isPresented: $isChoosingImportMode,
                titleVisibility: .visible
            ) {
                Button("Merge Documents") { importPending(mode: .merge) }
                Button("Replace Everything…", role: .destructive) {
                    presentedAlert = .confirmReplace
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("Merge combines records by ID. Deletions from either document stay deleted, newer edits win conflicts, and other distinct records are kept. Replace removes the current data and uses only the file. Either way, anything this changes is kept here as a recoverable backup.")
            }
            // Left on the import section, where it has always presented from.
            // It now serves the clear confirmation below as well as import's
            // own two alerts — one `.alert(item:)` for the screen, rather than a
            // second presentation attached to a section carrying a
            // `.confirmationDialog`, which is the shape that silently broke
            // `ShareLink` above.
            .alert(item: $presentedAlert, content: alert)

            // The third whole-document action, beside the two that already move
            // the whole document (docs/TODO.md item 24). One button, one
            // confirmation, and the safety is the recoverable copy rather than
            // the ceremony — see `Store.clearAll`.
            //
            // Off when there is nothing to delete, rather than raising a dialog
            // that offers to remove nothing.
            Section {
                Button(role: .destructive) {
                    isRecoverable = store.currentDocumentIsRestorable
                    presentedAlert = .confirmClear
                } label: {
                    // **"All Data", not "Everything".** `TrackerEditor` already
                    // has a *Delete Everything* — the one that takes a single
                    // tracker with its history — and it says, correctly, that it
                    // cannot be undone. Two buttons with one name and opposite
                    // promises, both reached from this screen, is how somebody
                    // learns here that "Delete Everything" is recoverable and
                    // then finds out there that it is not.
                    Label("Delete All Data…", systemImage: "trash")
                }
                .disabled(!hasAnything)
            } footer: {
                // Hedged, and deliberately: whether the copy can be read back
                // depends on the document, the check is O(n) over every entry,
                // and a footer is drawn on every pass of this screen's body
                // while a confirmation is built once. So the footer says what
                // normally happens and points at the sentence that knows.
                Text("Removes every tracker and entry from this device. The document you have now is normally kept as a recoverable copy, so this can be undone until the next import or clear replaces it — the confirmation says if it cannot be.")
            }
        }
    }

    /// What the share sheet is handed. Built on every body pass, which is why
    /// `ExportFile` carries the document rather than the encoded bytes.
    ///
    /// Reading `store.document` here is also what subscribes this screen to
    /// every entry and tombstone, where it used to watch nothing but the
    /// recovery file. That is three array retains on a screen nobody's day runs
    /// through, and the alternative — handing the store itself to a `Sendable`
    /// value that is read off the main actor — is not one.
    private func exportFile(_ format: ExportFile.Format) -> ExportFile {
        ExportFile(stem: stem(format), format: format, document: store.document)
    }

    /// The undated stem. The date is added at the moment of use, so a settings
    /// screen left open across midnight cannot hand the share sheet
    /// yesterday's name.
    private func stem(_ format: ExportFile.Format) -> String {
        format == .csv ? "boring-tracker-entries" : "boring-tracker"
    }




    private func selectImport(_ result: Result<[URL], any Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try Data(contentsOf: url)
            isRecoverable = store.currentDocumentIsRestorable
            isChoosingImportMode = true
        } catch {
            if !isCancellation(error) { show(error, action: "open") }
        }
    }

    private func importPending(mode: Store.ImportMode) {
        guard let pendingImport else { return }
        Task {
            do {
                let summary = try await store.importData(pendingImport, mode: mode)
                self.pendingImport = nil
                // Said for a merge as well as a replace, and only when it is
                // true of the run that just happened. An import that changed
                // nothing does not take the recovery slot, so on a fresh
                // install there may be no copy at all — and a reassurance the
                // Settings list then contradicts is worse than none.
                let backup = summary.keptBackup
                    ? " A backup of the previous document was kept on this device." : ""
                presentedAlert = .message(
                    title: "Import complete",
                    detail: "\(describe(summary))\(backup)"
                )
            } catch {
                show(error, action: "import")
            }
        }
    }

    /// Both directions, for both record types. A replace that removes trackers
    /// has to say so — see `Store.ImportSummary`.
    private func describe(_ summary: Store.ImportSummary) -> String {
        let added = "Added \(count(summary.trackersAdded, "tracker", "trackers")) and "
            + "\(count(summary.entriesAdded, "entry", "entries"))."
        let removed = "Removed \(count(summary.trackersRemoved, "tracker", "trackers")) and "
            + "\(count(summary.entriesRemoved, "entry", "entries"))."
        return "\(added) \(removed)"
    }

    /// "1 tracker", "1,247 entries". Grouped, because the number is the whole
    /// point of the clear confirmation and `1247` is a number you skim past.
    private func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value.formatted()) \(value == 1 ? singular : plural)"
    }

    /// Whether there is anything for a clear to remove.
    private var hasAnything: Bool {
        !store.trackers.isEmpty || !store.entries.isEmpty
    }

    private func clearEverything() {
        Task {
            do {
                let summary = try await store.clearAll()
                presentedAlert = .message(
                    title: "Everything deleted",
                    // Not `describe(_:)`, which leads with what was added. A
                    // clear can never add anything, so that sentence would put
                    // "Added 0 trackers and 0 entries" in front of the only
                    // number on the screen that means anything.
                    detail: "Removed \(count(summary.trackersRemoved, "tracker", "trackers")) "
                        + "and \(count(summary.entriesRemoved, "entry", "entries"))."
                        // `keptBackup` only says the copy was *written*.
                        // Whether it can be read back out again is the other
                        // question, and it is the one the confirmation just
                        // answered — so a document that was warned about as
                        // unrecoverable must not be told, one alert later, that
                        // Restore brings it back.
                        + (summary.keptBackup && isRecoverable
                            ? " Restore Previous Data brings it back."
                            : "")
                )
            } catch {
                show(error, action: "delete")
            }
        }
    }

    private func alert(_ alert: PresentedAlert) -> Alert {
        switch alert {
        case .confirmReplace:
            Alert(
                title: Text(isRestoringBackup ? "Restore previous data?" : "Replace all current data?"),
                message: Text(isRestoringBackup
                    ? "Every current tracker and entry will be replaced by the document saved before the last import. The current document will take its place as the recoverable backup."
                    : isRecoverable
                    ? "Every current tracker and entry will be removed and replaced by this file. The current document will remain recoverable here until the next import."
                    : "Every current tracker and entry will be removed and replaced by this file, and this one cannot be undone: the file on this device holds records that Restore would refuse. Share a copy from Export first if you want to keep anything."),
                primaryButton: .destructive(Text(isRestoringBackup ? "Restore Previous Data" : "Replace Everything")) {
                    if isRestoringBackup {
                        restoreBackup()
                    } else {
                        importPending(mode: .replace)
                    }
                },
                secondaryButton: .cancel {
                    pendingImport = nil
                    isRestoringBackup = false
                }
            )
        case .confirmClear:
            // **One confirmation, and it names the count.** A number is what
            // makes somebody stop; "are you sure" is what they tap through, and
            // a second dialog behind the first protects nothing the first did
            // (docs/TODO.md item 24).
            //
            // Destructive, and not the default button: `.cancel` is the bold
            // one in a two-button alert, so the tap your thumb finds is the one
            // that keeps your data.
            //
            // Export is *suggested* rather than required. Gating a clear behind
            // an export would put a file-picker in front of somebody who has
            // already decided, and the recoverable copy — not the export — is
            // what makes the decision safe to make. The Export rows are two
            // sections up on this same screen, so pointing at them is a real
            // offer rather than a shrug.
            Alert(
                title: Text("Delete \(count(store.trackers.count, "tracker", "trackers")) and \(count(store.entries.count, "entry", "entries"))?"),
                message: Text(isRecoverable
                    ? "Everything logged on this device goes. What you have now is kept as a recoverable copy, so Restore Previous Data brings it all back — until the next import or clear takes its place. If you want a copy that outlives that, share one from Export first."
                    : "Everything logged on this device goes, and this one cannot be undone: the file on this device holds records that Restore would refuse, so no copy worth keeping can be made here. Share a copy from Export first if you want to keep anything."),
                primaryButton: .destructive(Text("Delete All Data")) { clearEverything() },
                secondaryButton: .cancel()
            )
        case .message(let title, let detail):
            Alert(title: Text(title), message: Text(detail), dismissButton: .default(Text("OK")))
        }
    }

    /// Says what actually went wrong.
    ///
    /// Only a decode failure is evidence about the file. Every other error on
    /// the import path used to be reported as a damaged export, and an import
    /// can now fail because a *write* failed — the pre-import copy, or the
    /// imported document itself. So a phone that had run out of storage told
    /// its owner their backup was corrupt and sent them off to re-export a file
    /// that was fine, while the real problem, which was also breaking every
    /// ordinary save, went unmentioned.
    ///
    /// "Nothing was changed" survives the correction: import and restore both
    /// fail before they touch memory, whichever step threw.
    private func show(_ error: any Error, action: String) {
        pendingImport = nil
        // True of a clear for the same reason it is true of the other two: the
        // transaction is one `Store.applyIncoming`, and every way it can fail
        // throws before memory or the live file has moved.
        let unchanged = ["import", "restore", "delete"].contains(action) ? " Nothing was changed." : ""
        let detail: String
        if let storeError = error as? StoreError {
            detail = storeError.errorDescription ?? "This file uses a schema this version cannot read.\(unchanged)"
        } else if error is DecodingError {
            detail = action == "restore"
                ? "The document saved before the last import could not be read.\(unchanged)"
                : "The selected file is not a valid Boring Tracker export or is damaged.\(unchanged)"
        } else {
            detail = "\((error as NSError).localizedDescription)\(unchanged)"
        }
        presentedAlert = .message(title: "Couldn’t \(action)", detail: detail)
    }

    private func restoreBackup() {
        Task {
            do {
                let summary = try await store.restoreImportBackup()
                isRestoringBackup = false
                // The same sentence import uses. Written separately, this one
                // counted removed entries and stayed silent about removed
                // trackers — which is exactly what a restore is most likely to
                // remove, since it undoes an import that added them.
                presentedAlert = .message(
                    title: "Restore complete",
                    detail: "\(describe(summary))"
                        + " The document you replaced is now the recoverable backup."
                )
            } catch is CancellationError {
                isRestoringBackup = false
            } catch {
                isRestoringBackup = false
                show(error, action: "restore")
            }
        }
    }

    private func isCancellation(_ error: any Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
}
