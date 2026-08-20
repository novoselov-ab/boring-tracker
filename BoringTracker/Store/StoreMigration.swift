import Foundation

/// The version probe, the steps that carry an older file forward, and the refusal
/// of everything they cannot reach. See "Migrating an older file" in docs/TECH.md.
///
/// **The refusal is the load-bearing part.** A version with no step is one this
/// build cannot read, and it is refused rather than decoded with today's rules:
/// decoding an unfamiliar document silently drops whatever it holds under a key
/// since renamed or removed, and the next save writes that loss back over the
/// only copy the user has. `load` moves such a file aside intact instead.
enum StoreMigration {

    /// One version's worth of change, applied to the JSON rather than to a Swift
    /// type.
    ///
    /// It has to be the JSON. `StoreDocument`, `Tracker` and `Entry` only describe
    /// the *current* shape, so a step written against them could not see the field
    /// it exists to rename — by the time one has decoded, the old field is gone.
    ///
    /// Deliberately not throwing: anything a step cannot make sense of is caught
    /// moments later by the decoder, which refuses the document and leaves the
    /// file quarantined intact.
    ///
    /// **What a step must not do is put in a value JSON cannot hold** — a `Date`,
    /// a `UUID`, a `URL`. `JSONSerialization` answers those with an Objective-C
    /// exception, which cannot be caught and takes the process down; on the launch
    /// path that is a crash loop with no screen to escape from, where every other
    /// bad document is merely quarantined. `chain` checks for it and refuses the
    /// document instead. One case the check cannot catch: a Swift `Optional`
    /// holding `nil`, boxed into `Any`, bridges to `NSNull` and is valid JSON, so
    /// `["group": maybeString as Any]` writes `"group": null` and the file is
    /// quarantined at the next launch instead of migrated.
    typealias Step = @Sendable ([String: Any]) -> [String: Any]

    /// Keyed by the version each step *reads*: `steps[1]` takes a version 1
    /// document to version 2.
    static let steps: [Int: Step] = [1: v1ToV2]

    private struct VersionProbe: Decodable { var schemaVersion: Int }

    /// Reads a file this build is willing to be responsible for, or refuses it.
    static func migrate(_ data: Data) throws -> StoreDocument {
        let supported = StoreDocument.currentSchemaVersion
        let found = try StoreCoding.decoder().decode(VersionProbe.self, from: data).schemaVersion

        // Probed before the document is parsed as JSON so that a current file —
        // the case every launch takes — never pays for the second parse.
        if found == supported { return try decodeCurrent(data) }

        // A newer file is refused and never migrated: it comes from a build that
        // knows more, and there is no step that runs backwards.
        guard found < supported else {
            throw StoreError.futureSchema(found: found, supported: supported)
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Not reachable through the probe above, which needs an object to
            // decode at all. Written down rather than forced, because this is the
            // path that ends with a file being replaced.
            throw StoreError.invalidDocument("the file is not a JSON object.")
        }
        let migrated = try chain(object, from: found, to: supported, steps: steps)
        return try decodeCurrent(JSONSerialization.data(withJSONObject: migrated))
    }

    /// Applies one step per version, in order, from `found` up to `target`.
    ///
    /// Separate from `migrate` so the chaining can be tested with steps of a test's
    /// own making: there is no way to build a two-step chain out of the one real
    /// step, and the ordering, version bookkeeping and missing-step refusal will be
    /// wrong long before any individual step is.
    ///
    /// A gap refuses the whole document rather than stopping partway. Half a
    /// migration is a shape no version of the app has ever described.
    static func chain(
        _ document: [String: Any], from found: Int, to target: Int, steps: [Int: Step]
    ) throws -> [String: Any] {
        var document = document
        var version = found
        while version < target {
            guard let step = steps[version] else {
                throw StoreError.olderSchema(found: found, supported: target)
            }
            document = step(document)
            // See `Step`: a value JSON cannot hold would kill the process inside
            // `JSONSerialization` rather than throw. Checked per step so the
            // refusal names the step, and so a chain cannot be half-applied.
            guard JSONSerialization.isValidJSONObject(document) else {
                throw StoreError.invalidDocument(
                    "the migration step from version \(version) produced a value that is not JSON."
                )
            }
            version += 1
            // The loop stamps the version, not the step, so no step can forget to
            // and the next one can trust what `schemaVersion` says it was handed.
            document["schemaVersion"] = version
        }
        return document
    }

    private static func decodeCurrent(_ data: Data) throws -> StoreDocument {
        var document = try StoreCoding.decode(data)
        document.schemaVersion = StoreDocument.currentSchemaVersion
        document.entries = StoreDocument.sorted(document.entries)
        return document
    }

    // MARK: - The steps

    /// Version 1 to version 2, the bump made in `d6520b2`: `group` and
    /// `orderModified` added to a tracker, `note` renamed to `name` on an entry,
    /// and the `Pin` type deleted.
    ///
    /// It converts to the shape version 2 has *now*, not the one it had the day it
    /// was bumped — `section` became `group` and `orderModified` split off
    /// `modified` later, both while nothing had shipped. Those intermediate shapes
    /// existed only on our own simulators and this step does not read them.
    ///
    /// **`pins` is dropped, and that is the one thing a version 1 file loses.** The
    /// alternative is turning each pin into entries, which writes rows into a
    /// history at times when nothing was logged.
    private static func v1ToV2(_ document: [String: Any]) -> [String: Any] {
        var document = document

        // Rewritten only where the key is present and holds what it should. The
        // tempting `as? [[String: Any]] ?? []` is the dangerous version: a
        // `trackers` key holding something unexpected would migrate into an empty
        // array, decode cleanly as a document with no trackers, and be saved back
        // over a file that still had them. Left alone, it fails to decode and the
        // file is quarantined whole.
        if let trackers = document["trackers"] as? [[String: Any]] {
            document["trackers"] = trackers.map { tracker in
                var tracker = tracker
                // Written rather than left out: both are non-optional on `Tracker`
                // and a synthesized decoder does not fall back to a property's
                // default for a missing key. Empty is what every version 1 tracker
                // was — not grouped with anything.
                tracker["group"] = ""
                // The tracker's own `modified`, not now: stamping an old file with
                // today's date would let it win every ordering conflict the first
                // time it met another device.
                if let modified = tracker["modified"] { tracker["orderModified"] = modified }
                return tracker
            }
        }
        if let entries = document["entries"] as? [[String: Any]] {
            document["entries"] = entries.map { entry in
                var entry = entry
                if let note = entry.removeValue(forKey: "note") { entry["name"] = note }
                return entry
            }
        }
        // Explicit, though the decoder would ignore it: dropping data is a
        // decision, and one made by omission reads as an oversight.
        document.removeValue(forKey: "pins")
        return document
    }
}
