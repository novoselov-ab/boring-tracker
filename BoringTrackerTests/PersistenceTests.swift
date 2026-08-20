import Foundation
import Testing
@testable import BoringTracker

@Suite("Persistence")
struct PersistenceTests {

    private func sampleDocument() -> StoreDocument {
        let calories = Tracker(name: "Calories", unit: "kcal", sortIndex: 0, group: "Food",
                               modified: time(1))
        let weight = Tracker(
            name: "Weight", unit: "kg", kind: .measurement, decimals: 1,
            sortIndex: 1, group: "Weight", modified: time(1)
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
        #expect(loaded.document.trackers.map(\.group) == ["Food", "Food", "Weight"])
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

    /// A real version 1 document, written out the way version 1 wrote them:
    /// `note` on an entry, no `group` or `orderModified` on a tracker, and a
    /// `pins` array holding a type that no longer exists. Kept as literal text
    /// rather than built from today's model, because today's model cannot
    /// express it — that is the whole reason a step is needed.
    private static let versionOneFile = """
    {
      "entries" : [
        {
          "date" : "2026-01-01T06:40:00Z",
          "id" : "44444444-4444-4444-8444-444444444444",
          "modified" : "2026-01-01T06:40:00Z",
          "trackerID" : "11111111-1111-4111-8111-111111111111",
          "value" : 250.5
        },
        {
          "date" : "2026-01-01T00:10:00Z",
          "id" : "33333333-3333-4333-8333-333333333333",
          "modified" : "2026-01-01T00:10:00Z",
          "note" : "porridge",
          "trackerID" : "11111111-1111-4111-8111-111111111111",
          "value" : 600
        }
      ],
      "pins" : [
        {
          "amounts" : [
            {
              "trackerID" : "11111111-1111-4111-8111-111111111111",
              "value" : 450
            }
          ],
          "id" : "66666666-6666-4666-8666-666666666666",
          "label" : "usual breakfast",
          "modified" : "2026-01-01T00:01:00Z",
          "sortIndex" : 0
        }
      ],
      "schemaVersion" : 1,
      "tombstones" : [
        {
          "deleted" : "2026-01-01T00:20:00Z",
          "id" : "55555555-5555-4555-8555-555555555555"
        }
      ],
      "trackers" : [
        {
          "decimals" : 0,
          "id" : "11111111-1111-4111-8111-111111111111",
          "isArchived" : false,
          "kind" : "dailyTotal",
          "modified" : "2026-01-01T00:01:00Z",
          "name" : "Calories",
          "sortIndex" : 0,
          "unit" : "kcal"
        },
        {
          "decimals" : 1,
          "id" : "22222222-2222-4222-8222-222222222222",
          "isArchived" : false,
          "kind" : "measurement",
          "modified" : "2026-01-01T00:01:00Z",
          "name" : "Weight",
          "sortIndex" : 1,
          "unit" : "kg"
        }
      ]
    }
    """

    @Test("A file from a newer version of the app is refused rather than half-understood")
    func futureSchemaIsRefused() throws {
        var document = sampleDocument()
        document.schemaVersion = StoreDocument.currentSchemaVersion + 1
        let data = try StoreCoding.encoder().encode(document)

        #expect(throws: StoreError.futureSchema(
            found: document.schemaVersion, supported: StoreDocument.currentSchemaVersion
        )) {
            try StoreMigration.migrate(data)
        }
    }

    @Test("A version with no step is refused, however readable the rest of it looks")
    func unreachableOlderSchemaIsRefused() throws {
        // Deliberately a document that is otherwise perfectly readable: the
        // version alone has to be enough to stop it. A step exists for version
        // 1 and for nothing below it, and letting an unknown version through
        // would drop every field it holds under a name this build has never
        // seen, then save that loss back over the original.
        var document = sampleDocument()
        document.schemaVersion = 0
        let data = try StoreCoding.encoder().encode(document)

        #expect(throws: StoreError.olderSchema(
            found: 0, supported: StoreDocument.currentSchemaVersion
        )) {
            try StoreMigration.migrate(data)
        }
    }

    @Test("A file no step can read is kept, not converted in place")
    func unreachableOlderSchemaSurvivesOnDisk() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        try file.prepareDirectory()
        var document = sampleDocument()
        document.schemaVersion = 0
        let data = try StoreCoding.encoder().encode(document)
        try data.write(to: file.url)

        let loaded = file.load()

        guard case let .unreadable(quarantine) = loaded.origin else {
            Issue.record("expected quarantine, got \(loaded.origin)")
            return
        }
        #expect(try Data(contentsOf: quarantine.appendingPathComponent("store.json")) == data)
        #expect(loaded.document.trackers.map(\.name) == ["Calories", "Protein", "Weight"])
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

    // MARK: - Version 1 to version 2

    @Test("A version 1 document arrives as a version 2 one, carrying everything it held")
    func versionOneBecomesVersionTwo() throws {
        let migrated = try StoreMigration.migrate(Data(Self.versionOneFile.utf8))

        #expect(migrated.schemaVersion == 2)
        #expect(migrated.schemaVersion == StoreDocument.currentSchemaVersion)

        let calories = try #require(migrated.trackers.first { $0.name == "Calories" })
        let weight = try #require(migrated.trackers.first { $0.name == "Weight" })
        #expect(calories.unit == "kcal")
        #expect(weight.kind == .measurement)
        #expect(weight.decimals == 1)
        // Nothing in version 1 was grouped, and empty is what that means.
        #expect(migrated.trackers.allSatisfy { $0.group.isEmpty })
        // The record's own last change, not the moment it was migrated: a
        // position stamped today would win every ordering conflict with another
        // device the first time the two documents met.
        #expect(calories.orderModified == time(1))
        #expect(calories.orderModified == calories.modified)

        // `note` became `name`, which is the field the history, search and
        // Repeat all read. Dropping it would empty every one of those screens.
        #expect(migrated.entries.map(\.name) == ["porridge", nil])
        #expect(migrated.entries.map(\.value) == [600, 250.5])
        #expect(migrated.entries.allSatisfy { $0.batchID == nil })
        // Sorted on the way in, like any other load: the file has them the
        // other way round.
        #expect(migrated.entries.map(\.date) == [time(10), time(400)])

        #expect(migrated.tombstones.map(\.deleted) == [time(20)])
    }

    @Test("The pins a version 1 file carried are gone, and gone deliberately")
    func versionOnePinsAreDropped() throws {
        let migrated = try StoreMigration.migrate(Data(Self.versionOneFile.utf8))
        let text = String(decoding: try StoreCoding.encode(migrated), as: UTF8.self)

        // The type was deleted before anything shipped, and turning a saved
        // shortcut into entries would write rows into a history at times when
        // nothing was logged. Asserted on the re-encoded document because
        // `StoreDocument` has no way left to express the loss.
        #expect(!text.contains("pins"))
        #expect(!text.contains("usual breakfast"))
        #expect(migrated.entries.count == 2)
    }

    @Test("A version 1 file opens from disk, migrated, rather than being quarantined")
    func versionOneLoadsFromDisk() throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        try file.prepareDirectory()
        try Data(Self.versionOneFile.utf8).write(to: file.url)

        let loaded = file.load()

        #expect(loaded.origin == .file)
        #expect(loaded.document.trackers.map(\.name) == ["Calories", "Weight"])
        #expect(loaded.document.entries.map(\.name) == ["porridge", nil])
    }

    @Test("A version 1 file whose records are unreadable is refused, not quietly emptied")
    func versionOneWithBrokenRecordsIsRefused() {
        // The step rewrites `trackers` only where it holds what it should. The
        // shorter `as? [[String: Any]] ?? []` would turn this into a document
        // with no trackers at all, which decodes perfectly and then gets saved
        // back over a file that still had them.
        let text = """
        {"entries":[],"schemaVersion":1,"tombstones":[],"trackers":"gone"}
        """

        #expect(throws: (any Error).self) {
            try StoreMigration.migrate(Data(text.utf8))
        }
    }

    // MARK: - Chaining

    /// Steps of the test's own making, because there is one real step today and
    /// no way to build a two-step chain out of it. What is under test is the
    /// loop rather than any step: the order, the version stamped between them,
    /// and what a gap does.
    private func trailStep(_ mark: String) -> StoreMigration.Step {
        { document in
            var document = document
            document["trail"] = (document["trail"] as? String ?? "") + mark
            document["seen\(mark)"] = document["schemaVersion"]
            return document
        }
    }

    @Test("A chain runs every step in order, stamping the version between them")
    func chainRunsStepsInOrder() throws {
        let steps: [Int: StoreMigration.Step] = [4: trailStep("a"), 5: trailStep("b")]

        let result = try StoreMigration.chain(
            ["schemaVersion": 4], from: 4, to: 6, steps: steps
        )

        #expect(result["trail"] as? String == "ab")
        // The second step saw the version the first one's stamp left behind,
        // so a step can trust `schemaVersion` to say what it is reading.
        #expect(result["seena"] as? Int == 4)
        #expect(result["seenb"] as? Int == 5)
        #expect(result["schemaVersion"] as? Int == 6)
    }

    @Test("A gap in the chain refuses the whole document rather than stopping halfway")
    func chainRefusesAGap() {
        // A step for 4, nothing for 5. Half a migration is a shape no version
        // of the app has ever described, and the version reported is the file's
        // own, not the one the chain got stuck on — that is what the user can
        // check.
        let steps: [Int: StoreMigration.Step] = [4: trailStep("a")]

        #expect(throws: StoreError.olderSchema(found: 4, supported: 6)) {
            try StoreMigration.chain(["schemaVersion": 4], from: 4, to: 6, steps: steps)
        }
    }

    @Test("A document already at the target passes through untouched")
    func chainAtTargetDoesNothing() throws {
        let result = try StoreMigration.chain(
            ["schemaVersion": 6, "trail": "x"], from: 6, to: 6, steps: [:]
        )

        #expect(result["trail"] as? String == "x")
        #expect(result["schemaVersion"] as? Int == 6)
    }

    @Test("The real chain has a step for every version below the current one")
    func everyOlderVersionHasAStep() {
        // The rule this project actually holds itself to: a released version's
        // shape stays readable. If this fails, either a step is missing or the
        // bump that needed it was made without one.
        for version in 1..<StoreDocument.currentSchemaVersion {
            #expect(StoreMigration.steps[version] != nil, "no step from version \(version)")
        }
    }
}
