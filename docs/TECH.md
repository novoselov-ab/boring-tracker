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

| entries | JSON: load all + totals | SwiftData: fetch all + totals | SwiftData: today only |
|---|---|---|---|
| 15,000 (~5 years) | **41 ms** | 372 ms | **12 ms** |
| 50,000 | **115 ms** | 1,226 ms | — |
| 100,000 | **216 ms** | 2,531 ms | — |

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
milliseconds to decode, trivially small in memory. Once it's in an array,
"today's total" is a filter. There is no query problem here, so a query engine
is pure cost: a Core Data stack spun up during launch, a schema migration
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
  N+1, run at load. This is simpler than any framework's migration system and
  it's ours.
- **There is no migration step yet, deliberately.** Nothing has been released,
  so no older file exists outside a development simulator, and one left there
  is quarantined and started over like any file that won't decode. What does
  exist is the guard that accepts the current version and nothing else, rather
  than decoding an unfamiliar file with today's rules and saving the loss back
  over the original — three lines, and needed from the first release. A *newer*
  file is refused because it comes from a build that knows more; an *older* one
  because there is no step that reads it, and letting it through would silently
  drop whatever it holds under a key that has since been renamed. The first
  shipped version is the first shape someone can be holding; that is when a
  step earns its keep, and it takes the older versions with it.

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
| `tracker_kind` | `dailyTotal` or `measurement`, blank if unavailable |
| `value` | the stored number |
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

**Names are not neutralised against spreadsheet formulas, and that is settled.**
A name is free text, so it can be `=1+1`. It round-trips exactly through an RFC
4180 parser, but a spreadsheet that reads a leading `=`, `+`, `-` or `@` as a
formula will show its own answer instead of what was typed. The usual
mitigations — prefixing an apostrophe or a tab — buy that back by changing the
bytes, so the file stops being what the user typed. Both requirements cannot be
met at once, and this is which one wins.

Written down because "CSV injection" is a phrase people remember, and this gets
re-opened every time someone does:

- **The attack is someone else's data landing in your spreadsheet.** That is
  what makes the technique dangerous: a hostile string arrives through a form,
  a shared file or a third-party feed, and a colleague opens the export. This
  app has one user per install, no server, no sharing and no imported
  third-party content. The only data in the file is what the person holding the
  phone typed into it, so there is no attacker in the picture — only a user and
  their own words.
- **Rule 6 promises the export is your data.** Mangling a name to defend
  someone from themselves breaks the exact round trip the format exists to
  guarantee, and breaks it silently, in the one file that is supposed to be the
  escape hatch when everything else has stopped being trustworthy.
- **This is reopened the day the app can receive someone else's entries.**
  Shared trackers, a sync service that accepts a remote document, an import
  path that pulls from a URL — anything that puts a string into the document
  that the user did not type brings a real attacker back, and makes
  neutralisation worth its cost. Until then it defends against nobody.

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

**Every import has a one-step safety net, merge included.** Before changing
memory it writes the exact current document — including edits still inside the
save debounce — to `store.before-import.json`. Settings exposes **Restore Data
Before Last Import…** whenever that file exists. Restoring swaps the documents:
the current one becomes the recoverable backup, so a mistaken restore can be
reversed too. A later import intentionally advances this one-step backup.

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
replace that actually needed it.

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

This design is comfortable into the low hundreds of thousands of entries —
far past anything this app will see. If that were ever wrong, the fix is to
put SQLite behind the same store interface, which is a contained change
because nothing in the UI knows how persistence works.

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
struct Tracker: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var unit: String
    var kind: Kind          // .dailyTotal | .measurement
    var decimals: Int
    var sortIndex: Int
    var isArchived: Bool
    var group: String       // "" when the tracker isn't grouped
    var modified: Date      // every field but sortIndex
    var orderModified: Date // sortIndex only — see "Mergeable by design"
}

struct Entry: Codable, Identifiable, Hashable {
    let id: UUID
    var trackerID: UUID
    var value: Double
    var date: Date
    var name: String?       // the food, not the tracker
    var batchID: UUID?      // the other entries saved with it
}
```

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
- Day rollover is midnight local. No configurable "my day starts at 4am"
  setting in v1; it's a real want for some people but it multiplies the
  edge cases in every aggregation.
- Tests cover: DST forward and back, year boundaries, time zone travel, and
  entries logged at 23:59:59 and 00:00:00.

## Performance budget

Numbers to hold the design to, measured on the oldest supported device:

- **Cold launch to interactive: under 400ms.** No splash, no async gate before
  the UI draws. Loading the store is a synchronous decode of a small file
  because doing it asynchronously would flash an empty state for longer than
  the decode takes.
- **Tap + to sheet visible: one frame.** The log sheet is trivial and pre-warmed;
  nothing is fetched when it opens. The app adds no presentation animation;
  the numeric keypad's system animation is the remaining wait before typing.
- **Log to dismissed: instant.** Memory is updated synchronously, the sheet
  closes, the disk write happens later and off the main actor.
- **Graph redraw: 60fps while scrubbing** over a year of data. Points are
  aggregated once when the range changes, not per frame.

## Smaller decisions, settled

So they don't get re-argued mid-build:

- **Charts use Swift Charts.** First-party, so it costs no dependency, and it
  handles bars, lines and scrubbing without help. Points are aggregated once
  per range change, never per frame.
- **English only in v1**, but all numbers and dates go through system
  formatters, so they display correctly in any region. Translations are a
  welcome pull request, not a blocker.
- **The day starts at midnight, local.** No configurable day start in v1; it
  multiplies edge cases in every aggregation for a minority want.
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

## Testing

Swift Testing (built in, no dependency). Tests target the parts where a silent
bug destroys data or trust, not UI:

- day-boundary and aggregation math, including the DST and time zone cases
- export → import round trip preserving everything exactly
- schema migration from every past version, once any exist to migrate from —
  today that is only the refusal of any version but the current one, in both
  directions
- decode failure falling back to the backup file
- atomic write leaving a valid file when interrupted

## Project layout

XcodeGen with `project.yml` as the source of truth, and the generated
`.xcodeproj` committed alongside it. That way anyone can clone and open in
Xcode with nothing installed, while configuration changes stay reviewable as
readable YAML instead of pbxproj conflicts.

```
project.yml
BoringTracker/
  App/            entry point, root view
  Model/          Tracker, Entry, StoreDocument
  Store/          Store, persistence, the version guard
  Views/          Home, LogSheet, TrackerDetail, Graph, Settings, editors
  Support/        date math, formatting
BoringTrackerTests/
docs/
```

An App Group is configured from the start, even though widgets come later —
retrofitting one means moving the store file after people have data in it.

## CI

GitHub Actions on a macOS runner: build and run tests on push and PR. Free for
public repos, and it's the only thing standing between a fork and a broken
`main`.
