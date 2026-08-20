import Foundation
import Darwin

enum StoreError: Error, Equatable {
    case futureSchema(found: Int, supported: Int)
    case olderSchema(found: Int, supported: Int)
    case invalidDocument(String)
}

extension StoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .futureSchema(let found, let supported):
            "This export uses schema version \(found). This app supports version \(supported); update the app before importing it. Nothing was changed."
        case .olderSchema(let found, let supported):
            "This export uses schema version \(found), but this app supports version \(supported) and has no safe migration for it. Nothing was changed."
        case .invalidDocument(let reason):
            "This export is internally inconsistent: \(reason) Nothing was changed."
        }
    }
}

enum StoreOrigin: Equatable, Sendable {
    case file
    /// The main file would not decode; the previous good copy did.
    case backup
    case fresh
    /// Neither file could be read. Both were moved aside to this URL rather than
    /// overwritten, and the app started over. The user gets told.
    case unreadable(quarantine: URL)
}

struct StoreLoad: Sendable {
    var document: StoreDocument
    var origin: StoreOrigin
}

struct StoreFile: Sendable {

    let url: URL
    let backupURL: URL
    let importBackupURL: URL
    let importBackupStagingURL: URL

    init(directory: URL) {
        self.url = directory.appendingPathComponent("store.json")
        self.backupURL = directory.appendingPathComponent("store.backup.json")
        self.importBackupURL = directory.appendingPathComponent("store.before-import.json")
        self.importBackupStagingURL = directory
            .appendingPathComponent("store.before-import.staging.json")
    }

    var directory: URL { url.deletingLastPathComponent() }

    /// The real location: `Application Support/boring-tracker/`, inside the App
    /// Group container when the entitlement is present so a widget can read the
    /// same file later. Signing an App Group needs a paid developer account and
    /// this project deliberately builds without one, so the plain container is the
    /// fallback.
    static func standard(appGroup: String? = Self.appGroupIdentifier) -> StoreFile {
        let fileManager = FileManager.default
        let base = appGroup
            .flatMap { fileManager.containerURL(forSecurityApplicationGroupIdentifier: $0) }
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return StoreFile(directory: base.appendingPathComponent("boring-tracker", isDirectory: true))
    }

    /// Matches the permanent bundle id in docs/SHIPPING.md, and like it cannot
    /// change after shipping without stranding everyone's data.
    static let appGroupIdentifier = "group.com.novoselov.boringtracker"

    // MARK: - Reading

    func load(now: Date = Date()) -> StoreLoad {
        let fileManager = FileManager.default
        let mainExists = fileManager.fileExists(atPath: url.path)
        let backupExists = fileManager.fileExists(atPath: backupURL.path)

        if mainExists, let document = try? read(url) {
            return StoreLoad(document: document, origin: .file)
        }
        if backupExists, let document = try? read(backupURL) {
            return StoreLoad(document: document, origin: .backup)
        }
        guard mainExists || backupExists else {
            return StoreLoad(document: .starter, origin: .fresh)
        }
        // Something is there and none of it decodes. Move it aside instead of
        // letting the next save write over the only copy the user has left.
        let quarantine = quarantineAll(now: now)
        return StoreLoad(document: .starter, origin: .unreadable(quarantine: quarantine))
    }

    func read(_ fileURL: URL) throws -> StoreDocument {
        try StoreMigration.migrate(Data(contentsOf: fileURL))
    }

    private func quarantineAll(now: Date) -> URL {
        let fileManager = FileManager.default
        let label = now.formatted(
            Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted)
        )
        let folder = directory.appendingPathComponent("unreadable-\(label)", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        for source in [url, backupURL] where fileManager.fileExists(atPath: source.path) {
            try? fileManager.moveItem(at: source, to: folder.appendingPathComponent(source.lastPathComponent))
        }
        return folder
    }

    // MARK: - Writing

    func write(_ document: StoreDocument) throws {
        let data = try StoreCoding.encode(document)
        try prepareDirectory()

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: backupURL)
            // On APFS this is a clone, not a byte copy, so keeping a spare
            // costs essentially nothing per save.
            try? fileManager.copyItem(at: url, to: backupURL)
        }
        // Writes a temp file and renames it, so a reader — or a crash — sees
        // either the whole old document or the whole new one.
        try data.write(to: url, options: .atomic)
    }

    /// Throws away the rolling save backup. **Only a clear does this.**
    ///
    /// `write` copies the old `store.json` aside before every save, and `load`
    /// falls back to that file, so without this the entire pre-clear history
    /// survives a clear in `store.backup.json` — an undisclosed second copy of the
    /// data somebody just asked to be rid of. Safe here specifically: what it
    /// protects against is a torn `store.json`, and the file this runs after is a
    /// freshly written, complete, empty document.
    func discardSaveBackup() {
        try? FileManager.default.removeItem(at: backupURL)
    }

    /// Keeps the exact in-memory document an import is about to change. Separate
    /// from the rolling save backup: recent edits may not have reached that file.
    func writeImportBackup(_ document: StoreDocument) throws {
        try prepareDirectory()
        try StoreCoding.encode(document).write(to: importBackupURL, options: .atomic)
    }

    /// Writes the pre-import copy *beside* the recovery slot without disturbing
    /// what is in it.
    ///
    /// The slot holds one document, so overwriting it is itself destructive:
    /// writing straight into it and only then writing the import meant a failure
    /// on that second write — a full disk — left the user with neither.
    func stageImportBackup(_ document: StoreDocument) throws {
        try prepareDirectory()
        try StoreCoding.encode(document).write(to: importBackupStagingURL, options: .atomic)
    }

    /// Advances the recovery slot to the staged copy, reporting whether it managed
    /// to. `rename(2)` replaces in one step, so there is never a moment with no
    /// slot at all. Deliberately does not throw: the import is already on disk by
    /// now, so a failure here means the safety net did not advance, which the
    /// summary says out loud rather than failing a completed import.
    @discardableResult
    func commitStagedImportBackup() -> Bool {
        guard FileManager.default.fileExists(atPath: importBackupStagingURL.path) else {
            return false
        }
        guard rename(importBackupStagingURL.path, importBackupURL.path) == 0 else {
            discardStagedImportBackup()
            return false
        }
        return true
    }

    func discardStagedImportBackup() {
        try? FileManager.default.removeItem(at: importBackupStagingURL)
    }

    var hasImportBackup: Bool {
        FileManager.default.fileExists(atPath: importBackupURL.path)
    }

    func importBackupData() throws -> Data {
        try Data(contentsOf: importBackupURL)
    }

    /// Exchanges the live document and the pre-import recovery document in one
    /// filesystem operation. Deliberately not two moves: a crash must leave either
    /// the old pair or the new pair, never two copies of the document the user was
    /// trying to get away from.
    func swapWithImportBackup() throws {
        let result = renameatx_np(
            AT_FDCWD, url.path,
            AT_FDCWD, importBackupURL.path,
            UInt32(RENAME_SWAP)
        )
        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    func prepareDirectory() throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        // Stated explicitly because the opposite is a one-line mistake that
        // silently destroys people's history when they get a new phone: the
        // store must stay inside iCloud/iTunes backup. See docs/TECH.md.
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var mutable = directory
        try? mutable.setResourceValues(values)
    }
}
