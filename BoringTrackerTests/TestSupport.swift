import Foundation
@testable import BoringTracker

// Shared fixtures. Everything here is deterministic on purpose: a merge test
// that depends on the wall clock or on dictionary ordering is a test that will
// eventually fail for a reason nobody can reproduce.

func calendar(_ zone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

func date(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
    in calendar: Calendar = calendar("UTC")
) -> Date {
    let parts = DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute, second: second
    )
    return calendar.date(from: parts)!.canonicalized
}

/// A date offset from a fixed epoch, for when the exact value doesn't matter
/// but the ordering does.
func time(_ minutes: Int) -> Date {
    date(2026, 1, 1).addingTimeInterval(Double(minutes) * 60)
}

/// xorshift64. Seeded so a failing property test reproduces exactly.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        if state == 0 { state = 0x2545_F491_4F6C_DD1D }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

extension StoreDocument {
    /// A small fixed pool of batch ids, in its own namespace rather than drawn
    /// from the record ids. Shared by every generated document and deliberately
    /// short, so several entries land in the same batch and two documents can
    /// genuinely agree about one.
    private static let batchIDs: [UUID] = (0..<4).map {
        UUID(uuidString: "00000000-0000-4000-8000-00000000000\($0)")!
    }

    /// Builds a document out of a shared pool of ids, so two generated
    /// documents genuinely conflict rather than merging as disjoint sets.
    static func random(
        seed: UInt64,
        trackerIDs: [UUID],
        entryIDs: [UUID]
    ) -> StoreDocument {
        var random = SeededRandom(seed: seed)
        var document = StoreDocument()

        for (index, id) in trackerIDs.enumerated() where Bool.random(using: &random) {
            document.trackers.append(
                Tracker(
                    id: id,
                    name: "T\(Int.random(in: 0...9, using: &random))",
                    unit: ["kcal", "g", ""].randomElement(using: &random)!,
                    kind: Bool.random(using: &random) ? .dailyTotal : .measurement,
                    // Not the position in the shared pool: that gave every
                    // document the same index for the same id, so two of them
                    // could never disagree about where a tracker sits and the
                    // whole position-merge path went untested.
                    sortIndex: Int.random(in: 0...5, using: &random),
                    section: ["Food", "Weight", ""].randomElement(using: &random)!,
                    modified: time(Int.random(in: 0...20, using: &random)),
                    // Drawn independently of `modified`, because the whole
                    // point of the second stamp is that the two move apart:
                    // a document can hold a tracker renamed late and moved
                    // early, or the reverse, and the merge has to take one
                    // field from each side.
                    orderModified: time(Int.random(in: 0...20, using: &random))
                )
            )
        }

        for id in entryIDs where Bool.random(using: &random) {
            document.entries.append(
                Entry(
                    id: id,
                    trackerID: trackerIDs.randomElement(using: &random)!,
                    value: Double(Int.random(in: -50...500, using: &random)),
                    date: time(Int.random(in: 0...5_000, using: &random)),
                    name: Bool.random(using: &random) ? "n\(Int.random(in: 0...5, using: &random))" : nil,
                    // Its own small pool, not the record ids: a batch id shares
                    // no namespace with entries or tombstones, and drawing from
                    // a handful means several entries land in one batch. The
                    // point is that the field is carried through the round trip
                    // and the merge tie-break instead of being nil everywhere.
                    batchID: Bool.random(using: &random) ? batchIDs.randomElement(using: &random) : nil,
                    modified: time(Int.random(in: 0...20, using: &random))
                )
            )
        }

        for id in (trackerIDs + entryIDs) where Int.random(in: 0...4, using: &random) == 0 {
            document.tombstones.append(
                Tombstone(id: id, deleted: time(Int.random(in: 0...20, using: &random)))
            )
        }
        return document
    }
}

/// A store file in a fresh temporary directory, cleaned up by the caller.
func temporaryStoreFile() -> StoreFile {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("whatever-tests-\(UUID().uuidString)", isDirectory: true)
    return StoreFile(directory: directory)
}

extension StoreFile {
    func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }
}
