import SwiftUI
import UniformTypeIdentifiers

/// The escape hatch promised by rule 6: complete JSON out and back in, a CSV
/// view for spreadsheets, and the one action that ends with nothing left.
struct DataTransferView: View {
    @Environment(Store.self) private var store

    @State private var isImporting = false
    @State private var pendingImport: Data?
    @State private var isRestoringBackup = false
    @State private var isChoosingImportMode = false
    /// Whether the document a destructive action is about to replace could come
    /// back out of the recovery slot. Captured when the button is tapped rather
    /// than read from inside the alert: the check walks every tracker and entry,
    /// and the document cannot change while the alert is up.
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

    /// **A `ShareLink` will not present from a container that carries a
    /// `.confirmationDialog`.** No sheet, no error, nothing in the log; a
    /// `Button` beside it works on the same tap. That dialog is the import
    /// merge/replace chooser, and while export and import shared one section it
    /// silently took the share sheet with it.
    ///
    /// So the two directions are two sections, and the import section owns every
    /// presentation that belongs to importing. **Do not "simplify" these back
    /// into one section** — nothing looks broken, the rows still draw, and the
    /// button just stops working.
    var body: some View {
        let json = exportFile(.json)
        let csv = exportFile(.csv)
        return Group {
            Section {
                ShareLink(item: json, preview: SharePreview(json.filename)) {
                    Label("Share JSON…", systemImage: "square.and.arrow.up")
                }
                .formRowAccent()
                ShareLink(item: csv, preview: SharePreview(csv.filename)) {
                    Label("Share CSV…", systemImage: "square.and.arrow.up")
                }
                .formRowAccent()
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
                .formRowAccent()
                if store.hasImportBackup {
                    Button("Restore Previous Data…", systemImage: "arrow.uturn.backward") {
                        isRestoringBackup = true
                        presentedAlert = .confirmReplace
                    }
                    .formRowAccent()
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
            // One `.alert(item:)` for the whole screen, on the section that
            // already carries the `.confirmationDialog`, so no other section
            // acquires a presentation — see `ShareLink` above.
            .alert(item: $presentedAlert, content: alert)

            // Off when there is nothing to delete, rather than raising a dialog
            // that offers to remove nothing.
            Section {
                Button(role: .destructive) {
                    isRecoverable = store.currentDocumentIsRestorable
                    presentedAlert = .confirmClear
                } label: {
                    // **"All Data", not "Everything".** `TrackerEditor`'s
                    // *Delete Everything* takes one tracker with its history and
                    // says, correctly, that it cannot be undone. Two buttons with
                    // one name and opposite promises, both reached from this
                    // screen, is how somebody learns here that it is recoverable
                    // and finds out there that it is not.
                    Label("Delete All Data…", systemImage: "trash")
                }
                .disabled(!hasAnything)
            } footer: {
                // Hedged, deliberately: whether the copy can be read back is an
                // O(n) question, and a footer is drawn on every body pass while a
                // confirmation is built once. So it says what normally happens
                // and points at the sentence that knows.
                Text("Removes every tracker and entry from this device. The document you have now is normally kept as a recoverable copy, so this can be undone until the next import or clear replaces it — the confirmation says if it cannot be.")
            }
        }
    }

    /// Built on every body pass, which is why `ExportFile` carries the document
    /// rather than the encoded bytes.
    private func exportFile(_ format: ExportFile.Format) -> ExportFile {
        ExportFile(stem: stem(format), format: format, document: store.document)
    }

    /// The undated stem. The date is added at the moment of use, so a settings
    /// screen left open across midnight cannot hand the share sheet yesterday's
    /// name.
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
                // Only when it is true of the run that just happened. An import
                // that changed nothing does not take the recovery slot, so there
                // may be no copy at all — and a reassurance the Settings list
                // then contradicts is worse than none.
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

    /// Grouped, because the number is the whole point of the clear confirmation
    /// and `1247` is a number you skim past.
    private func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value.formatted()) \(value == 1 ? singular : plural)"
    }

    private var hasAnything: Bool {
        !store.trackers.isEmpty || !store.entries.isEmpty
    }

    private func clearEverything() {
        Task {
            do {
                let summary = try await store.clearAll()
                presentedAlert = .message(
                    title: "Everything deleted",
                    // Not `describe(_:)`, which leads with what was added: a
                    // clear can never add anything, so that sentence would put
                    // "Added 0 trackers and 0 entries" in front of the only
                    // number on the screen that means anything.
                    detail: "Removed \(count(summary.trackersRemoved, "tracker", "trackers")) "
                        + "and \(count(summary.entriesRemoved, "entry", "entries"))."
                        // `keptBackup` only says the copy was *written*. Whether
                        // it can be read back out again is the other question,
                        // and it is the one the confirmation just answered — so a
                        // document warned about as unrecoverable must not be
                        // told, one alert later, that Restore brings it back.
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
            // One confirmation, naming the count: a number is what makes somebody
            // stop, and a second dialog behind the first protects nothing the
            // first did. `.cancel` is the bold button in a two-button alert, so
            // the tap your thumb finds is the one that keeps your data.
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

    /// Only a decode failure is evidence about the file. Every other error on the
    /// import path used to be reported as a damaged export, and an import can
    /// fail because a *write* failed — the pre-import copy, or the imported
    /// document itself. So a phone that had run out of storage told its owner
    /// their backup was corrupt and sent them off to re-export a file that was
    /// fine.
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
                // `describe`, not a sentence of its own: written separately this
                // one counted removed entries and stayed silent about removed
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
