# Technical design

Decisions and the reasoning behind them. Every one of these went through
performance and simplicity — see the end of [PHILOSOPHY.md](PHILOSOPHY.md).

## Platform

| | |
|---|---|
| Language | Swift 6.2, Swift 6 language mode |
| UI | SwiftUI |
| Minimum iOS | 18.0 |
| Built with | Xcode 26 |
| Charts | Swift Charts (first-party) |
| Dependencies | none |

**iOS 18** covers iPhone XR and newer, which is meaningfully more people than
iOS 26 would reach. This app needs nothing that only exists in iOS 26, and
building with Xcode 26 means it still picks up the current system look on
current devices.

## Storage: a JSON file

**The store is one JSON file. It is decoded into plain Swift structs at launch
and lives in memory. That's the whole persistence layer.**

### Measured, not assumed

Benchmarked before deciding: same data, same question, fresh process each run,
release build, median of repeated runs. macOS on Apple Silicon, so treat these
as optimistic in absolute terms — an old iPhone is several times slower — but
the ratio is what matters. Process-launch baseline ~5ms is included.

**Taken 2026-08-09 (`2275932`), and not reproducible from this repository.** The
harness was a throwaway that compared a JSON decode against a SwiftData stack,
and neither it nor the SwiftData model is in this history — the app has never
depended on SwiftData, so there is nothing left here to re-run. These are the
numbers the decision was made on; anyone who wants to disbelieve them has to
rebuild the comparison. What *is* reproducible, and what the design is actually
held to now, is [scale.md](scale.md), which measures the shipping app.

| entries | JSON: load all + totals | SwiftData: fetch all + totals | SwiftData: today only |
|---|---|---|---|
| 15,000 | **41 ms** | 372 ms | **12 ms** |
| 50,000 | **115 ms** | 1,226 ms | — |
| 100,000 | **216 ms** | 2,531 ms | — |

The 15,000 row used to be annotated "(~5 years)" and that annotation was wrong
by half: five years of real use was later measured at **29,756 entries**
(docs/scale.md), because the estimate behind it counted meals and not the water,
steps and weigh-ins that go with them. Nothing about the decision moves — the
50,000 row is the one that brackets five years, and JSON wins it by 10x — but
the number is corrected here so it is not read back out as a size.

SwiftData genuinely wins the launch case, because it is lazy and only fetches
today's few entries. That advantage is real and it does not matter: both are
noise against a 400ms budget.

It loses everywhere else by roughly 10x, because materializing objects is
expensive and **this app reads all of its data constantly** — the graph is the
second screen. SwiftData pays that cost on every full-range graph; the JSON
design pays 41ms once at launch and is then free forever, because everything is
already in memory.

Caveats recorded honestly: CloudKit was **not** measured (it needs a paid
account), and it only adds cost via persistent history tracking and mirroring
setup. And SwiftData's full fetch can be tuned with `propertiesToFetch` or
SQL-side aggregation — but that tuning is precisely the complexity this design
avoids.

### Why not SwiftData or Core Data

Realistic worst case is a few thousand entries a year, so a heavy user reaches
maybe 15,000 entries in five years — a couple of megabytes of JSON, tens of
milliseconds to decode, trivially small in memory. (**That estimate was low by
half**, and the measurement is in docs/scale.md: five years is 29,756 entries,
8.6MB and 122ms to decode. Still tens of milliseconds, still small in memory,
and the argument below is unaffected — but the figure to quote is the measured
one.) Once it's in an array, "today's total" is a filter. There is no query
problem here, so a query engine is pure cost: a Core Data stack spun up during launch, a schema migration
system to learn, and concurrency friction under Swift 6, all to manage data
that fits in RAM with room to spare.

The deciding argument is that **the export format and the storage format are
the same thing.** Rule 6 already requires a documented, readable JSON export.
Making that file the source of truth deletes an entire layer: export hands over
the file, import validates and replaces it, and what the user gets is exactly
what the app runs on. With a database we'd maintain a schema *and* a
serialization format *and* the mapping between them, forever, for no benefit.

### The file

- Location: app container, `Application Support/boring-tracker/store.json`.
- Contains everything: schema version, trackers, entries, tombstones.
- Pretty-printed with sorted keys — it's meant to be opened and read, and it
  diffs cleanly if someone keeps it in a git repo or Dropbox.
- `schemaVersion` is an integer. Migration is a function from version N to
  N+1, run at load, and a chain of them carries an older file up to the
  current version one step at a time. This is simpler than any framework's
  migration system and it's ours.
- **Dates are ISO 8601 at whole seconds, and that is the format's constraint
  rather than a preference.** Milliseconds were tried and rejected on
  measurement: `Date.ISO8601FormatStyle` is not a fixed point at that
  precision. `…:38.328Z` parses to a `Double` a hair below 38.328, which
  formats back as `…:38.327Z`, so a document stopped equalling itself after a
  save and a load. Whole seconds are exactly representable, so the file is
  lossless — and `Date.stamp()` canonicalises at the point of creation, so an
  in-memory timestamp can never be finer than the file and no merge decision
  can flip after a round trip. Two rules downstream depend on it:
  `StoreDocument.beats` breaks ties between records stamped in the same
  *second*, and `Store.sameDocument` exists because two deletions inside one
  second carry the identical timestamp.

### Migrating an older file

**This page used to say there was no migration step, deliberately, and that it
would earn its keep at the first release. That is what changed here:** nothing
has shipped yet, but the shape stops being ours alone the moment it does, so
the step was written while it was still cheap rather than under the first
version somebody else is holding. `StoreMigration` is the whole of it.

**A step is a function over the file's own JSON**, `[String: Any]` in and out,
not over `StoreDocument`. It has to be: `StoreDocument`, `Tracker` and `Entry`
only ever describe the *current* shape, so a step written against them could
not see the field it exists to rename — by the time one of them has decoded,
the old field is gone. The alternative is a frozen copy of every model type for
every version that ever existed, maintained forever, which is the cost this
project's storage decision was made to avoid. `steps` is a dictionary keyed by
the version each step *reads*, and the chain applies one per version, stamping
`schemaVersion` between them so a step can trust what it is looking at. The one
thing a step may not do is put a value in that JSON cannot hold — a `Date`, a
`UUID`, anything that is not a string, number, bool, array or dictionary —
because `JSONSerialization` answers that with an Objective-C exception rather
than a Swift error, which cannot be caught and would take the process down on
the launch path. The chain checks each step's output and refuses the document
instead, so a broken step lands in the same quarantine as a broken file. A nil
Swift optional is the exception it cannot catch: boxed into `Any` it bridges to
`NSNull` and is valid JSON, so it writes a `null` that the decoder then refuses
one step later.

**The refusal is still the load-bearing part**, and it is unchanged. A *newer*
file is refused outright: it comes from a build that knows more, and no step
runs backwards. An *older* one is read only if a step exists for it and for
every version between; a gap refuses the whole document rather than stopping
halfway, because half a migration is a shape no version of the app has ever
described. Everything refused is moved aside intact by `load`, never decoded
with today's rules and saved back over the original.

**Version 1 to version 2** is the one real step, and it converts to the shape
version 2 has now rather than the one it had the day it was bumped (`d6520b2`):
`group` and `orderModified` added to a tracker, `note` renamed to `name` on an
entry. `orderModified` takes the record's own `modified` rather than the moment
of the migration, or an old file would win every ordering conflict the first
time it met another device. The intermediate prototype shapes — `section`
before it was `group`, one timestamp before there were two — existed only on
our own simulators, and no step reads them.

**A version 1 file loses its `pins`**, and that is the only thing it loses. A
pin was a saved value you could log with one tap; search-and-repeat over your
own named entries replaced the feature before any of this shipped and the type
went with it. Turning each pin into entries would write rows into a history at
times when nothing was logged, and inventing a record of something the user
never did is worse than losing a shortcut they can retype.

Migrating does not rewrite the file. The document is carried forward in memory
and the next ordinary save writes it out as version 2 — and because every save
copies the old `store.json` aside first, the original survives one further save
as `store.backup.json`.

### An unknown value is kept, not refused

A `String`-backed enum throws on a raw value it does not have, and a throw at
the boundary is a refused document. So a `kind` a later version writes would
stop this build from opening the file at all, over one field it does not need
to understand. `lastTime` was written to test exactly that and then shipped as
a real kind; the rule is what makes the next one free.

`Tracker` stores `kindRaw`, the string as written, and offers `kind` as this
build's reading of it. A value that is not `dailyTotal`, `measurement` or
`lastTime` reads as `.measurement`, which shows the latest value and when it
was taken — the shape that still renders sensibly for a tracker whose
behaviour is not here yet. The string goes back out on the next save exactly
as it came in, and the CSV `tracker_kind` column carries it rather than the
fallback.

**The load is not the point; the save is.** Dropping an unrecognised tracker on
decode is the tempting version and it is the destructive one: the next ordinary
save writes the document back without it, so opening the file on the older
phone deletes a tracker and every entry underneath it, quietly and for good.
Refusing the whole document is safe but too blunt for one field — the file is
quarantined and the user is locked out of everything this build could have
shown them. **An older build must never be the reason a newer build's data
disappears**, and preserving a string it cannot interpret costs nothing.

Unknown *keys* are the same question one level up and it is not answered:
`Codable` ignores a key it has no property for, which means it also drops it on
the way out. See "Noted, not scheduled" in TODO.md for what that costs and what
it would take.

### The value a `lastTime` entry does not have

A `lastTime` tracker records that something happened and when; there is no
number anywhere in the interaction. Its entries still store `value: 0`, and
`Entry.value` stays non-optional.

**Because the alternative costs the whole app to buy one kind a `nil`.** An
optional `value` reaches every sum, every average, every chart point, the merge
tie-break, the CSV column and both editors — dozens of call sites that would
each need an answer for a case only one kind can produce, and every one of them
a place to get it wrong later. A stored 0 is a value the arithmetic already
handles: it adds nothing to a total, and the totals index never sees it anyway,
because that index is built from daily-total trackers only.

**The 0 is written in one place and drawn in none.** `Store.logNow` is the only
thing that writes it, and `Tracker.entryText` is the only thing any screen asks
for an entry's value as text — it answers "Logged" for this kind, so History,
tracker detail and anything added later cannot print the zero by forgetting to
ask. **If a 0 ever appears on screen for a `lastTime` tracker, that is a bug**,
not a display choice, and the place to fix it is whichever call site went to
`format` instead.

The cost of the choice is that the file and the CSV both carry a `0.0` that
means nothing, and a spreadsheet summing the `value` column across every kind
gets the same answer either way. That is the honest trade: the number is noise
in the export and silence in the app.

### The CSV view

JSON is the complete document and the only import format. CSV is a flat,
spreadsheet-friendly view of the history: **one row per entry**, oldest first,
with these columns:

| column | meaning |
|---|---|
| `entry_id` | stable UUID of the entry |
| `batch_id` | shared UUID for values written by one log; blank when absent |
| `date` | ISO 8601 timestamp |
| `tracker_id` | referenced tracker UUID, retained even if the tracker was deleted |
| `tracker_name` | current tracker name, blank if the tracker was deleted |
| `tracker_unit` | current unit, blank if unavailable |
| `tracker_kind` | the stored kind string — `dailyTotal`, `measurement` or `lastTime`, or one a later version wrote; blank if unavailable |
| `value` | the stored number; always `0.0` for a `lastTime` entry, whose date is the data |
| `name` | entry label, blank when absent |

Fields containing commas, quotes, or line breaks use ordinary RFC 4180-style
quoting, and rows use CRLF endings. Tracker records with no entries and
tombstones are not rows, so CSV is not lossless and is intentionally not
importable. `batch_id` is present specifically so a logged food can be rebuilt
as one event rather than mistaken for unrelated tracker values at the same time.

That quoting test asks the *scalars*, not the Swift `Character`s. Swift treats
CRLF as a single character, so a name holding a pasted Windows line break
answered `false` to `contains("\r")`, went out unquoted, and split its row in
two — shifting every column after it. A bare LF was caught only by the accident
of being its own character.

Names go out exactly as typed. A CSV export is your own numbers coming off your
own phone, so the file says what you wrote and nothing rewrites it.

### Writing safely

Whole-file rewrite is the obvious risk, and it's fully solvable:

1. **Atomic writes.** `Data.write(options: .atomic)` writes a temp file and
   renames it. A reader sees either the complete old file or the complete new
   one, never a torn one. A crash mid-write cannot corrupt the store.
2. **Backup.** The previous good file is kept as `store.backup.json` before
   each write. If the main file ever fails to decode, load the backup and tell
   the user plainly.
3. **Debounced and off the main thread.** Mutations update memory immediately
   so the UI is instant; the write is coalesced (~0.5s) and runs off the main
   actor. An explicit flush happens on `scenePhase` leaving active, so
   backgrounding or force-quitting can lose at most the last moment of typing.
4. **Never partial.** There is no such thing as a half-saved store. Every
   write is the entire, valid document.

**Import does not use the debounce.** It drains anything the debounce still
owes, then writes the imported document itself before it reports success, so
force-quitting the app while the "Import complete" alert is up cannot discard an
import the app has already announced — and a write queued for the pre-import
document cannot land on top of the imported one. Every other mutation is worth
coalescing; the one action a person takes and then immediately quits is not.

**Every import has a one-step safety net, merge included.** It writes the exact
current document — including edits still inside the save debounce — to
`store.before-import.json`. Settings exposes **Restore Previous Data…**
whenever that file exists. Restoring swaps the documents: the current one becomes
the recoverable backup, so a mistaken restore can be reversed too. A later import
intentionally advances this one-step backup.

**Deleting all data is the same transaction with an empty argument.**
`Store.clearAll` is a replacing import of `StoreDocument()`, run through the
same `applyIncoming` — so it inherits the drained save queue, the staged copy,
and the restore row, and one confirmation naming the counts is then enough
(docs/TODO.md item 24). The row is called *Restore Previous Data…* rather than
*Restore Data Before Last Import…* because a clear fills the slot too. It writes
**no tombstones** for what it removes, which is `replace`'s meaning inherited:
the document afterwards is the argument, so an older export merged back in
returns the data, and "start over" does not leave a file as long as the history
it just removed.

**The recovery promise is conditional, because restoring is stricter than
loading.** `StoreFile.load` validates nothing, so a hand-edited `store.json`
with a duplicate id or `decimals` outside 0…3 opens fine — and
`restoreImportBackup` runs `validateImport` and refuses it, which would make a
clear irreversible under a dialog that had just said it was not.
`Store.currentDocumentIsRestorable` asks the question before either destructive
confirmation words itself, and both say the other thing when the answer is no.
No document this app can produce fails it.

The copy is **staged beside the slot and committed only once the imported
document is safely on disk.** The slot holds one document, so overwriting it is
itself destructive: writing straight into it and only then writing the import
meant a failure on that second write — a full disk being the realistic one — left
the user with neither. The document they might still want back had already been
replaced by the one they were importing over, under an alert that said nothing
had changed. Staging costs one extra file and makes the pair recoverable in
every order they can fail in.

Merge gets the copy even though it is the non-destructive-sounding option,
because it isn't one: the incoming document carries **tombstones**, and a merge
honours them. An export from two months ago, or a file from someone else's
phone, can therefore delete entries that exist here and appear nowhere in the
file. That loss is exactly as permanent as a replace's and arrives with none of
its warning. The fix is the cheap side of the trade — one extra write of a
document the app was about to write anyway — so merge takes the backup and
**does not** gain a confirmation dialog for it. A tap on a safe action is the
ceremony PHILOSOPHY.md exists to refuse; the backup costs the user nothing.

**An import that changes nothing does not advance the slot.** There is nothing
to recover from it, and the slot holds exactly one document. Spending it there
would mean that re-merging a file you already have — the import people repeat,
and the only one behind no confirmation — could burn the recovery point for the
replace that actually needed it. "Changes nothing" is asked of the documents in
a canonical order, because `merged` sorts tombstones by `(deleted, id)` while
the live store appends them as deletions happen: two deletions inside one second
carry the same timestamp, so a plain `==` called a genuine no-op a change about
half the time, on nothing but array order.

Whether a copy was actually kept is carried back in `ImportSummary` rather than
assumed, so the completion alert cannot promise a safety net that a no-op import
never created.

**A failed import is not evidence about the file.** The same call fails when a
*write* fails — a full disk is the realistic one — and only a `DecodingError`
says anything about what was handed in. Reporting every error as a damaged
export told a phone that had run out of storage that its backup was corrupt,
and sent its owner off to re-export a file that was fine.

**"Nothing was changed" is true of import, restore and clear alike**, and it is
true structurally rather than by three careful wordings: all three are one
`Store.applyIncoming`, and every way it can fail throws before memory or the
live file has moved.

The price of the rest, stated: a merge that *does* change something advances the
slot, so it can still overwrite a pre-replace copy. That is a worse trade only
for someone undoing an import two imports ago, which one step never promised,
and a better one for everyone whose merge quietly deleted something and
previously had no way back at all.

### Surviving a new phone

Getting a new iPhone must not lose your history, and this needs no cloud
service — it needs the file to be in a directory Apple already backs up.

- The store lives in `Application Support` (inside the App Group container, so
  a widget can read it later). That location is included in iCloud Backup,
  encrypted computer backups, and direct device-to-device transfer.
- It must **never** be marked `isExcludedFromBackup`, and must never be moved
  to `Caches` or `tmp`, which are not backed up. This is a one-line mistake
  that silently destroys people's history on upgrade, so it gets a test that
  asserts the resource value.
- That covers restore, not sync. Two phones used at once will not converge —
  that's CloudKit's job, and it's out of scope (see PRODUCT.md).
- Export remains the answer for anyone who doesn't trust device backups, and
  the only answer that survives leaving iOS entirely.

### The ceiling, honestly

**Measured at 29,756 entries — five years of real use — in
[scale.md](scale.md), and the claim that used to be here was half wrong.** It
said the design is comfortable into the low hundreds of thousands of entries.
It was written from the document benchmark above rather than from the app, and
it measured the right thing about the wrong layer.

**The store holds, and comfortably.** The 8.6MB file decodes in 122ms, costs
about 5MB of memory, merges with another five years in 96ms, and re-encodes on
every save in 100ms off the main actor. Launch grows by 135ms against a
1,028-entry store and nothing else on the common path grows at all: the log
sheet opens and accepts a number in exactly the time it does with two months of
history, because neither it nor logging touches the entry list. Extrapolating
the decode, 100,000 entries is roughly 400ms at launch and some 17MB in memory.
There is still no reason to put SQLite behind the store interface, and if there
ever is, it remains a contained change.

**Two screens did not hold, and the reason was a `Section`.** History built a
row per *log* and tracker detail a row per entry, and both a *section per day* —
for History, **17,647 rows and 1,733 sections** at five years, one section per
day that has anything in it rather than one per day on the calendar — and a
`List` pays about **0.8ms for every section it is handed, whatever is in it**. Opening History blocked the
main thread for 1.5 seconds; all 17,647 rows in a single section cost 185ms.
Both screens now draw one section with the day heading as a row, and open in
**321–327ms** and **363–586ms**, still showing every row (docs/scale.md).

The paragraph that used to be here concluded that the fix was "fewer rows on
screen at once — a windowed or paged history". That was wrong on both halves:
the rows were not the cost, and hiding rows is the one thing History may not do.
Left recorded because it is the more useful half of the lesson — **the honest
move was to find what the list was being charged for, and the plausible move was
to reduce the obvious quantity.**

So the ceiling is now the ordinary linear one: both screens grow with rows and no
longer with days, the store is fine well past 100,000 entries, and **nothing on
the common path — launching, opening the log sheet, logging a number — grows
with history at all.** The one thing left that scales and is not a list is Swift
Charts drawing 1,826 bars for the "All" range, at 255–262ms; it is its own item
and it is not on any common path.

## Two classes of decision

Worth separating, because they deserve opposite attitudes and it is easy to
spend caution on the wrong one.

**Stored decisions** change the shape of the document: a new field, a removed
type, a changed meaning. They are nearly free right now and expensive the day
somebody else's history depends on them, because then every one needs a
migration and a way to be wrong about their data. Be slow and deliberate here,
and get them done before the **first App Store release** — that is the freeze
point, not daily use on our own phone, where a schema change still costs only
deleting the app or hand-editing the JSON.

**Displayed decisions** are everything computed from the document at read time:
ranking, ordering, what an empty state shows, whether a tap logs immediately or
opens a sheet, how a graph aggregates. These cost nothing to change, ever. You
can replace an entire interaction after a week of use and lose no data and owe
no migration.

Most of what feels like a big product question — how presets work, how search
ranks, what the log sheet does first — is the second kind. Treat it as an
experiment, ship the simplest version, and change it once you have used it.
Only reach for the first kind when the experiment genuinely needs a fact the
document does not already record, and when it does, say so loudly, because that
is the expensive move.

## Why a group is a string, not an entity

Settled, but it is a real trade rather than an obvious call, so the reasoning
is recorded — including the part that argues the other way.

**The UI is identical either way**, which is worth saying because it is easy to
assume otherwise. You add a tracker and pick or type a group name; with an
entity it would be created implicitly when the name is new. No user could tell
which model is underneath, and neither design implies a management screen.

**For the string.** A group is a label some trackers share, not a thing with an
existence of its own. An entity can exist with nothing in it, and that one fact
forces questions that currently cannot even be asked: is an empty group kept or
deleted, shown or hidden, and what does a tracker pointing at a deleted group
mean? Every answer is a rule, and some become UI. With a string, delete both
tire pressures and `Honda wheels` is simply gone, because it was never more
than what those trackers said about themselves. That tax is permanent and paid
on every future screen.

**Against the string, honestly.** Renaming a group is N record edits. Rename it
on the iPad while offline, add a third tracker to it on the phone, and the
merge yields *two* groups: the renamed ones, and the newcomer still carrying
the old name. Silently split. An entity renames in one record and merges
exactly. This is the same shape as the `sortIndex` bug the review caught, and
it should not be waved away.

**Why the string still wins.** A rename is rare, the split is immediately
visible, and the fix is to rename again. The editor also offers existing group
names rather than free text, so the common path never retypes one. A rare
visible annoyance beats a permanent invisible tax.

This is a *stored* decision (see below), so it wants settling before the first
release. Until then, switching costs nothing.

## Mergeable by design

Two devices is a stated goal (iPhone + iPad), so the document is built to merge
from day one. This is a data-model decision, not a sync feature — retrofitting
it after people have real history means a migration and a window where deleted
entries come back from the dead.

Two cheap additions make it work:

- **`modified: Date` on every record.** Last write wins on a conflicting edit.
- **`orderModified: Date` on Tracker**, covering `sortIndex` and nothing else.
  A merge compares whole records, and dragging one row renumbers every row it
  passed — so under a single stamp a reorder on the phone silently discarded a
  rename made on the iPad an hour earlier. Dropping the stamp instead was
  worse: the two copies then differed only in `sortIndex` with equal
  timestamps, the tie-break fell to comparing the records as text — which is to
  say comparing `sortIndex` — and each tracker took its highest index
  independently, giving duplicate indices and an order neither device chose.
  A field that gets rewritten without anyone editing it needs its own stamp.

  Two consequences worth stating, because both were got wrong first. A drag
  stamps **every** row, not only the ones whose number changed: a reorder is a
  decision about the whole list, and stamping it in part let two devices' drags
  interleave into an order neither had shown. And the conflict tie-break reads
  **content only** — `sortIndex` and `orderModified` are blanked before records
  are compared as text — because the merge rewrites those fields on the
  survivor, so a tie-break that could see them would depend on what had already
  been merged. Position and content are reduced as two independent joins, which
  is what keeps the merge commutative and associative; the fuzz tests hold it to
  all three over 400 seeds.

  The mirror of "stamp the whole list" is that only a real position change may
  stamp at all. Adding a tracker appends, and an append moves nothing — so it
  takes the next index and leaves every other record's `orderModified` alone.
  Restamping there let adding a tracker on the phone outrank, and silently
  discard, a drag made on the iPad, which is a claim about an order nobody on
  the phone had touched. Only slotting a grouped tracker in among its group
  pushes rows down, and only that renumbers and stamps.

  When it does stamp, it stamps every row, including the ones above the
  insertion whose index provably did not change — with the same consequence a
  drag has: a tracker added to a group on the phone beats a drag made on the
  iPad an hour earlier. That is the trade taken knowingly, because the
  alternative is stamping in part, which is the case above that two devices
  interleave into an order neither chose. A partial stamp is worse than a
  coarse one, so an insertion is a whole-list decision like any other.

  Not claimed: unique `sortIndex` after every merge. Two devices that each add a
  tracker can still pick the same index, and nothing renumbers across a merge.
  The `(sortIndex, id)` sort settles that deterministically, and the list is
  drawn from it either way.
- **Tombstones.** Deleting records the id and time of deletion instead of
  dropping the row. Tombstones older than a generous window get compacted away.

Merging two documents is then a union by id: keep the newer version of anything
edited on both sides, and let a tombstone beat a resurrection. Entries are
essentially append-only records with unique ids, so the common case — two
devices each logging different meals — is a union with no conflict at all.

This pays off immediately, before any sync exists: **import can merge** rather
than only replace, so restoring an old backup or pulling in a second device's
export doesn't destroy what you already have.

Sync transport is deliberately left open and comes after v1 — CloudKit's API
directly, an iCloud Drive file, or nothing. All of them need the paid developer
account. The merge core needs none of it and is fully testable on a laptop,
which is exactly why it gets built first.

## Model

Plain `Codable` value types. No classes, no framework base types, no
`@Model`.

```swift
struct Tracker: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var unit: String
    var kindRaw: String     // "dailyTotal" | "measurement" | "lastTime" | whatever was written
    var decimals: Int
    var sortIndex: Int
    var isArchived: Bool
    var group: String       // "" when the tracker isn't grouped
    var modified: Date      // every field but sortIndex
    var orderModified: Date // sortIndex only — see "Mergeable by design"
}

struct Entry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var trackerID: UUID
    var value: Double
    var date: Date          // when it happened — editable, often backdated
    var name: String?       // the food, not the tracker
    var batchID: UUID?      // the other entries saved with it
    var modified: Date      // when the *record* changed, not when it happened
}
```

`Tracker.kind` is a computed reading of `kindRaw` and not a stored field — see
"An unknown value is kept, not refused". `Entry.modified` is not decoration and this listing used to omit it: "`modified`
on every record" under "Mergeable by design" is a requirement of the merge, and
an `Entry` without one cannot take part in last-write-wins. It is distinct from
`date` — editing last Tuesday's dinner today moves `modified` and leaves `date`
alone. `Tombstone` is the third stored type, and it is `id` plus `deleted`.

Entries reference trackers by id rather than nesting, so deleting a tracker
and keeping its history is a decision rather than a cascade.

What one log writes is a **log group** — a group when the trackers are logged
together, a single tracker when it isn't in one. It is an enum computed from
`Tracker.group` at read time, never stored, so it is a displayed decision and
free to rework. It exists because the alternative was to treat "no group" as a
group, which puts unrelated trackers in one sheet and claims something untrue
about them.

`group` is a string and `name` is a label, both for the same reason: the
alternative is a record to create, clean up and merge. PRODUCT.md says what
each one means. `sortIndex` is one global run over all trackers. Ordering and
membership are independent: settings changes `sortIndex`; the tracker editor
changes `group`.

There is no `Pin`. Saved presets were replaced by searching your own named
entries, which is a feature delivered by removing a type rather than adding
one.

### The history row, and the three rules it carries

`HistoryItem` is derived, not stored — a batch's surviving members, or one
ordinary entry — and three of its rules are invisible from the code that
implements them.

**`names` is the single place that decides what a batch is called.** Members
can disagree, because tracker detail edits one entry at a time. While the row
and `BatchEditor` each had their own rule for picking one, the editor opened
blank on a batch the row showed a name for, and saving wrote that blank over
every member.

**`keeping(_:)` is asked twice per row on the Log again path and the two asks
must stay separate** — once to decide membership, once to cut the row down to
what a tap will write. Merging them into one predicate decides membership on
what a tap writes, which empties the list the moment anything is archived; that
is why membership keeps archived members and content does not, and why the
call returns `self` unallocated when everything is kept.

**`RepeatKey` compares values as stored and names exactly.** As *stored*,
because `decimals` is editable: keying on the formatted string would make the
key depend on a setting, and cost a `Tracker.format` per value over thousands
of rows. The accepted price is that dropping a tracker to zero decimals can
leave two rows both reading "rice / 100 kcal". *Exactly*, unlike `matches`,
which folds case and diacritics: search decides what you are shown, the key
decides what is hidden behind a row, and a normalisation that swallows the
wrong two rows is invisible from the screen.

## The store object

One `@Observable @MainActor final class Store` holds the arrays and is the
only thing that mutates them. Views read it from the environment. There is no
repository, no view model per screen, no coordinator, no dependency injection
container, no Combine. SwiftUI already observes state; adding a layer to help
it observe state is the kind of thing this app exists to avoid.

Mutations are ordinary array operations. The store keeps one derived index —
daily totals keyed by tracker and local day — updated incrementally on add,
edit, and delete, so the home screen never scans the entry list to draw
today's number.

## Dates and the day boundary

The single most bug-prone part of this app, so it gets stated precisely and
tested hard.

- An entry stores an absolute `Date` (UTC internally, as `Date` always is).
- A "day" is computed in the **device's current local calendar and time
  zone**, at read time, never stored.
- Consequence, accepted deliberately: fly to another time zone and yesterday's
  totals can shift. The alternative — freezing each entry's day at write time —
  is worse, because then your totals disagree with the calendar you're
  currently living in.
- Day rollover is midnight local **by default, and the hour is now settable**
  (`DayStart`). This reverses the line that used to sit here, and the line
  under "Decisions worth writing down" — see that entry for why the cost turned
  out to be lower than it was written to be. Nothing about the offset is
  stored: it is applied where a day is derived, so turning it back re-derives
  exactly what was there before.
- Everything inside the store derives its day through `Store.dayKey(_:)`, and
  everything on screen through the `DayKey` calls that take the store's hour.
  The offset is applied in one place for the same reason the day itself is: a
  second copy of the rule is how the totals index comes to disagree with the
  screen reading from it.
- **The offset is read off the wall clock, not subtracted in seconds.** Taking
  `hour × 3600` off the date first is the obvious version and it is wrong
  across DST — on a spring-forward morning it walks back through the hour that
  never happened and files 04:30 under yesterday.
- Tests cover: DST forward and back, year boundaries, time zone travel,
  entries logged at 23:59:59 and 00:00:00, and every one of those again with
  the day cut somewhere other than midnight.

## Performance budget

Numbers to hold the design to. **They are defined against the oldest supported
device and have never been measured on one** — this line used to say "measured
on the oldest supported device", which read as a claim about the figures under
it, and every figure under it comes from an iPhone 17 Pro simulator on an M4
Pro. That environment is faster than any phone in absolute terms and still
misses the 400ms launch budget at *both* two months and five years of data,
which is why scale.md records the launch delta rather than a verdict and leaves
"is the budget wrong, or is the launch genuinely slow?" open. Settling it needs
a real device, and that is TODO item 17.

- **Cold launch to interactive: under 400ms.** No splash, no async gate before
  the UI draws. Loading the store is a synchronous decode of a small file
  because doing it asynchronously would flash an empty state for longer than
  the decode takes. Measured at five years of history (docs/scale.md):
  622–669ms in an iPhone 17 Pro simulator, against 488–505ms with a 60-day
  store, so the data costs 135ms of it and the rest is the app starting at all.
- **Tap + to sheet visible: one frame.** The log sheet is trivial and pre-warmed;
  nothing is fetched when it opens. The app adds no presentation animation;
  the numeric keypad's system animation is the remaining wait before typing.
- **Log to dismissed: instant.** Memory is updated synchronously, the sheet
  closes, the disk write happens later and off the main actor.
- **Graph redraw: 60fps while scrubbing** over a year of data. Points are
  aggregated once when the range changes, not per frame.
- **Opening Log again: one list build, never one per redraw.**
  `Store.repeatItems` walks and sorts the whole history — about 20ms over 7,600
  entries and 40ms over 15,300, Debug on an iPhone 17 simulator — so the sheet
  snapshots it as it appears and filters the snapshot. Reading the property from
  `body` instead would pay that on every keystroke in its search field;
  filtering the snapshot costs a fraction of a millisecond.

  Re-measured when the screen became a sheet (docs/TODO.md item 20), same
  method, five runs: **20.2–21.8ms over 7,641 entries and 40.8–43.4ms over
  15,291**, and **23.5–24.7ms / 49.0–50.0ms** on the shape where nothing
  collapses. Counted as well as timed — an `NSLog` in `repeatItems`, read off
  `log stream` — **one build when the sheet opens and none for focusing the
  search field or typing three letters**. The count is the half a timing number
  cannot show.

  Re-measured again at five years of use (docs/scale.md): **93.6ms over 29,756
  entries in Debug and 41.4ms in Release**, counted the same way — one build
  when the sheet opens, and none for anything else. Opening that sheet blocks
  the main thread for 216ms, most of which is the list rather than the walk.

  What that walk is made of, for anyone tempted to take a piece of it out.
  These were taken while the screen was built, lived in the source comments,
  and were moved here by the 2026-08-19 comment pass without being re-measured:
  Debug, iPhone 17 simulator, five to ten runs a column, and where two variants
  are compared they alternate in one binary so a warm-up lands on both.
  **Deduplicating rows costs about 5ms over 7,644 entries and 8ms over
  15,294**, and **projecting each row onto what a tap can actually write costs
  about 1ms and 2ms** — at the smaller size that second figure is inside the
  noise, at the larger one it is consistent. The worst shape is the one where
  nothing collapses at all: 15,294 entries that all differ cost 49.9–51.0ms
  against 32.2–32.8 undeduplicated. Deduplicating makes the *keystroke*
  cheaper rather than dearer — 0.08–0.16ms against 5.3 and 9.9 for the plain
  list — because there are far fewer rows left to filter.

## Smaller decisions, settled

So they don't get re-argued mid-build:

- **Charts use Swift Charts.** First-party, so it costs no dependency, and it
  handles bars, lines and scrubbing without help. Points are aggregated once
  per range change, never per frame.
- **English only in v1**, but all numbers and dates go through system
  formatters, so they display correctly in any region. Translations are a
  welcome pull request, not a blocker.
- **The day starts at midnight, local — and you can move it.** This entry used
  to end "No configurable day start in v1; it multiplies edge cases in every
  aggregation for a minority want", and it has been reversed deliberately. The
  reason recorded was **cost, not principle**, and the cost was overstated:
  entries store absolute dates, so the day start is a *displayed* decision
  computed at read time, with no schema change, no migration and no way for two
  devices to disagree about the data. What it does touch is everything that
  derives a day — `DayKey`, the totals index, the charts, History's grouping —
  which is why the whole day-boundary suite runs twice over, once at midnight
  and once offset. Somebody who eats at 1am is also not a minority of one.
  It lives in `UserDefaults` beside the appearance switch, for the same reason:
  it says how this phone reads the numbers, not what the numbers are.
- **Negative values are allowed.** They're meaningful (weight change, a
  correction) and rejecting them costs a validation rule and an error state.
- **Tombstones are compacted after 180 days**, comfortably longer than any
  plausible period of a second device being offline.
- **The last-used log group is a `UserDefaults` key** (`lastLoggedGroup`), and
  the only thing the app keeps outside the store file. It is what + opens, so
  it is UI state rather than data: it must not sync between devices, must not
  turn up in an export, and must not be a field somebody else's history has to
  carry. It holds a `LogGroup` in string form — `group:Food` or
  `tracker:<uuid>` — and anything that no longer resolves means + falls back to
  the first group on the home screen. A stale string costs nothing.
- **No analytics, no crash reporter, no launch screen image.** Rules 5 and the
  launch budget.
- **The log sheet is presented without animation, and the keypad cannot be made
  to arrive with it.** iOS will not raise the keyboard while a modal
  presentation animation is in flight, so a sheet's duration is *added* to the
  wait rather than hidden inside it: instant is one ramp, at 0.70s to typeable,
  and animating the sheet over the keyboard's own 0.38s is two ramps with a
  stall between them, at 1.27s. That the two do arrive at two moments and read
  as a small glitch is known and accepted — the only fix is to stop using
  `.sheet` and own the presentation, which is a much larger change than the
  half-second it would buy back.
- **The sheet's Log button is a bottom safe-area inset, not a `.keyboard`
  toolbar item.** SwiftUI's native keyboard placement emitted no visible
  accessory in an iOS 26 sheet. The inset sits directly above the keypad, drops
  to the bottom of the sheet when the keypad goes down, and lands in the same
  place on the smallest supported phone.

## The accent, and what may be painted with it

Four rules, each learned by measuring a control that turned out to be
unreadable, and coupled tightly enough that breaking one takes the others under
the floor with it. The measurements live beside the code in
`BoringTracker/Views/OnAccent.swift`; what is here is the shape of the decision.

**The contrast ratios are reproducible on paper, and were reproduced on
2026-08-19.** Every ratio quoted in this section and in TODO items 13e and 18 was
recomputed from the hex values with the WCAG 2.x formula — some fifty numbers,
counting the four candidate tables the accent explorations left in git history —
and every one matches to the second decimal. The *hex values* are the part that had to be
sampled off a screen and cannot be re-derived; the two that ship are pinned by
`AccentTests` instead, which asserts `AccentFill` resolves to `#009888` light
and `#00DAC3` dark and that nothing claims the magic `AccentColor` name.

**One constant names the hue.** `Color.accentFill` is the `AccentFill` colour
set and nothing else in the app names a colour. **Two deliberate values, one per
appearance** — `#009888` light, `#00DAC3` dark — because one hue could not serve
both: the system mint it replaced measured 2.05:1 as a light-mode bar glyph and
2.12:1 as a light-mode `Form` row, both under the floor, against 9.89 and 9.57
for the same colour in dark (TODO item 18). The dark value *is* the system
mint's own byte, so the appearance this app is used in did not move; the light
value is that mint at the same hue and saturation, darkened until it measures
what the system blue Apple ships measures on those two surfaces. It is not a hex
picked to taste — the numbers and the two rejected neighbours are in
`OnAccent.swift`.

The colour set is named `AccentFill` rather than `AccentColor` on purpose. A
colour set under the magic name becomes `Color.accentColor` and the app's global
tint, which would restore the inheritance the rule below removes — by filename,
with no Swift changing. A test asserts both values and that nothing claims the
magic name.

**It is a fill, and a foreground only where the OS uses colour to mean
"tappable".** Two carve-outs, both named at their call sites: `navBarAccent()`
for bar buttons and `formRowAccent()` for list action rows — a `Button`, a
`ShareLink` or a `Link` in a `List`, none of which get a disclosure chevron, so
they have no other way to say they are buttons. Note that the *navigating* rows
in settings do not get theirs from the platform either: `rowButton` draws its
own `chevron.right`. Everything
else that used to be accent-coloured text stays the label colour. That is why
the chart is monochrome: bars and the readings line are the label colour and the
moving average is `.secondary`, so the two are told apart by weight rather than
by a hue that was, until the colour set, not legible as text at all.

**What sits on the accent is `Color.onAccent`, which is black, and that is
load-bearing rather than tidy.** iOS draws a prominent button's label white
whatever the tint, and white on the dark fill is the worst pairing in the whole
candidate set — 1.78:1, against 11.82:1 for the black label the app forces. The
colour set's darker light value would in fact carry a white label at 3.59:1, so
the label could now flip with the appearance and clear the floor twice; it does
not, because what sits on the accent is decided by the accent and the dark value
has no such choice. So a new control that draws its own white label on the
accent does not look slightly different, it takes every accent-filled site in
the app under the floor in the appearance it is used in.

**Nothing inherits it.** The root tint is `.tint(.primary)`, not the accent. A
tint is inherited by every standard control there is, which is exactly how a
foreground use of the accent twice appeared by accident; with nothing to
inherit, a new one has to name itself. Two kinds of control do: bar buttons
through `navBarAccent()` and `Form` action rows through `formRowAccent()` —
deliberate carve-outs for system chrome, where colour is the platform saying
"tappable" rather than the app writing in colour. **The two are separate
modifiers because the mechanism differs, and that was measured both ways.** A
bar button uses `.tint`, which a disabled button correctly drops — `TrackerEditor`'s
*Save* with an empty name draws `#B0B0B2` grey — while `.foregroundStyle` there
is *not* dropped and paints the same disabled *Save* full accent, a dead button
that reads as live. A `Form` row is the other way round: `.tint` colours the
text and leaves the SF Symbol at the label colour, giving a two-colour row, and
a disabled tinted row drops to plain black, indistinguishable from a static one;
`.foregroundStyle` takes the glyph with it and dims to a 50% blend when
disabled. Nothing may paint with `Color.accentColor`, which is still the system
blue — there is an asset catalog now, but see the naming note above.

**The cost of inheriting nothing is that some controls want a tint, and get
`.primary`.** A `Toggle` under this root tint is a solid white capsule in dark
mode, on and off indistinguishable — measured in review when the rule went in,
and noted as the shape of the problem rather than a bug, since the app has no
`Toggle`. History's delete swipe action turned out to be the same case for real:
`role: .destructive` asks for red, loses to the inherited tint, and drew as a
blank white capsule with an invisible label — no glyph and no word — on the one
control in the app that destroys a record (TODO item 20). It names `.tint(.red)`
itself now. **A control whose meaning is carried by colour has to state that
colour where it is used**, the same way a bar button states `navBarAccent()`.

**And a control that appears on more than one screen states it once, in a view
both screens use.** Stating the colour at each site is what the rule above
asks for, and it is also how sites drift apart: "log this again" reached three
screens and one of them — home's bottom bar, the app's only
`.buttonStyle(.bordered)` — drew a grey square with a *white* glyph beside two
accent discs with a black one (TODO item 21). Same glyph, same VoiceOver label,
two answers about what kind of control it is. It is `RepeatDisc` now, one view
in three places, next to `UndoButton`, which exists because the same thing
happened to Undo one item earlier. **Prominence is carried by size and shape,
not by hue**: home's copy stays secondary because it is a circle with no word on
it against a pill six times its width. It is 50pt there and 30 on a row, which
`RepeatDisc` takes as a parameter rather than forking the view (TODO item 33).

**The light-mode foreground failure was real, and the colour set is the fix.**
One system hue could not be both a legible fill and a legible foreground on
white — that is the whole reason there are two values rather than one. With the
darker light value the accent measures 3.48:1 as a bar glyph and 3.59:1 as a
`Form` row foreground, against the system blue control's 3.41 and 3.52, so both
appearances clear the floor and the `Form` action rows have their colour back
(TODO items 18 and 13e). The accent is stated per row rather than on the
`Section`, so `.alert` and `.confirmationDialog` buttons have nothing applied to
them and are unchanged — a button in a dialog is already unmistakably a button —
and *Delete All Data…* keeps the red its `role` gives it rather than inheriting
an accent.

**The back chevron takes no tint at all**, and this was proved rather than
assumed. Set at the app root, on the `NavigationStack`, on the destination, or
through `UINavigationBar.appearance().tintColor`, it comes back the label colour
every time — the same pixels, byte for byte — and `toolbarForegroundStyle(_:for:)`
is unavailable on iOS. A pale chevron beside a tinted `+` is what this OS draws,
not something the app took away or can restore.


### The light value is at a ceiling, and that was measured three ways

The light `#009888` looks dimmer than the dark mint does, and it gets reported
as murk about once a pass. It is not a mistake in the arithmetic — it is the top
of a short window, and the window is what this note exists to stop being
reopened.

**The window has a floor and a ceiling, and both are contrast running out.**
Walking the hue line one unit at a time: the last value that still clears 3:1 as
a nav-bar glyph is `#00A493`, at 3.02, and `#00A594` is the first that does not,
at 2.99. Going the other way, black on the fill crosses 4.5 — what a word that
size wants, over the 3:1 a UI element needs — at `#008375`, which measures 4.50.
So the usable interval is `#008375` to `#00A493`, `L*` 48.9 to 60.5, and
`#009888` sits inside it at `L*` 56.3 with about seven points of room below and
four above. Four `L*` points is not a colour change anyone notices: `#00A896`,
which is only just distinguishable from today's, already measures 2.89 as a
glyph, and `#00B3A0` — the first that reads as a genuinely lighter, fresher mint
— measures 2.56. **The honest answer to "make light lighter" is that it cannot
go much lighter while the accent is also a tint.** The bar glyph is the stricter
of the two surfaces, so it sets the ceiling whether or not the `Form` rows carry
the accent — dropping the tint from those rows does not buy the headroom back,
and item 13c tried exactly that.

**Holding the luminance and moving the hue instead does not help either.** Ten
candidates were rendered right around the wheel at the luminance the tint needs.
At that luminance the WCAG ratio is constant by construction, so what separates
them is the glyph, and the two that read lightest as a filled pill read *weakest*
as a glyph — a hazy periwinkle gear against its near-white circle where the
green and the azure stay crisp. No hue that still belongs beside dark's mint
reads lighter than the mint does.

**The one real alternative is the whole app, not the light half.** Pairing an
azure light value with today's dark mint reads as a blue app whose dark mode is
a mint app; deriving a dark azure to go with it fixes that, and `#009DD2` light
with `#04BFFF` dark is genuinely one app in both appearances, with every surface
clear of its floor. What it costs is paid in dark, which is the appearance this
app is used in: every dark number goes down without breaking — the black label
on the fill goes 11.82 to 9.90 — and the dark half loses chroma it cannot buy
back, `C*` 46.0 against the mint's 49.3, so it gets a little less light and a
little less colour at once. **Today's dark is the better dark**, which is why
the pair did not move. A plain blue (`#2693FF` light) was the other candidate
and is the one to drop: no dark blue of that hue is both bright and colourful,
and the pair reads as two relatives rather than one app.

These come from four rendering passes — twelve dark candidates, then light
deeper, light lighter, and light at constant luminance around the hue wheel —
whose contact sheets, candidate tables and reversals were kept in `docs/` while
the work was live and are now in git history. The screenshots behind them were
deliberately never committed, so the history has the numbers and the reasoning
and not the pictures. Every ratio quoted in this subsection was recomputed from
its hex value on 2026-08-19 and reproduces; the `L*` figures are recomputed too,
and the ceiling's differs by 0.2 from the one the original pass recorded, which
is a white-point difference and moves nothing.

### The pressed and the disabled fill are the system's own arithmetic

Two more colours are not chosen at all — the pressed fill and the disabled one
are the system's own arithmetic, and both reproduce on paper. Every ratio and
every composite below was recomputed on 2026-08-19 from the hex values and
matches what was sampled, to the byte.

**A `.plain` press composites the fill at 75% over what is behind it.**
`#009888` at 75% over white is exactly `#40B2A6`, and `#00DAC3` at 75% over the
card's `#1C1C1E` is exactly `#07AA9A` — both confirmed against screenshots of a
real press. So a `.plain` accent control needs no pressed colour of its own; it
darkens by 1.38–1.68 against rest, which is a press you can see.

**`.borderedProminent` is the exception, and it is the reason `.accentPill`
exists.** Pressed in dark mode, iOS draws the fill at 80% under a white wash —
`#33E1CF`, which is 1.08:1 against its own rest colour and *lighter*, while
every other accent fill on the same screen darkens. A press that goes the wrong
way on the most-tapped control in the app is not a press, and the style is not
something a tint can reach into.

**The disabled fill is `.systemGray2`, and what sits on it has to flip with the
appearance.** It draws `#AEAEB2` on History's light row and `#636366` on the
dark one — 2.21:1 and 2.84:1 against those rows — with `Color.primary` on top at
9.50:1 and 5.99:1. The `.quaternary` it replaced drew `#E8E8E8` at 1.23:1, which
is a disc that is not there rather than a disc that is off, and the `.tertiary`
glyph on top of that managed 1.32:1.

**One fixed grey cannot serve every row an archived disc lands on**, and that is
accepted rather than solved. The Log again sheet is a `.medium` detent whose
inset-grouped rows are `#DBDBDD`, where the same disc measures 1.60:1 against
the 1.8:1 this was aiming at. Nothing fixed clears 1.8 on both `#FFFFFF` and
`#DBDBDD` short of `.systemGray`, which is 2.36 on the sheet but 3.26 on white —
close enough to the enabled fill's 3.59 to be read as live. `.systemGray3` was
ruled out arithmetically at 1.68:1 on white.

**The press *scale* is derived, and writing it down again is a mistake this
project has already made.** The travel is 2pt per end of the fill's longest
edge, so the scale is a function of the size the fill laid out at. A table of
six controls' scales lived in source, went stale the moment the bottom bar's
arithmetic changed, and was still quoting a pill that no longer existed. What is
worth keeping is the guard: while the press *shrank*, `1 - 2 * travel / longest`
was zero at 4pt and negative below it, so a 3pt fill was mirrored through its
own centre. Growing cannot invert anything, so the same constant now guards a
milder rule — below it, a press at least doubles the fill.

### Sampling a colour off the screen

Read the screenshot's own bytes. `NSBitmapImageRep.colorAt(x:y:)` does **not**
return what is in the PNG on this machine, even for a file that reports itself
as `sRGB IEC61966-2.1`: it hands back a colour converted out of sRGB, which
moved the accent by 7 units per channel and the old blue by 20. Two sessions
sampled the same pixel and disagreed about what it was, and the sanity check
both of them ran — "black reads `#000000` and white `#FFFFFF`" — passes anyway,
because black and white are fixed points of that conversion. The conversion is
not per-channel either, so a hex read that way cannot be corrected on paper;
re-sample instead.

## A `ShareLink` will not present beside a `.confirmationDialog`

The export leaves by **one** door, the share sheet, and getting it there was
drawn by a platform bug, so that is written down here rather than only in the
code. (For a while there were two — a *Save to Files* row apiece beside the
share rows. Both rows and the whole `.fileExporter` path were removed in
`35a5fd0` once the share sheet worked; Files is one tap inside the sheet, and
two doors to the same bytes were two things to keep in step. The bug below is
what the second door existed to work around, so it is still the reason the
sections must not be merged.)

**A `ShareLink` in a `Form`/`List` section whose container also carries
`.confirmationDialog` silently does nothing when tapped.** No sheet, no error,
no log line, and a `Button` in the same section responds to the same tap. On
iOS 26.3 that dialog was the import merge/replace chooser, and while export and
import shared one *Data* section it took the share sheet down with it —
`531d71c` concluded from that that the share sheet was impossible in SwiftUI and
would need `UIActivityViewController`. It doesn't. **The fix is that export and
import are two sections**, so the dialog no longer sits on the container the
`ShareLink` is in; nothing else changed, and the share sheet then presents for
both formats.

Verified on an iPhone 17 / iOS 26.3, both directions of the claim: with the
rows in one section the tap does nothing while *Import JSON* beside it opens
the file importer on the same synthesized tap, and with the sections split the
same tap presents the sheet. The dated name was checked through the *Save to
Files* row that still existed at the time —
`boring-tracker-2026-08-17.json`, landing in On My iPhone byte-identical to the
store file — and that row has since gone with `35a5fd0`; the name comes from the
same `ExportName.dated` either way. See also the eight-way bisect in `3028257`,
which is what identified the modifier.

**So do not merge those two sections back together.** Nothing about the result
looks broken — the rows draw, the labels are right, the button is simply dead.

The item handed to the sheet is `ExportFile`, and it carries the
**`StoreDocument`, not the encoded bytes**: a `ShareLink`'s item is rebuilt on
every body pass of the settings list, including during a reorder drag, and
`StoreDocument` is a struct of arrays so holding one is a retain. The encode and
the write to a temporary file happen in its `FileRepresentation`, once a
destination has been chosen.

It is **one** `FileRepresentation`, typed `.data`, rather than one per format.
The representation is static, so it cannot ask an instance which type it is, and
declaring both would let a receiver asking for JSON take whichever was first and
be handed a CSV.

Two consequences of leaving by this door. **`ShareLink` has no error hook**:
anything thrown while writing the temporary file is reported by the share sheet
rather than by the app, so a full disk shows whatever iOS shows. Since `35a5fd0`
removed the *Save to Files* route there is no way out of this app that reports
an export failure in the app's own words — the remaining `show(_:action:)` calls
are open, import, delete and restore. And **`SentTransferredFile` copies what it
is handed** unless told otherwise, so deleting the share file once the sheet has
taken it is safe; `tmp` is emptied by iOS only when storage runs short, which is
not a schedule, and these are whole documents, hence the one-hour prune.

## `withAnimation` does not reach a list row's background

The mark on the row a repeat just wrote fades out (TODO item 20), and the fade
has to be attached to the colour rather than to the state change:

```swift
.listRowBackground(
    Color.accentFill
        .opacity(highlighted == item.id ? 0.2 : 0)
        .animation(.easeOut(duration: 0.9), value: highlighted)
)
```

Written the other way — `withAnimation(.easeOut(duration: 0.9)) { highlighted =
nil }`, which is how every other animation in this app is triggered — the mark
cuts off between two frames instead of fading. That is not a judgement from
looking at it: a screen recording decoded frame by frame shows the row's colour
constant for the whole hold and then at background in the very next frame,
against a smooth ~785ms decay once the modifier moved. Row *content* animates
from an ambient transaction as usual; the background view a `List` installs
behind the cell does not.

## More SwiftUI that does not do what it says

One place for the rest of them. Each cost at least a session, none of them log
anything, and every one leaves a build that compiles and a screen that draws.

**Modifiers written under `.onGeometryChange` are silently dropped.** Settings
reads every row's frame for its drop target, and `.listRowInsets` or
`.rowPress()` written *inside* the reader's builder never take: the row keeps
the platform's 74pt inset, and the press scales the row without drawing its
background wash. Two sessions lost an hour each to this, once for the insets and
once for the press. `.swipeActions` is not one of these — checked rather than
assumed. Both must be applied outside.

**A `List`'s `frame(in: .global)` is already the safe area.** On an iPhone 17
the proxy reports `(0, 116, 402, 724)` with `safeAreaInsets` of 116 top and 34
bottom, so the frame is what is left *after* the insets, and adding
`insets.top` back on counts it twice: the drop band moved to 232…806 and left
the first row outside it, so letting go squarely on that row dropped the tracker
below it.

**A named coordinate space declared on a `List` is not reachable from inside its
rows.** Each side silently falls back to a different default, which is how every
drop landed on a row nobody dropped anything on. Both ends of a comparison have
to read `.global`. `dropTarget` — a free function in `SettingsView.swift`, and
SwiftUI-free and unit-tested for this reason — has been wrong twice this way,
both times silently rewriting stored order and stamping it as a decision, and
neither time did it show in a screenshot of the list at rest.

**A `Button` hit-tests its label's drawn content unless it is given a
`contentShape`.** A label that is two pieces of drawn content with a `Spacer`
between them has a dead gap in the middle — most of a row's width. A row
tappable in two narrow places is worse than one that plainly is not: a miss
teaches you the tap failed rather than that you aimed wrong.

**An `HStack` puts its spacing on both sides of a `Spacer`**, measured at 24pt
where 8 was meant, so a row that wants one gap says `spacing: 0` plus
`Spacer(minLength: 8)`.

**`.pickerStyle(.segmented)` drops the picker's own label**, so the section
needs a header or nothing on screen names the setting. It is also the one
control `.tint(.primary)` does not spoil the way it spoils a `Toggle`: a
segmented control's selection is a background, not a fill drawn in the tint.

**`dismiss()` freezes the presentation's content.** A state change made on the
same tap is never drawn — the sheet slides away for about 300ms still showing
what it had before the tap. Held for 0ms and 50ms the mark still never appeared;
at 500ms it did, which is a delay on the common path rather than a fix. Anything
a sheet wants to say about what it just did has to be said by the screen it
uncovers.

**A `.searchable` condition that flips while the sheet is up blanks the sheet.**
The Log again list fills its snapshot in `onAppear`, one pass after the first, so
`!(items?.isEmpty ?? true)` took the field from absent to present underneath a
presentation that was already up: the sheet came back with no title and no list,
on every fixture and every text size. Asked as `!= true` the field is present
from the first pass and never has to appear.

**Focusing a field inside a transaction with animations disabled suppresses the
keypad altogether.** The log sheet is presented without animation, so a single
`await Task.yield()` before setting focus — letting that transaction finish — is
what makes an instant presentation still raise the keyboard.

**A `task` on a `NavigationStack`'s root content is cancelled by a push.**
Tapping History during home's one-second confirmation left the flag set with
nothing running to unset it, so coming back drew a checkmark for an old write.

**`.plain`'s disabled opacity is about 0.502**, and replacing the button style
takes the dimming with it silently: the Log again sheet's archived rows came
back drawing the same `#000000` a live row draws. The replacement dims by 0.5,
read off pixels rather than assumed — it draws `#6D6D6E` where the old build
drew `#6D6D6E`, and `#969696` on the dark sheet's `#2C2C2C` row.

**A caption that can wrap needs a non-breaking space before its `·`.** At AX5
the settings caption takes two lines, and with an ordinary space "Daily total ·
kcal" broke as `Daily total` / `· kcal` — a line starting with a dot. Bound to
the word before it, the same caption breaks as `Daily total ·` / `kcal`.

## Testing

Swift Testing (built in, no dependency). Tests target the parts where a silent
bug destroys data or trust, not UI:

- day-boundary and aggregation math, including the DST and time zone cases
- export → import round trip preserving everything exactly
- schema migration from every past version — a version 1 document arriving as
  a version 2 one, the chain applying two steps in order, and the refusal of a
  newer version, of a version no step reads, and of a gap in the chain
- decode failure falling back to the backup file
- atomic write leaving a valid file when interrupted

## Project layout

XcodeGen with `project.yml` as the source of truth, and the generated
`.xcodeproj` committed alongside it. That way anyone can clone and open in
Xcode with nothing installed, while configuration changes stay reviewable as
readable YAML instead of pbxproj conflicts.

**A config file has to live in a folder**, which is why there is a `Config/`
holding one file. With `createIntermediateGroups` on, an xcconfig sitting beside
`project.yml` makes XcodeGen invent a group for the *containing directory* to
put it in — named after whatever the clone is called, and with no deterministic
id — so both that group and the file reference regenerated as a fresh
`TEMP_<uuid>` every time and five lines of the committed `.xcodeproj` changed
for nothing. Any subdirectory ends it.

```
project.yml
Config/           Signing.xcconfig, and the untracked Local.xcconfig it includes
BoringTracker/
  App/            entry point, root view
  Model/          Tracker, Entry, StoreDocument
  Store/          Store, persistence, the version guard and its steps
  Views/          Home, LogSheet, History, TrackerDetail, TrackerChart,
                  RepeatView, Settings, editors
  Support/        date math, formatting
BoringTrackerTests/
docs/
```

**The App Group is *named* from the start, not entitled.** Retrofitting one
means moving the store file after people have data in it, so
`StoreFile.appGroupIdentifier` is fixed now — `group.com.novoselov.boringtracker`
— and `StoreFile.standard` prefers that container whenever the entitlement
resolves. It does not resolve today: signing an App Group needs the paid
developer account this project deliberately builds without (docs/SHIPPING.md),
there is no entitlements file and no `DEVELOPMENT_TEAM` in `project.yml`, so the
code falls back to the plain app container. The store is therefore at
`Application Support/boring-tracker/store.json` inside the app's own container,
which is what the README's `simctl get_app_container` line finds. Adding the
entitlement later moves the file once, before anybody's data is in it — which is
the retrofit this naming exists to keep cheap, not one it has already avoided.

## CI

GitHub Actions on a macOS runner: build and run tests on push and PR. Free for
public repos, and it's the only thing standing between a fork and a broken
`main`.
