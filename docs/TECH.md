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
    var kind: Kind          // .dailyTotal | .measurement
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

`Entry.modified` is not decoration and this listing used to omit it: "`modified`
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

Numbers to hold the design to, measured on the oldest supported device:

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
not by hue**: home's copy stays secondary because it is a 30pt disc with no word
against a full-width pill.

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
  Store/          Store, persistence, the version guard
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
