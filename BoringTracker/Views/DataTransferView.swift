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
                Button("Restore Data Before Last Replace…", systemImage: "arrow.uturn.backward") {
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
            Text("Merge combines records by ID. Deletions from either document stay deleted, newer edits win conflicts, and other distinct records are kept. Replace removes the current data and uses only the file.")
        }
        .alert(item: $presentedAlert, content: alert)
    }

    private func exportJSON() {
        do {
            exportDocument = ExportDocument(data: try store.exportData())
            exportType = .json
            exportName = "boring-tracker"
            isExporting = true
        } catch {
            show(error, action: "export")
        }
    }

    private func exportCSV() {
        exportDocument = ExportDocument(data: store.exportCSV())
        exportType = .commaSeparatedText
        exportName = "boring-tracker-entries"
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
        do {
            let summary = try store.importData(pendingImport, mode: mode)
            self.pendingImport = nil
            let removed = summary.entriesRemoved == 1 ? "1 entry" : "\(summary.entriesRemoved) entries"
            let backup = mode == .replace ? " A backup of the previous document was kept on this device." : ""
            presentedAlert = .message(
                title: "Import complete",
                detail: "Added \(summary.trackersAdded) trackers and \(summary.entriesAdded) entries. Removed \(removed).\(backup)"
            )
        } catch {
            show(error, action: "import")
        }
    }

    private func alert(_ alert: PresentedAlert) -> Alert {
        switch alert {
        case .confirmReplace:
            Alert(
                title: Text(isRestoringBackup ? "Restore previous data?" : "Replace all current data?"),
                message: Text(isRestoringBackup
                    ? "Every current tracker and entry will be replaced by the document saved before the last replace. The current document will take its place as the recoverable backup."
                    : "Every current tracker and entry will be removed and replaced by this file. The current document will remain recoverable here until the next replace."),
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

    private func show(_ error: any Error, action: String) {
        pendingImport = nil
        let detail: String
        if let storeError = error as? StoreError {
            detail = storeError.errorDescription ?? "The file uses a schema this version cannot read."
        } else if action == "import" {
            detail = "The selected file is not a valid Boring Tracker export or is damaged. Nothing was changed."
        } else {
            detail = (error as NSError).localizedDescription
        }
        presentedAlert = .message(title: "Couldn’t \(action)", detail: detail)
    }

    private func restoreBackup() {
        Task {
            do {
                let summary = try await store.restoreImportBackup()
                isRestoringBackup = false
                let removed = summary.entriesRemoved == 1
                    ? "1 entry" : "\(summary.entriesRemoved) entries"
                presentedAlert = .message(
                    title: "Restore complete",
                    detail: "Added \(summary.trackersAdded) trackers and \(summary.entriesAdded) entries. Removed \(removed). The document you replaced is now the recoverable backup."
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
