import Foundation
import Darwin

enum StoreError: Error, Equatable {
    /// The file was written by a newer version of the app. Refusing beats
    /// guessing: decoding it with today's rules would drop whatever is new and
    /// then save that loss back over the original.
    case futureSchema(found: Int, supported: Int)
    /// The file was written by an older version, and this build has no step
    /// that reads it. Refused for the same reason and with the same danger:
    /// today's decoder would silently ignore every field that has since been
    /// renamed or removed, and the next save would write that loss back.
    case olderSchema(found: Int, supported: Int)
    /// Structurally decodable, but not a document the merge rules can handle
    /// consistently (for example, the same id both live and deleted).
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

/// Where the document came from, so the app can be honest about it.
enum StoreOrigin: Equatable, Sendable {
    /// Normal launch.
    case file
    /// The main file would not decode; the previous good copy did.
    case backup
    /// Nothing on disk yet — a first launch.
    case fresh
    /// Neither file could be read. Both were moved aside to this URL rather
    /// than overwritten, and the app started over. The user gets told.
    case unreadable(quarantine: URL)
}

struct StoreLoad: Sendable {
    var document: StoreDocument
    var origin: StoreOrigin
}

/// Reading and writing the one file the app owns.
///
/// Every write is the entire document, written atomically, with the previous
/// version kept alongside. See "Writing safely" in docs/TECH.md.
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

    /// The real location: `Application Support/boring-tracker/`.
    ///
    /// Inside the App Group container when the entitlement is present, so a
    /// widget can read the same file later without the store moving after
    /// people already have history in it. Signing an App Group needs a paid
    /// developer account, and the project deliberately builds without one, so
    /// the plain container is the fallback.
    static func standard(appGroup: String? = Self.appGroupIdentifier) -> StoreFile {
        let fileManager = FileManager.default
        let base = appGroup
            .flatMap { fileManager.containerURL(forSecurityApplicationGroupIdentifier: $0) }
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return StoreFile(directory: base.appendingPathComponent("boring-tracker", isDirectory: true))
    }

    /// Matches the permanent bundle id from docs/SHIPPING.md. Like the bundle
    /// id, this cannot change after shipping without stranding the data of
    /// everyone who already has the app.
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
        // Writes a temporary file and renames it, so a reader — or a crash —
        // sees either the whole old document or the whole new one.
        try data.write(to: url, options: .atomic)
    }

    /// Throws away the rolling save backup.
    ///
    /// **Only a clear does this**, and it is the difference between "removes
    /// every tracker and entry from this device" being true and being nearly
    /// true. `write` copies the old `store.json` aside before every save, so
    /// the write that lands the empty document leaves the entire pre-clear
    /// history in `store.backup.json` — and `load` falls back to that file
    /// whenever the main one fails to decode. Nothing rewrites it until the
    /// next save, which for somebody who cleared the app and put the phone down
    /// is never.
    ///
    /// The one copy a clear leaves is the recovery slot, which the confirmation
    /// names out loud. An undisclosed second copy of a history somebody has
    /// just asked to be rid of is not a safety net; it is the opposite of the
    /// thing they asked for.
    ///
    /// Safe to lose here specifically: what it protects against is a torn or
    /// unreadable `store.json`, and the file this runs after is a freshly
    /// written, complete, empty document. The next ordinary save recreates it.
    func discardSaveBackup() {
        try? FileManager.default.removeItem(at: backupURL)
    }

    /// Keeps the exact in-memory document that an import is about to change.
    /// This is separate from the rolling save backup: recent edits may not have
    /// reached that file yet when the user imports.
    func writeImportBackup(_ document: StoreDocument) throws {
        try prepareDirectory()
        try StoreCoding.encode(document).write(to: importBackupURL, options: .atomic)
    }

    /// Writes the pre-import copy *beside* the recovery slot without disturbing
    /// what is in it.
    ///
    /// The slot holds one document, so overwriting it is itself destructive.
    /// Writing straight into it and only then writing the imported document
    /// meant a failure on that second write — a full disk is the realistic one —
    /// left the user with neither: the document they had before the import they
    /// regretted was already gone, replaced by the one they were importing over.
    /// Staged here, committed once the imported document is safely down.
    func stageImportBackup(_ document: StoreDocument) throws {
        try prepareDirectory()
        try StoreCoding.encode(document).write(to: importBackupStagingURL, options: .atomic)
    }

    /// Advances the recovery slot to the staged copy, reporting whether it
    /// managed to. `rename(2)` replaces in one step, so there is never a moment
    /// with no slot at all.
    ///
    /// Deliberately does not throw: by the time this runs the import is already
    /// on disk and has succeeded. A failure here means the safety net did not
    /// advance, which the summary then says out loud rather than turning a
    /// completed import into an error.
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

    /// Exchanges the live document and the pre-import recovery document in
    /// one filesystem operation. There is deliberately no sequence of two
    /// moves here: a crash must leave either the old pair or the new pair,
    /// never two copies of the document the user was trying to get away from.
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

/// The version probe, and the refusal of a file this build does not understand.
///
/// There is no migration step, and that is a statement about the app rather
/// than an omission: nothing has been released, so no version 1 document exists
/// anywhere to be migrated. Writing a step now would mean maintaining and
/// testing a path from a file that has never been on anyone's phone.
///
/// What does have to work from the first release is the refusal itself: meeting
/// a document this build cannot read and declining to guess. Decoding one with
/// today's rules would drop whatever it holds under a key that has since been
/// renamed or removed, and then save that loss back over the original. So the
/// probe accepts exactly the current version and nothing else — a *newer* file
/// because it is from a build that knows more, an *older* one because there is
/// no step that reads it. Both are moved aside intact rather than overwritten.
/// The first shipped version is the first one whose shape anyone can be
/// holding, and a step from N to N+1 goes here when that day comes.
enum StoreMigration {

    private struct VersionProbe: Decodable { var schemaVersion: Int }

    static func migrate(_ data: Data) throws -> StoreDocument {
        let supported = StoreDocument.currentSchemaVersion
        let probe = try StoreCoding.decoder().decode(VersionProbe.self, from: data)
        // Equality, not `<=`. With no migration step, every version but this one
        // is a version this build cannot read, and both directions fail the same
        // way if allowed through: the decoder ignores keys it doesn't know, so a
        // document quietly loses whatever it carried under a name that has since
        // changed. Today a v1 file happens to fail anyway — `group` is
        // non-optional, and a synthesized decoder does not fall back to a
        // property's default — but that is an accident of this bump's fields,
        // not a guarantee. A bump that only added optional fields would decode
        // and lose data. When a step from N to N+1 is written, it goes here and
        // takes the older versions it can actually handle.
        guard probe.schemaVersion == supported else {
            throw probe.schemaVersion > supported
                ? StoreError.futureSchema(found: probe.schemaVersion, supported: supported)
                : StoreError.olderSchema(found: probe.schemaVersion, supported: supported)
        }
        var document = try StoreCoding.decode(data)
        document.schemaVersion = StoreDocument.currentSchemaVersion
        document.entries = StoreDocument.sorted(document.entries)
        return document
    }
}
