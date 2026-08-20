import Foundation

/// The version probe, the steps that carry an older file forward, and the
/// refusal of everything they cannot reach.
///
/// `schemaVersion` is an integer and a migration is a function from N to N+1,
/// run at load — see "The file" in docs/TECH.md. Nothing here is declarative
/// and there is no framework: a step is a plain function over the decoded
/// JSON, and the chain is a loop that applies them in order until the document
/// claims the version this build reads.
///
/// **The refusal is still the load-bearing part.** A step exists for a version
/// only when somebody has written and tested one; every other version is a
/// version this build cannot read, and it is refused rather than decoded with
/// today's rules. Decoding an unfamiliar document would silently drop whatever
/// it holds under a key that has since been renamed or removed, and the next
/// save would write that loss back over the only copy the user has. `load`
/// moves such a file aside intact instead.
enum StoreMigration {

    /// One version's worth of change, applied to the JSON rather than to a
    /// Swift type.
    ///
    /// It has to be the JSON. `StoreDocument`, `Tracker` and `Entry` only ever
    /// describe the *current* shape, so a step written against them could not
    /// see the field it exists to rename — by the time one of them has decoded,
    /// the old field is already gone. The alternative is a frozen copy of every
    /// model type for every version that has ever existed, maintained forever;
    /// a dictionary of the file's own keys costs one function per bump and
    /// nothing between bumps.
    ///
    /// Deliberately not throwing. A step's job is to move what is there, and
    /// anything it cannot make sense of is caught moments later by the decoder,
    /// which refuses the document and leaves the file quarantined intact. A
    /// step that could refuse would be a second, weaker copy of that check.
    ///
    /// **What a step must not do is put a value in that JSON cannot hold** — a
    /// `Date`, a `UUID`, a `URL`, anything that is not a string, number, bool,
    /// array or dictionary. `JSONSerialization` answers those with an
    /// Objective-C exception rather than a Swift error, so it cannot be caught
    /// and it takes the process down; on the launch path that is a crash loop
    /// with no screen the user can reach to get out of it, where every other
    /// bad document is merely quarantined. `chain` checks each step's output
    /// for exactly this and refuses the document instead.
    ///
    /// One thing the check does not catch, measured rather than assumed: a
    /// Swift `Optional` holding `nil`, boxed into `Any`, bridges to `NSNull`
    /// and is perfectly valid JSON — `["group": maybeString as Any]` writes
    /// `"group": null`. That decodes as a missing value, so the file is
    /// quarantined at the next launch instead of migrated. Bad, but not the
    /// same kind of bad, and no guard here can tell it from a step that meant
    /// to write a null.
    ///
    /// `@Sendable` only so that the table below can be a `static let` under
    /// strict concurrency. A step captures nothing and is called synchronously
    /// on whichever thread is doing the load.
    typealias Step = @Sendable ([String: Any]) -> [String: Any]

    /// Keyed by the version each step *reads*: `steps[1]` takes a version 1
    /// document to version 2.
    static let steps: [Int: Step] = [1: v1ToV2]

    private struct VersionProbe: Decodable { var schemaVersion: Int }

    /// Reads a file this build is willing to be responsible for, or refuses it.
    static func migrate(_ data: Data) throws -> StoreDocument {
        let supported = StoreDocument.currentSchemaVersion
        let found = try StoreCoding.decoder().decode(VersionProbe.self, from: data).schemaVersion

        // The case every launch takes, and the reason the version is probed
        // before the document is parsed as JSON: a current file never pays for
        // the second parse that migrating one needs.
        if found == supported { return try decodeCurrent(data) }

        // A newer file is refused and never migrated. It comes from a build
        // that knows more than this one, and there is no such thing as a step
        // that runs backwards: what it holds under a key this version has never
        // heard of cannot be preserved by a version that has never heard of it.
        guard found < supported else {
            throw StoreError.futureSchema(found: found, supported: supported)
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Not reachable through the probe above, which needs an object to
            // decode at all. Written down rather than forced anyway, because
            // this is the path that ends with a file being replaced.
            throw StoreError.invalidDocument("the file is not a JSON object.")
        }
        let migrated = try chain(object, from: found, to: supported, steps: steps)
        return try decodeCurrent(JSONSerialization.data(withJSONObject: migrated))
    }

    /// Applies one step per version, in order, from `found` up to `target`.
    ///
    /// Separate from `migrate` so that the chaining itself can be tested with
    /// steps of a test's own making. There is one real step today and there is
    /// no way to write a two-step chain out of it, but the ordering, the
    /// version bookkeeping and the missing-step refusal are the parts that will
    /// be wrong long before any individual step is.
    ///
    /// A gap refuses the whole document rather than stopping partway. Half a
    /// migration is a document in a shape no version of the app has ever
    /// described, and it would decode into whatever today's rules make of it.
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
            // See `Step`: a value JSON cannot hold would not throw here, it
            // would kill the process inside `JSONSerialization`. Checked per
            // step rather than once at the end so the refusal names the step
            // that did it, and so a chain cannot be half-applied before it is
            // noticed.
            guard JSONSerialization.isValidJSONObject(document) else {
                throw StoreError.invalidDocument(
                    "the migration step from version \(version) produced a value that is not JSON."
                )
            }
            version += 1
            // The loop stamps the version, not the step, so that no step can
            // forget to — and so the next one can read `schemaVersion` and
            // trust it to say which shape it has been handed. The decoded
            // document's own version is normalised afterwards either way.
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
    /// `orderModified` added to a tracker, `note` renamed to `name` on an
    /// entry, and the `Pin` type deleted.
    ///
    /// It converts to the shape version 2 has *now*, not the one it had the day
    /// it was bumped — `section` was renamed to `group` and `orderModified`
    /// split off `modified` later, both while nothing had shipped and the shape
    /// was still free (docs/TECH.md, "Two classes of decision"). Those
    /// intermediate shapes existed only on our own simulators and this step
    /// does not try to read them.
    ///
    /// **`pins` is dropped, and that is the one thing a version 1 file loses.**
    /// A pin was a saved value you could log with one tap; the feature it
    /// belonged to was replaced by search-and-repeat over your own named
    /// entries before any of this shipped, and the type went with it. The
    /// alternative is turning each pin into entries, which would write rows
    /// into a history at times when nothing was logged — inventing a record of
    /// something the user never did is worse than losing a shortcut they can
    /// retype.
    private static func v1ToV2(_ document: [String: Any]) -> [String: Any] {
        var document = document

        // Rewritten only where the key is present and holds what it should. The
        // tempting `as? [[String: Any]] ?? []` is the dangerous version: a
        // `trackers` key holding something unexpected would migrate into an
        // empty array, decode cleanly as a document with no trackers, and get
        // saved back over a file that still had them. Left alone, it fails to
        // decode and the file is quarantined whole.
        if let trackers = document["trackers"] as? [[String: Any]] {
            document["trackers"] = trackers.map { tracker in
                var tracker = tracker
                // Both are non-optional on `Tracker`, and a synthesized decoder
                // does not fall back to a property's default for a missing key,
                // so they have to be written here rather than left out.
                //
                // Empty is what "not grouped with anything" means, which is
                // what every version 1 tracker was.
                tracker["group"] = ""
                // The tracker's own `modified`, not now: `orderModified` is
                // compared against other devices' positions by the merge, and
                // stamping an old file with today's date would let it win every
                // ordering conflict on arrival. The record's last change is the
                // most recent moment its position is known to have been set.
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
        // decision, and a decision made by omission reads as an oversight.
        document.removeValue(forKey: "pins")
        return document
    }
}
