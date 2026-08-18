# Five years in

What the app actually does with **29,756 entries** — a five-year history, not a
synthetic document. The storage design was chosen on a benchmark of a *file*
(see "Measured, not assumed" in [TECH.md](TECH.md)); nothing had ever run the
app itself at that size. This is that measurement.

**The short version.** Storage is not the problem: the file decodes in 122ms,
merges in 96ms and costs 5MB of memory. Two screens are. **Opening History
freezes the app for 1.5 seconds, and every keystroke in its search field blocks
the main thread for 0.1–0.6s.** Both are the list, not the data — the model work
behind them is 31ms and 40ms. The ceiling claim in TECH.md was wrong about the
app and right about the store, so it now says which.

## The fixture

Deterministic, generated from a seed by a throwaway tool compiled against the
app's own `Model/` and `StoreCoding`, so the file is shaped exactly like one the
app saved. 1,826 days ending today, with the things a real history has:

| | |
|---|---|
| entries | 29,756 (16.3 a day) |
| logs (batches) | 17,679 — meals write three entries, water one |
| named | 17,566 (59%); water, steps, weight and coffee are not named |
| trackers | 10 — 8 daily totals, 2 measurements, 3 of them archived |
| tombstones | 89, of which 64 survive the 180-day compaction |
| shape | four meals and 2–4 waters a day, a morning weigh-in on 76% of days, a smoking habit that stops at 18 months, a pushup phase that lasts four, a cat weighed monthly until she dies, two 13-day holidays with nothing logged, 3.5% of ordinary days missed |
| file | 9,044,537 bytes (8.63 MiB), 304 bytes an entry |

Repeated logs are the point of the shape: "chicken rice" at one portion collapses
to a single Log again row, a bigger portion is its own, and the 17,679 logs
collapse to **1,694** rows.

## How it was measured

- **iPhone 17 Pro simulator, iOS 26.3, on an M4 Pro.** A simulator on a desktop
  is optimistic — TECH.md's own benchmark says treat these as several times
  faster than an old iPhone. Every number below should be read as a floor.
- **Release builds**, with Debug alongside where the existing numbers in TECH.md
  are Debug. Nothing in the app changed: the probe lived in a throwaway
  `git worktree` and is not in this history.
- **The counterfactual is the same build with a 1,028-entry store** (60 days from
  the same generator). Absolute numbers here carry an environment; the pair
  carries the answer.
- **Model-level timings** ran *inside the app*, on the real `Store` loaded from
  the file, five runs each, reported as range and median.
- **Launch** is `kinfo_proc.p_starttime` to the first main-queue turn after
  `HomeView.onAppear`, written to a file by the probe; six plain `simctl launch`
  runs each.
- **UI timings** are frame intervals off a `CADisplayLink` running in the app,
  driven by an XCUITest target in the worktree. A worst frame of 1,527ms means
  the main thread did not come back for 1.5 seconds. XCUITest's own marks are
  inflated by its quiescence waits and are used only to bracket phases, never as
  a duration.
- **Not measured:** a real device, the share sheet and the Files exporter (the
  encode behind them is), and iCloud backup. The Mac's screen was locked for the
  session, so there was no click driver and no accessibility tree; XCUITest
  drives the simulator without either.

## Launch

Six runs, Release, plain `simctl launch`.

| | 1,028 entries | 29,756 entries |
|---|---|---|
| process start → first frame | 488–505 ms | **622–669 ms** |
| of which `Store()` | 15 ms | 149–162 ms |

The budget is 400ms and this environment misses it at both sizes, so the budget
is not what these numbers test — the **delta** is. Five years of data costs
**+135ms**, all of it in the synchronous load: decode 122ms (median of 5,
120–151), sort and index 17ms, `rebuildTotals` 14ms. In Debug the same launch is
637–747ms, and the decode is unchanged at 126ms because it is Foundation's, not
ours.

## Every screen, at 29,756 entries

Release. "Worst frame" is the longest the main thread was blocked; the
counterfactual column is the same measurement at 1,028 entries.

| | model work | worst frame | at 1,028 |
|---|---|---|---|
| Open History | 40 ms | **1,527 ms** | 179 ms |
| History, one search keystroke | 31 ms | **575, 374, 253, 213, 109, 110, 107 ms** | 100, 104, 100, 94, 69, 68, 70 ms |
| History, ten fast flings | none | 33–66 ms | 35–59 ms |
| Open a tracker's detail (chart + list) | 6 ms | **870 ms** | 187 ms |
| Chart → Month | 1.8 ms | 47 ms | 54 ms |
| Chart → Year | 3.3 ms | 305 ms | 71 ms |
| Chart → All (1,826 bars) | 10.0 ms | 287 ms | 73 ms |
| Open the log sheet, to keypad | none | 272 ms | 262 ms |
| Open Log again | 41 ms | 216 ms | 163 ms |
| Log again, one search keystroke | 1.1 ms | — | — |
| Log a number, and the save after it | 1.3 ms | 55 ms | 63 ms |

Read across the last two rows: **the log sheet and logging are exactly as fast
with five years behind them as with two months**, which is what the design
promised — neither touches the entry list. Everything above them is a list or a
chart built from every entry there is.

**History's search rebuilds the list once per keystroke, and only once.** Counted,
not assumed: an `NSLog` in `historyItems` prints 8 times across the whole test —
one for the screen opening and one for each of seven letters — and none for ten
flings. The 31ms is honest; the other 100–545ms is SwiftUI diffing a `List` of
1,825 sections and 17,679 rows against a new one. That is why the first
keystrokes are the expensive ones: they replace the whole list, and by "chick"
there is little left to draw.

**Log again is still one build per open**, which is what TECH.md claims: the
same `NSLog` prints `repeatItems` exactly once — and `historyItems` once, inside
it — for opening the sheet at 29,756 entries.

**Scrolling is fine and getting anywhere is not.** The list holds 60fps with one
or two dropped frames per fling, unchanged at any depth — but 30 fast flings from
today reach 7 July, 41 days back. The far end of a five-year history is about
1,300 flings away.

## Logging, saving, exporting, importing, merging

| | Release | Debug |
|---|---|---|
| `add(values:)`, one log of three trackers | 1.26 ms | 1.35 ms |
| encode the whole document (what a save writes) | 99.7 ms | 106.7 ms |
| atomic write of those 9,051,312 bytes | 1.7 ms | 1.7 ms |
| `StoreFile.write` — backup copy and write | 102.5 ms | 107.9 ms |
| export CSV (4,996,509 bytes) | 33.6 ms | 92.9 ms |
| `merged(with:)`, two different 30k documents | 96 ms | 188 ms |
| `merged(with:)`, the same document again | 52 ms | 104 ms |
| `validateImport` | 2.3 ms | 6.1 ms |
| `importData(.replace)` of its own export | 366 ms | 398 ms |
| `importData(.merge)` of its own export | 410 ms | 499 ms |
| `importData(.merge)` of a *different* 30k document | 664 ms | 819 ms |

The save is the interesting one: **every log rewrites the whole 8.6MB file**, and
that is 100ms of CPU per log — off the main actor, coalesced at 0.5s, and
invisible in the frame trace, which never exceeds 55ms after a log. It is
invisible; it is not free, and on a phone several times slower it is a third of a
second of background CPU every time you log a snack.

A merge is the operation TECH.md never stated a ceiling for. It has one now:
**96ms for the union, 664ms for the whole import** including the flush, the
pre-import backup and the write. Afterwards the store holds 59,444 entries, and
the two expensive screens scale with it — `historyItems` 66ms, `repeatItems`
88ms.

## Memory

Roughly, from `task_vm_info.phys_footprint`:

| | |
|---|---|
| at rest, 1,028 entries | 41–45 MB |
| at rest, 29,756 entries | 43–50 MB |
| after merging in a second five years (59,444) | 83 MB |
| peak across the whole bench run | 151 MB |

The document itself is about **5MB in memory** for 8.6MB on disk. The peak is
what an import costs: two whole documents plus their union, live at once.

## The file, and what identifiers cost

Of 9,044,537 bytes, there are 89,367 UUIDs — three in nearly every entry.

| | bytes | share of the file |
|---|---|---|
| UUID text alone (36 chars each) | 3,217,212 | **35.6%** |
| with their quotes | 3,395,946 | 37.5% |
| the whole `"id"` / `"trackerID"` / `"batchID"` lines, keys and formatting | 5,093,434 | **56.3%** |

Measured, not implemented — what the same document would weigh:

| | file | change |
|---|---|---|
| as it is | 9,044,537 | — |
| 12-character ids | 6,899,729 | −23.7% (−2.0 MiB) |
| `batchID` dropped entirely | 7,318,689 | −19.1% (−1.6 MiB) |
| both | 5,888,025 | −34.9% (−3.0 MiB) |

And what that buys at launch, since launch is the only place the file's size is
felt: the app was run against the `batchID`-free file, and `Store()` took
**137–142ms against 149–162ms** — about 11ms. Scaling the same way, 12-character
ids are worth roughly 15ms. Neither is close to the 1.5s that opening History
costs, so **the file's size is not where this app's problem is**. The argument
for shorter ids is a smaller export and a file that opens in a text editor, not
speed.

## Is `batchID` derivable? No — in both directions

The question is whether the members of one log can be recovered from their
timestamps. Five probe tests against the real `Store` say they cannot:

- **One log does write one instant** to all its members, as designed.
- **Two logs inside one second share that instant.** `Date.stamp()` rounds to
  whole seconds, so an apple and a biscuit logged back to back are one timestamp
  and two batches. Deriving would fuse two meals into one row.
- **Backdating collides without needing to be quick**: the log sheet's date
  picker offers minutes, so anything you set by hand lands on `:00`.
- **Two taps on Log again** in one second are the same collision — three copies
  of a meal, three batches, one timestamp.
- **Editing one member in tracker detail splits a batch's timestamps.** The
  entry editor saves a single entry's date; the batch survives and the clock does
  not. `BatchEditor` already knows this — it asks `Set(entries.map(\.date)).count
  > 1` to decide what to show.

So `batchID` is not redundant with the clock: dropping it would merge unrelated
logs *and* split real ones. If those 1.6 MiB are ever wanted back, the honest
version is a shorter id, not a derived one.

## The ceiling, honestly, again

TECH.md said this design is "comfortable into the low hundreds of thousands of
entries". **At 30,000 — a fifth of the way there — two screens are already
unpleasant on a machine faster than any phone.** The claim was written from a
document benchmark and it measured the right thing about the wrong layer:

- **The store holds.** Decode is linear in the file, so 100,000 entries is
  roughly 400ms at launch, a merge is roughly a third of a second, and the whole
  history costs some 17MB of memory. All of that is fine, and none of it is a
  reason to put SQLite behind the store interface.
- **The screens do not.** `HistoryView` and `TrackerDetailView` build a row per
  entry and a section per day — 17,679 rows and 1,825 sections today — and the
  cost is in the `List`, not in the walk that feeds it. That is what a fix has to
  address: fewer rows on screen at once (a windowed or paged history, a day
  section that draws one summary until it is opened), not a different way to
  store the same numbers.

The honest ceiling for the app as it stands is **somewhere below 30,000 entries
for History and tracker detail, and well above it for everything else.**
