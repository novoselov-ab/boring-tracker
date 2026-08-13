import Foundation
import Testing
@testable import BoringTracker

@Suite("Persistence")
struct PersistenceTests {

    private func sampleDocument() -> StoreDocument {
        let calories = Tracker(name: "Calories", unit: "kcal", sortIndex: 0, section: "Food",
                               modified: time(1))
        let weight = Tracker(
            name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
            sortIndex: 1, section: "Weight", modified: time(1)
        )
        let breakfast = UUID()
        return StoreDocument(
            trackers: [calories, weight],
            entries: [
                Entry(trackerID: calories.id, value: 600, date: time(10), name: "breakfast",
                      batchID: breakfast, modified: time(10)),
                Entry(trackerID: calories.id, value: 250.5, date: time(400), modified: time(400)),
                Entry(trackerID: weight.id, value: 78.4, date: time(500), modified: time(500)),
            ],
            tombstones: [Tombstone(id: UUID(), deleted: time(20))]
        )
    }

    // MARK: - The format

    @Test("Everything survives a trip through the file, exactly")
    func roundTripIsLossless() throws {
        let original = sampleDocument()
        let decoded = try StoreCoding.decode(StoreCoding.encode(original))
        #expect(decoded == original)
    }

    @Test("Sub-second timestamps survive too, because merge compares them")
    func timestampsSurvive() throws {
        let stamped = Date.stamp()
        let entry = Entry(trackerID: UUID(), value: 1, date: stamped, modified: stamped)
        let decoded = try StoreCoding.decode(StoreCoding.encode(StoreDocument(entries: [entry])))

        #expect(decoded.entries.first?.date == stamped)
        #expect(decoded.entries.first?.modified == stamped)
    }

    @Test("The file is meant to be read and diffed: pretty, sorted, ISO dates")
    func fileIsHumanReadable() throws {
        let text = try String(decoding: StoreCoding.encode(sampleDocument()), as: UTF8.self)

        #expect(text.contains("\n  \"entries\" : ["))
        // Keys in alphabetical order.
        let keyOrder = ["\"entries\"", "\"schemaVersion\"", "\"tombstones\"", "\"trackers\""]
        let positions = keyOrder.compactMap { text.range(of: $0)?.lowerBound }
        #expect(positions == positions.sorted())
        #expect(text.contains("\"date\" : \"2026-01-01T00:10:00Z\""))
    }

    @Test("A canonicalised date is a fixed point of the file format",
          arguments: 0...200 as ClosedRange<Int>)
    func canonicalDatesAreStable(step: Int) throws {
        // The reason this test exists: with milliseconds in the format, it
        // failed. `…:38.328Z` parsed back to a hair under 38.328 and re-encoded
        // as `…:38.327Z`, so documents stopped equalling themselves after a
        // save. Anything that changes the date format has to keep this passing.
        let moment = Date(timeIntervalSinceReferenceDate: 808_109_558.328)
            .addingTimeInterval(Double(step) * 0.137)
            .canonicalized
        let entry = Entry(trackerID: UUID(), value: 1, date: moment, modified: moment)

        let once = try StoreCoding.decode(StoreCoding.encode(StoreDocument(entries: [entry])))
        let twice = try StoreCoding.decode(StoreCoding.encode(once))

        #expect(once.entries == [entry])
        #expect(twice == once)
    }

    // MARK: - Loading

    @Test("A first launch starts with something usable, not an empty screen")
    func freshInstall() {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }

        let loaded = file.load()

        #expect(loaded.origin == .fresh)
        #expect(loaded.document.trackers.map(\.name) == ["Calories", "Protein", "Weight"])
        #expect(loaded.document.trackers.map(\.section) == ["Food", "Food", "Weight"])
    }

    @Test("A normal launch reads the file it wrote")
    func writeThenLoad() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let document = sampleDocument()

        try file.write(document)
        let loaded = file.load()

        #expect(loaded.origin == .file)
        #expect(loaded.document == document)
    }

    @Test("A corrupt main file falls back to the backup instead of losing everything")
    func corruptFileFallsBackToBackup() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let good = sampleDocument()

        try file.write(good)                       // first write: no backup yet
        try file.write(good)                       // second write: backup is now `good`
        try Data("{ this is not json".utf8).write(to: file.url)

        let loaded = file.load()

        #expect(loaded.origin == .backup)
        #expect(loaded.document == good)
    }

    @Test("A truncated file counts as corrupt, not as an empty document")
    func truncatedFileIsRejected() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        try file.write(sampleDocument())
        try file.write(sampleDocument())

        let whole = try Data(contentsOf: file.url)
        try whole.prefix(whole.count / 2).write(to: file.url)

        #expect(file.load().origin == .backup)
    }

    @Test("When nothing decodes, the unreadable files are moved aside, never overwritten")
    func unreadableFilesAreQuarantined() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        try file.prepareDirectory()
        let garbage = Data("not a store".utf8)
        try garbage.write(to: file.url)
        try garbage.write(to: file.backupURL)

        let loaded = file.load()

        guard case let .unreadable(quarantine) = loaded.origin else {
            Issue.record("expected the load to report unreadable files, got \(loaded.origin)")
            return
        }
        #expect(try Data(contentsOf: quarantine.appendingPathComponent("store.json")) == garbage)
        #expect(try Data(contentsOf: quarantine.appendingPathComponent("store.backup.json")) == garbage)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
        #expect(loaded.document.trackers.map(\.name) == ["Calories", "Protein", "Weight"])
    }

    // MARK: - Writing safely

    @Test("Each write keeps the previous version alongside")
    func backupHoldsThePreviousVersion() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        var first = sampleDocument()
        try file.write(first)

        first.entries.append(Entry(trackerID: UUID(), value: 42, date: time(600), modified: time(600)))
        try file.write(first)

        let backup = try file.read(file.backupURL)
        #expect(backup.entries.count == first.entries.count - 1)
        #expect(try file.read(file.url) == first)
    }

    @Test("Repeated writes always leave a file that decodes")
    func writesAreNeverPartial() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        var document = sampleDocument()

        for index in 0..<40 {
            document.entries.append(
                Entry(trackerID: UUID(), value: Double(index), date: time(1_000 + index),
                      modified: time(1_000 + index))
            )
            try file.write(document)
            #expect(try file.read(file.url).entries.count == document.entries.count)
        }
    }

    @Test("The store stays inside device backups — getting this wrong loses histories silently")
    func storeIsNotExcludedFromBackup() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        try file.write(sampleDocument())

        for url in [file.directory, file.url] {
            let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
            #expect(values.isExcludedFromBackup != true, "\(url.lastPathComponent) is excluded")
        }
        #expect(file.url.path.contains("Application Support")
            || file.url.path.contains(NSTemporaryDirectory()))
    }

    @Test("The real store lives in Application Support, not in a directory iOS may erase")
    func standardLocationIsBackedUp() {
        let path = StoreFile.standard(appGroup: nil).url.path

        #expect(path.hasSuffix("Application Support/boring-tracker/store.json"))
        #expect(!path.contains("/Caches/"))
        #expect(!path.contains("/tmp/"))
    }

    // MARK: - Schema

    @Test("A file from a newer version of the app is refused rather than half-understood")
    func futureSchemaIsRefused() throws {
        var document = sampleDocument()
        document.schemaVersion = StoreDocument.currentSchemaVersion + 1
        let data = try StoreCoding.encoder().encode(document)

        #expect(throws: StoreError.self) { try StoreMigration.migrate(data) }
    }

    @Test("A future-schema file is kept, not replaced")
    func futureSchemaSurvivesOnDisk() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        try file.prepareDirectory()
        var document = sampleDocument()
        document.schemaVersion = 99
        let data = try StoreCoding.encoder().encode(document)
        try data.write(to: file.url)

        let loaded = file.load()

        guard case let .unreadable(quarantine) = loaded.origin else {
            Issue.record("expected quarantine, got \(loaded.origin)")
            return
        }
        #expect(try Data(contentsOf: quarantine.appendingPathComponent("store.json")) == data)
    }

    @Test("Loading normalises the version and the entry order")
    func migrationNormalises() throws {
        var document = sampleDocument()
        document.entries.reverse()
        let data = try StoreCoding.encoder().encode(document)

        let migrated = try StoreMigration.migrate(data)

        #expect(migrated.schemaVersion == StoreDocument.currentSchemaVersion)
        #expect(migrated.entries == StoreDocument.sorted(document.entries))
    }
}
