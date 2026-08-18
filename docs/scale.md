# Five years in

What the app actually does with **29,756 entries** — a five-year history, not a
synthetic document. The storage design was chosen on a benchmark of a *file*
(see "Measured, not assumed" in [TECH.md](TECH.md)); nothing had ever run the
app itself at that size. This is that measurement.

**The short version.** Storage was never the problem: the file decodes in
122ms, merges in 96ms and costs 5MB of memory. Two screens were — History and a
tracker's detail — and they had one cause between them. **A `List` builds every
`Section` it is given, and a section costs about 0.8ms whatever is inside it**,
so 1,733 days of history were 1.4 seconds of blocked main thread before a single
row was drawn. The rows were never the problem: all 17,647 of them in *one*
section cost 185ms.

Both screens now draw the same rows in one section, with the day heading as a
row that looks like the header it replaced. **History opens in 321–327ms against
1,517–1,543ms, and its worst keystroke is 235ms against 519ms. A tracker's
detail opens in 363–586ms against 820–1,033ms.** Nothing was removed from either
screen to get there.

Two things are left, and they are honest rather than fixed. **A keystroke costs
90–110ms whatever the store holds** — a 60-day store types at the same speed, so
that floor is `.searchable` and the keyboard, not five years of data. And
**Chart → All still costs 255–262ms**, which is Swift Charts drawing 1,826 bars;
the data behind it is 2.4ms. That one is its own problem and is written up at
the bottom.

## The fixture

Deterministic, generated from a seed by a throwaway tool compiled against the
app's own `Model/` and `StoreCoding`, so the file is shaped exactly like one the
app saved.

**Rebuilt for the fix, because the first generator was thrown away with its
worktree** — so the numbers on this page come from two different fixtures of the
same shape, and the before/after pairs below were all re-measured on the second
one rather than compared across the two. The rebuild lands within 0.1% of the
original: 29,729 entries against 29,756, 17,647 logs against 17,679, 64
surviving tombstones against 64. It reproduces the old numbers too — 1,517ms for
opening History against the 1,527ms first recorded here — with one exception
noted in the chart section. Names are shorter, so the file is 8.34MB rather than
9.04MB and the identifier arithmetic further down is the original's.

1,826 days ending today, with the things a real history has:

| | first fixture | the rebuild |
|---|---|---|
| entries | 29,756 (16.3 a day) | 29,729 (16.3 a day) |
| logs (batches) | 17,679 — meals write three entries, water one | 17,647 |
| named | 17,566 (59%); water, steps, weight and coffee are not named | 17,039 (57%) |
| trackers | 10 — 8 daily totals, 2 measurements, 3 of them archived | the same 10 |
| tombstones | 89, of which 64 survive the 180-day compaction | 89, of which 64 |
| file | 9,044,537 bytes (8.63 MiB), 304 bytes an entry | 8,335,014 (7.95 MiB), 280 |

The shape, in both: four meals and 2–4 waters a day, a morning weigh-in on 76%
of days, a smoking habit that stops at 18 months, a pushup phase that lasts
four, a cat weighed monthly until she dies, two 13-day holidays with nothing
logged, 3.5% of ordinary days missed.

Repeated logs are the point of the shape: "chicken rice" at one portion collapses
to a single Log again row, a bigger portion is its own, and the 17,679 logs
collapse to **1,694** rows.

## How it was measured

- **iPhone 17 Pro simulator, iOS 26.3, on an M4 Pro.** A simulator on a desktop
  is optimistic — TECH.md's own benchmark says treat these as several times
  faster than an old iPhone. Every number below should be read as a floor.
- **Release builds**, with Debug alongside where the existing numbers in TECH.md
  are Debug. Nothing in the app changed: the probe lived in a throwaway
  `git worktree` and is not in this history. It was rebuilt for the fix, from
  the same description, and the before column was re-measured with it rather
  than quoted from the first pass — the two agree to within 1% on opening
  History, which is the check that the rebuilt harness measures the same thing.
- **The counterfactual is the same build with a 1,028-entry store** (60 days from
  the same generator; 1,010 in the rebuild). Absolute numbers here carry an
  environment; the pair carries the answer. It earns its keep twice over below,
  where it shows that the per-keystroke cost that looked like a data problem is
  the same at two months.
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

**This misses the budget and the budget has not been changed to suit it.** 400ms
is the number TECH.md holds the design to and this environment is over it at
*both* sizes, five years or two months, so what these runs establish is the
delta and not a verdict. Either the budget is wrong for a simulator on a desktop
or the launch is genuinely too slow; deciding which needs a real device, and it
is not decided here. It is the one measurement on this page that is still
waiting for someone.

## Every screen, at 29,756 entries

Release. "Worst frame" is the longest the main thread was blocked; the
counterfactual column is the same measurement at 1,028 entries. These are the
original fixture's numbers, before the section fix.

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

### The same screens after the fix

Three runs of each on the rebuilt fixture, 29,729 entries, Release, same
`CADisplayLink` and the same XCUITest script driving both columns. The
counterfactual is the fixed build against 1,010 entries.

| | before | after | after, at 1,010 |
|---|---|---|---|
| Open History | 1,517–1,543 ms | **321–327 ms** | 162 ms |
| History, seven search keystrokes | 505–519, 231–233, 142–148, 106, 84–102, 93–102, 90–101 ms | **235–237, 115–122, 100–104, 95–101, 80–93, 93–100, 92–106 ms** | 112, 95, 103, 93, 116, 94, 90 ms |
| Tap into the search field | 204–207 ms | 200–224 ms | 190 ms |
| Open a tracker's detail | 820–1,033 ms | **363–586 ms** | 168 ms |
| Chart → Month | 40–46 ms | 44–45 ms | 37 ms |
| Chart → Year | 74–89 ms | 75–90 ms | 64 ms |
| Chart → All (1,826 bars) | 255–262 ms | 255–258 ms | 62 ms |

The first run of each three is the slow one on the detail screen — 1,033 and 586
against 820/823 and 363/369 — and it is the run straight after an install, on
both columns, so it is a cold Swift Charts rather than anything in the diff.

**Read the last column first.** After the fix, every keystroke at five years
costs what a keystroke costs at two months, and so does opening the search
field. That was already true of the tail before the fix and is now true of the
whole series. What is left is a per-keystroke floor of **90–110ms that has
nothing to do with the store** — `.searchable`, the keyboard and one `List`
diff — and no amount of work on the data will move it.

**Chart → All did not move, and was not expected to.** It is the one number on
this page that scales with the data and is not a `Section`: 255–262ms to draw
1,826 bars, against 62ms for 60. The data behind it is 2.4ms, measured inside
`TrackerChart.recompute`. See "The chart is its own problem" below.

Read across the last two rows: **the log sheet and logging are exactly as fast
with five years behind them as with two months**, which is what the design
promised — neither touches the entry list. Everything above them is a list or a
chart built from every entry there is.

**History's search rebuilds the list once per keystroke, and only once.** Counted,
not assumed: an `NSLog` in `historyItems` prints 8 times across the whole test —
one for the screen opening and one for each of seven letters — and none for ten
flings. The 31ms is honest; the other 100–545ms is SwiftUI, and the sentence
that used to be here guessed *which* SwiftUI. It said the cost was diffing 1,733
sections and 17,679 rows against a new one. Half right: it was the sections
alone, and the rows were nearly free.

## It was the sections, and only the sections

Four builds at 29,729 entries, one variable each, everything else identical.
Every one of them draws the whole history — none of them shows less.

| | sections | rows | opening History |
|---|---|---|---|
| as shipped | 1,733 | 17,647 full rows | **1,646 ms** |
| one section, the same full rows | 1 | 17,647 | **185 ms** |
| every section, one trivial `Text` each | 1,733 | 1,733 | **1,375 ms** |
| every section, all rows trivial `Text` | 1,733 | 17,647 | **1,434 ms** |
| one section, plus a heading row per day | 1 | 19,380 | **261 ms** |

Read the second and third rows against each other: **17,647 real rows in one
section cost 185ms, and 1,733 sections holding one `Text` apiece cost 1,375ms.**
That is about **0.8ms per `Section`**, paid whatever the section contains, and it
is the whole of the freeze. Two more builds took the header away and moved to
`.listStyle(.plain)`; they came in at 1,379ms and 1,481ms, so it is not the
header and not the style either.

Where it goes is not in app code. Timing buckets inside the shipped build
account for only 69ms of the 1,646: `historyItems` and the grouping 36ms, the
1,733 day labels 24ms — a date format per section header, which was the first
suspect and is not the answer — and the row bodies and their repeat discs 10ms
between them. The rows are also genuinely lazy: 1,745 row bodies were built for
17,647 rows, one per section, while every section header was built twice.

**The fix is therefore one section and a day heading that is a row.** Both
screens keep every row, newest first, grouped by day, with tap to edit, swipe to
delete, search, repeat and the undo bar; a throwaway XCUITest exercises each of
those against the new structure at 29,729 entries.

**What it costs is the card per day.** `.insetGrouped` draws one rounded card per
section, so one section is one card: the day heading is still a heading — same
`.headline` in `.secondary`, matched against a real section header in a probe
build, and still `.isHeader` to VoiceOver — and the gap between days is still
there, but the white block behind each day no longer has rounded corners. It is
not recoverable without either the sections or a hand-drawn corner radius that
would have to be re-measured every time iOS restyles a list.

**It is not the only visible difference, and the sentence that used to say so
was corrected on measurement — see "What the review measured" below.** The
heading's `listRowInsets(top: 18, …)` is paid *on top of* the spacing a
headerless `Section` already reserves rather than instead of it, so History also
gained a band of empty space it did not have: **3.0% more list, about 17 points
a day, and the first heading roughly 47 points further down the screen you
arrive on.** It is left as it is, deliberately: it is spacing rather than
structure, and what the right gap between two days looks like now that there is
no card is nobody's decision yet. But it is not nothing — this is a list whose
whole problem was that it is 1,733 days long.

**Two smaller things on the detail screen, found on the way.** Its `days` was a
computed property asked **three** questions per redraw — the chart's guard, the
empty state's, and the `ForEach` — so one tracker's entries were walked, grouped
and sorted three times. Counted rather than estimated, with a counter in the
property itself: **three reads costing 31.3–31.7ms, against one costing
12.0–13.0ms after**. The "four questions … 35ms where one walk is 9ms" first
recorded here had the shape right and both numbers a little wrong. And
`.accessibilityElement(children: .combine)` on the new day heading cost **180ms
of 400**, because combining children is not lazy the way a row body is: all
1,733 headings resolve their children whether or not they are on screen. It was
dropped, which is what the section header it replaced did anyway.

**Log again is still one build per open**, which is what TECH.md claims: the
same `NSLog` prints `repeatItems` exactly once — and `historyItems` once, inside
it — for opening the sheet at 29,756 entries.

**Scrolling is fine and getting anywhere is not.** The list holds 60fps with one
or two dropped frames per fling, unchanged at any depth — but 30 fast flings from
today reach 7 July, 41 days back. The far end of a five-year history is about
1,300 flings away.

### What the review measured

The fix was reviewed in a fresh session that did not trust this page, and the
numbers above were reproduced from scratch rather than read. **A third fixture**,
generated from this page's description by a third throwaway tool, so it is
independent of the two the fix was built on: 29,320 entries, 17,272 logs, 1,726
days with something in them, 8,285,677 bytes. The probe is not XCUITest and
needs no clicker — a `CADisplayLink` in the app, and a launch argument that
pushes the screen programmatically once the app has settled, so it runs against
a locked Mac. Release, iPhone 17 Pro simulator, three runs each, worst frame:

| | before | after |
|---|---|---|
| open History | 1,186–1,191 ms | **210–214 ms** |
| open a tracker's detail | 458–676 ms | **237–267 ms** |
| sections in History's `List` | 1,726 | **1** |
| items in it | 17,272 | **18,999** |
| content height | 958,965 pt | 988,067 pt |
| reads of detail's `days` per open | 3, costing 31.3–31.7 ms | **1, costing 12.0–13.0 ms** |

Lower absolute numbers than the columns above and the same shape: **5.6× on
History against the 4.7× recorded here, on a fixture 1.4% smaller and a probe
that does not carry XCUITest's overhead.** The per-section cost implied by the
pair is 0.57ms rather than 0.8ms, which is the same finding at a different
machine's speed — 1,725 sections went away, 1,726 heading rows and one hint row
arrived in their place, and 978ms of blocked main thread went with the sections.

**Nothing is hidden, counted rather than assumed.** 18,999 items is exactly
17,272 rows + 1,726 headings + one hint, and the collection view scrolls to item
18,998 — the oldest day in the fixture, drawn with its heading. The pre-fix build
reaches its own last row the same way. A second, hand-made fixture put the awkward
days on screen: a day with one entry, a day with twenty, a day with nothing, the
first day, the last day, and a batch written either side of midnight — which is
drawn once, under its newest member's day, exactly as item 23 settled. Read off
the live accessibility tree, every day with entries has one heading and every
heading carries the header trait; the day with nothing has none.

**One thing the review found rather than confirmed.** Tracker detail's heading
put `.accessibilityAddTraits(.isHeader)` on the `HStack`, and a trait set on a
container reaches every child, so the day's *total* became a heading too — the
same tree read as `Today`, `250 kcal`, `Sun, Aug 16`, `5,550 kcal`, which is
3,466 rotor stops for 1,733 days, half of them bare numbers. The same read of
the section header it replaced shows that header marking its label and leaving
its total alone. The trait moved onto the label, which restores it at no cost;
detail still opens in 257–306ms. History's heading is a single `Text` and was
never affected — the two hand-drawn copies of one heading had come apart, which
is the thing this app usually spends a shared component to avoid.

**Not verified here, and taken on trust:** the keystroke timings, the four
single-variable builds behind the 0.8ms figure, and swipe-to-delete and
tap-to-edit as *gestures* — the Mac's screen was locked, so there was no way to
touch the screen. The controls themselves were read off the accessibility tree
on the first and last rows of the list, where they are still a button apiece.

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

## The chart is its own problem

Chart → All is the one thing on this page that scales with the data and is not a
`Section`, so the section fix did nothing for it and was not expected to:
**255–262ms to draw 1,826 bars, against 62ms for 60 days of them.** The work
behind it is 2.4ms — `TrackerChart.recompute` already aggregates once per range
change and holds the points in `@State`, which is what TECH.md's "graph redraw"
budget asked for and it is doing its job. The rest is Swift Charts laying out
1,826 `BarMark`s.

It is left alone deliberately. The obvious cure is to draw fewer bars — bucket
the "All" range by week or by month above some length — and that is a different
decision from this one: it changes what the chart *says*, where everything above
only changed how the same rows are put into a list. It wants its own item, its
own before-and-after, and someone deciding whether a five-year chart of weekly
bars is the better chart anyway. Note also that it is a range you have to ask
for by tapping "All", not something every visit to the screen pays.

Chart → Year was 305ms in the first fixture and is 74–89ms in the rebuild. That
is the one number the rebuilt fixture does not reproduce, and the likely reason
is the shape of what Calories holds rather than the code — worth knowing before
anyone treats the 305ms as a regression that was fixed here, because nothing in
this change touches it.

## The ceiling, honestly, again

TECH.md said this design is "comfortable into the low hundreds of thousands of
entries". **At 30,000 — a fifth of the way there — two screens were already
unpleasant on a machine faster than any phone.** The claim was written from a
document benchmark and it measured the right thing about the wrong layer:

- **The store holds.** Decode is linear in the file, so 100,000 entries is
  roughly 400ms at launch, a merge is roughly a third of a second, and the whole
  history costs some 17MB of memory. All of that is fine, and none of it is a
  reason to put SQLite behind the store interface.
- **The screens did not, and the reason was one line of structure.** `HistoryView`
  and `TrackerDetailView` built a section per day, and a `List` pays for every
  section it is handed. One section each, with the day heading as a row, takes
  History from 1.5s to a third of a second and detail from a second to under
  four tenths — while still drawing every row there is. The earlier conclusion
  here, that the fix had to be "fewer rows on screen at once", was wrong twice:
  the rows were not the cost, and showing fewer of them would have been the one
  thing this screen may not do.

**What the ceiling is now.** Both screens are linear in rows and no longer in
days, so 100,000 entries would be roughly three times the 321ms History costs
today — about a second, and unpleasant again, but reached at fifteen years of
this use rather than five. Nothing else on the common path grows at all. The
honest statement is that the app is **comfortable at 30,000 entries and the next
thing to give way is the same `List`, at a size no one on this design will
reach** — and if someone does, the answer will be the same shape as this one:
find what the list is being charged for, not how much data there is.
