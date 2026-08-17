import SwiftUI
import UniformTypeIdentifiers

/// The escape hatch promised by rule 6: complete JSON out and back in, plus a
/// CSV view for spreadsheets. Import is the app's only destructive workflow,
/// so merge and replace are said apart before either one runs.
struct DataTransferView: View {
    @Environment(Store.self) private var store

    @State private var exportDocument: ExportDocument?
    @State private var exportType: UTType = .json
    @State private var exportName = "boring-tracker"
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImport: Data?
    @State private var isRestoringBackup = false
    @State private var isChoosingImportMode = false
    @State private var presentedAlert: PresentedAlert?

    private enum PresentedAlert: Identifiable {
        case confirmReplace
        case message(title: String, detail: String)

        var id: String {
            switch self {
            case .confirmReplace: "confirm-replace"
            case .message(let title, let detail): "message:\(title):\(detail)"
            }
        }
    }

    var body: some View {
        Section {
            Button("Export JSON", systemImage: "square.and.arrow.up", action: exportJSON)
            Button("Export CSV", systemImage: "tablecells", action: exportCSV)
            Button("Import JSON", systemImage: "square.and.arrow.down") {
                isRestoringBackup = false
                isImporting = true
            }
            if store.hasImportBackup {
                Button("Restore Data Before Last Import…", systemImage: "arrow.uturn.backward") {
                    isRestoringBackup = true
                    presentedAlert = .confirmReplace
                }
            }
        } header: {
            Text("Data")
        } footer: {
            Text("JSON contains the complete document and can be imported again. CSV is one row per entry for spreadsheets.")
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportType,
            defaultFilename: exportName,
            onCompletion: finishExport
        )
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
        .alert(item: $presentedAlert, content: alert)
    }

    private func exportJSON() {
        do {
            exportDocument = ExportDocument(data: try store.exportData())
            exportType = .json
            exportName = ExportName.dated("boring-tracker")
            isExporting = true
        } catch {
            show(error, action: "export")
        }
    }

    private func exportCSV() {
        exportDocument = ExportDocument(data: store.exportCSV())
        exportType = .commaSeparatedText
        exportName = ExportName.dated("boring-tracker-entries")
        isExporting = true
    }

    private func finishExport(_ result: Result<URL, any Error>) {
        if case .failure(let error) = result, !isCancellation(error) {
            show(error, action: "export")
        }
        exportDocument = nil
    }

    private func selectImport(_ result: Result<[URL], any Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try Data(contentsOf: url)
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
        func phrase(_ count: Int, _ singular: String, _ plural: String) -> String {
            "\(count) \(count == 1 ? singular : plural)"
        }
        let added = "Added \(phrase(summary.trackersAdded, "tracker", "trackers")) and "
            + "\(phrase(summary.entriesAdded, "entry", "entries"))."
        let removed = "Removed \(phrase(summary.trackersRemoved, "tracker", "trackers")) and "
            + "\(phrase(summary.entriesRemoved, "entry", "entries"))."
        return "\(added) \(removed)"
    }

    private func alert(_ alert: PresentedAlert) -> Alert {
        switch alert {
        case .confirmReplace:
            Alert(
                title: Text(isRestoringBackup ? "Restore previous data?" : "Replace all current data?"),
                message: Text(isRestoringBackup
                    ? "Every current tracker and entry will be replaced by the document saved before the last import. The current document will take its place as the recoverable backup."
                    : "Every current tracker and entry will be removed and replaced by this file. The current document will remain recoverable here until the next import."),
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
        let unchanged = action == "import" || action == "restore" ? " Nothing was changed." : ""
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
