import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// An export offered to the share sheet.
///
/// It carries the document rather than the bytes: a `ShareLink`'s item is built
/// every time the settings list draws a body, and encoding the whole document
/// there would run on a drag. `StoreDocument` is a struct of arrays, so holding
/// one is a retain; the encode happens in the representation below, once a
/// destination has been chosen.
struct ExportFile: Transferable {

    enum Format {
        case json
        case csv

        var fileExtension: String {
            switch self {
            case .json: "json"
            case .csv: "csv"
            }
        }
    }

    /// The undated stem — `boring-tracker`. The date is added in `filename`
    /// below rather than stored here, because this value is built when the
    /// settings list draws and read when a destination is chosen, and those are
    /// not the same day if the list has been on screen since before midnight.
    /// An export should be named for the day it was taken, and the tap is when
    /// it is taken. (This used to argue it from the *Save to Files* door dating
    /// its name at the tap; `35a5fd0` deleted that door, and the reason stands
    /// without it.)
    let stem: String
    let format: Format
    let document: StoreDocument

    var filename: String { "\(ExportName.dated(stem)).\(format.fileExtension)" }

    /// `FileRepresentation`, so what is shared is a *file* — AirDrop, Mail and
    /// Messages attach it, and Files saves it under `filename`. A
    /// `DataRepresentation` would hand over bytes with no name attached.
    ///
    /// One representation, typed `.data`, rather than one per format: the
    /// representation is static, so it cannot ask an instance which type it is,
    /// and declaring both would let a receiver asking for JSON take the first
    /// one and be handed a CSV. `.data` is the honest common ancestor, and the
    /// extension on the file says the rest — which is what sharing a file URL
    /// has always done.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { file in
            SentTransferredFile(try file.written())
        }
    }

    /// Writes the bytes into a temporary directory of this file's own, so the
    /// name the receiver sees is `filename` and nothing else is exposed.
    ///
    /// Old shares are pruned first, so this directory holds today's files
    /// rather than one complete copy of the document per format per day for as
    /// long as the app is installed. `tmp` is emptied by iOS only when storage
    /// runs short, which is not a schedule, and these are whole documents.
    ///
    /// **Anything thrown from here is reported by the share sheet, not by the
    /// app.** `ShareLink` has no error hook, so a full disk shows whatever iOS
    /// shows and this code says nothing — worth knowing before treating a
    /// silent share as it doing nothing at all. The comment used to contrast
    /// this with "the Files route", which put the same failure through
    /// `show(_:action:)` and named it; `35a5fd0` deleted that route, and the
    /// surviving `show(_:action:)` calls are open, import, delete and restore.
    /// So there is no longer a door out of this app that reports an export
    /// failure in the app's own words.
    func written() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "share", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        prune(directory)
        let url = directory.appending(path: filename)
        try data().write(to: url, options: .atomic)
        return url
    }

    /// Removes shares written more than an hour ago, and nothing newer.
    ///
    /// `SentTransferredFile` copies what it is handed unless told otherwise, so
    /// deleting a file after the sheet has taken it is safe — but a transfer
    /// started a minute ago is not worth the argument, and an hour costs one
    /// stale file. Failures are ignored: a share that cannot tidy up should
    /// still be a share.
    private func prune(_ directory: URL) {
        let cutoff = Date.now.addingTimeInterval(-3600)
        let existing = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        for file in existing {
            let modified = try? file.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate
            if let modified, modified < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func data() throws -> Data {
        switch format {
        case .json: try StoreCoding.encode(document)
        case .csv: CSVExport.data(document: document)
        }
    }
}
