# Five years in

What the app does with **29,756 entries** — five years of real use, not a
synthetic document. The storage design was chosen on a benchmark of a *file*
(see "Measured, not assumed" in [TECH.md](TECH.md)); this is the app itself
measured at that size.

**The short version.** Storage was never the problem: the file decodes in 122ms,
merges in 96ms and costs 5MB of memory. Two screens were — History and a
tracker's detail — and they had one cause between them. **A `List` builds every
`Section` it is given, and a section costs about 0.8ms whatever is inside it**,
so 1,733 days of history were 1.4 seconds of blocked main thread before a single
row was drawn; all 17,647 rows in *one* section cost 185ms. Both screens now
draw the same rows in one section with the day heading as a row, and nothing was
removed from either to get there.

Two things are left, and they are honest rather than fixed. **A search keystroke
costs 90–110ms whatever the store holds** — a 60-day store types at the same
speed, so that floor is `.searchable` and the keyboard, not five years of data.
And **Chart → All costs 255–262ms**, which is Swift Charts drawing 1,826 bars;
the data behind it is 2.4ms.

## The fixture, and how it was measured

Deterministic, generated from a seed by a throwaway tool compiled against the
app's own `Model/` and `StoreCoding`, so the file is shaped exactly like one the
app saved. 1,826 days ending today: **29,756 entries** in **17,679 logs** across
**1,733 days** with anything in them, 59% of them named, ten trackers of which
three are archived, 89 tombstones with 64 surviving compaction, and a
**9,044,537-byte** file at 304 bytes an entry. The shape is four meals and 2–4
waters a day, a weigh-in on 76% of days, a smoking habit that stops at 18 months,
a pushup phase that lasts four, a cat weighed monthly until she dies, two 13-day
holidays and 3.5% of ordinary days missed. Repeated logs are the point of it:
17,679 logs collapse to **1,694** Log again rows.

**iPhone 17 Pro and Pro Max simulators, iOS 26.3, on an M4 Pro, Release.** A
simulator on a desktop is optimistic — treat every number here as a floor. UI
timings are frame intervals off a `CADisplayLink` running inside the app, driven
by a throwaway XCUITest or by a launch argument that pushes the screen; a worst
frame of 1,527ms means the main thread did not come back for 1.5 seconds. Model
timings ran inside the app on the real `Store`, five runs each. **The
counterfactual is the same build against a 1,028-entry store** — 60 days from the
same generator — because absolute numbers carry an environment and the pair
carries the answer. Not measured: a real device, the share sheet, iCloud backup.

**These are dated measurements**, taken 2026-08-17 to 2026-08-21 across five
independently generated fixtures that agree to within a few percent. The
generators and probe builds were throwaways in `git worktree`s and are not in
this history, so reproducing any of it starts by regenerating a 30,000-entry
fixture. Read the deltas as the finding, the milliseconds as one machine's.

## Launch

| six runs, `simctl launch` | 1,028 entries | 29,756 entries |
|---|---|---|
| process start → first frame | 488–505 ms | **622–669 ms** |
| of which `Store()` | 15 ms | 149–162 ms |

Five years of data costs **+135ms**, all of it in the synchronous load: decode
122ms (median of 5, 120–151), sort and index 17ms, `rebuildTotals` 14ms. Debug
is 637–747ms with the decode unchanged, because that part is Foundation's and
not ours. **This environment misses TECH.md's 400ms budget at *both* sizes**, so
these runs establish the delta and not a verdict: either the budget is wrong for
a simulator on a desktop or the launch is genuinely too slow, and deciding needs
a real device.

## Every screen

Worst frame, Release, three runs each. "Before" is the section-per-day build
these screens used to be; the last column is the shipping build at 1,010 entries.

| | before | now | at 1,010 |
|---|---|---|---|
| Open History | 1,517–1,543 ms | **321–327 ms** | 162 ms |
| History, worst search keystroke | 505–519 ms | **235–237 ms** | 112 ms |
| History, the six keystrokes after it | 231–233 down to 90–101 ms | 115–122 down to 92–106 ms | 95 down to 90 ms |
| Tap into the search field | 204–207 ms | 200–224 ms | 190 ms |
| Open a tracker's detail | 820–1,033 ms | **363–586 ms** | 168 ms |
| Chart → Month | 40–46 ms | 44–45 ms | 37 ms |
| Chart → Year | 74–89 ms | 75–90 ms | 64 ms |
| Chart → All (1,826 bars) | 255–262 ms | 255–258 ms | 62 ms |
| Open the log sheet, to keypad | 272 ms | 272 ms | 262 ms |
| Open Log again | 216 ms | 216 ms | 163 ms |
| Log a number, and the save after it | 55 ms | 55 ms | 63 ms |

**Read the last column first.** Every keystroke at five years now costs what a
keystroke costs at two months, and so does opening the search field; what is left
is a floor of 90–110ms that has nothing to do with the store. **Then read the
last three rows:** the log sheet and logging are exactly as fast with five years
behind them as with two months, because neither touches the entry list.
Everything above them is a list or a chart built from every entry there is.
Scrolling holds 60fps at any depth, but 30 fast flings reach only 41 days back,
so the far end of this history is about 1,300 flings away.

## It was the sections, and only the sections

Four builds at 29,729 entries, one variable each, everything else identical.
Every one of them draws the whole history — none of them shows less.

| | sections | rows | opening History |
|---|---|---|---|
| section per day, full rows | 1,733 | 17,647 | **1,646 ms** |
| one section, the same full rows | 1 | 17,647 | **185 ms** |
| every section, one trivial `Text` each | 1,733 | 1,733 | **1,375 ms** |
| every section, all rows trivial `Text` | 1,733 | 17,647 | **1,434 ms** |
| one section, plus a heading row per day | 1 | 19,380 | **261 ms** |

Read the second and third rows against each other: **17,647 real rows in one
section cost 185ms, and 1,733 sections holding one `Text` apiece cost 1,375ms.**
That is about **0.8ms per `Section`**, paid whatever the section contains, and it
is the whole of the freeze. It is not the header and not the list style —
removing the header and moving to `.listStyle(.plain)` came in at 1,379 and
1,481ms. Nor is it app code: timing buckets account for only 69ms of the 1,646,
of which the 1,733 day labels are 24ms, and the rows are genuinely lazy at 1,745
bodies built for 17,647 rows. An independent session reproduced the finding on a
fixture, probe and harness of its own — 1,186–1,191ms against **210–214ms**,
implying 0.57ms a section on that machine.

**What the fix costs is the card per day.** `.insetGrouped` draws one rounded
card per section, so one section is one card: the day heading is still a heading
and still `.isHeader` to VoiceOver, and the gap between days survives, but the
block behind each day no longer has rounded corners. History also gained **3.0%
more list, about 17 points a day**, because the heading's `listRowInsets` is paid
on top of the spacing a headerless `Section` already reserves rather than instead
of it. Left as it is deliberately: spacing rather than structure.

Tracker detail gave up two smaller things on the way. Its `days` was a computed
property asked **three** questions per redraw — the chart's guard, the empty
state's, and the `ForEach` — costing 31.3–31.7ms between them against 12.0–13.0ms
for the one read it does now. And `.accessibilityElement(children: .combine)` on
the new day heading cost **180ms of 400**; see TECH.md for why.

**History's jump control did not put any of it back.** The nav-bar date picker
costs 2% to 8% of the open — +6 to +36ms on ~360ms, across batches that disagree
by more than half of that, because a long session of Xcode builds moves this
machine more than the change does. It is not the day identities: a build with
`.id(group.day)` taken back off has the same median. A *jump* costs 331–354ms,
half of it `HistoryView.body` re-evaluating — 178ms to regroup `historyItems` and
re-diff every row for a state change that cannot alter one of them. If a jump
ever needs to be cheap, caching the grouping is the half to take. Landing is
nearest-day, driven rather than reasoned: inside a fourteen-day hole the 15th
lands on the 10th and both the 18th and the 22nd on the 25th, and a date nine
years before anything was logged lands on the oldest day rather than doing
nothing. And the picker **is not immune to Dynamic Type**, though its fixed
320-point frame is safe anyway — photographed at five sizes the title grows from
42 to 69 screenshot pixels of glyph height and the weekday row relabels itself
from `SUN MON TUE` to `S M T`, while the day grid stays **289–306 points wide**
at every size and nothing clips at AX5.

## Writing, exporting, importing, merging

Model-level, Release, on the real `Store` loaded from the file; Debug runs
1.1–2.8× slower throughout. One log of three trackers is **1.26ms**. Encoding the
whole document — what every save writes — is **99.7ms**, the atomic write of
those 8.6MB is 1.7ms, and CSV export is 33.6ms. `validateImport` is 2.3ms, a
replacing import of the app's own export **366ms**, a merging one 410ms, and a
merge of a *different* 30k document **664ms**, of which the union itself is
**96ms**. That last is the ceiling TECH.md never stated for a merge; afterwards
the store holds 59,444 entries and the two expensive screens scale with it, at
`historyItems` 66ms and `repeatItems` 88ms.

The save is the interesting one: **every log rewrites the whole 8.6MB file**, and
that is 100ms of CPU per log — off the main actor, coalesced at 0.5s, and
invisible in the frame trace, which never exceeds 55ms after a log. It is
invisible; it is not free, and on a phone several times slower it is a third of a
second of background CPU every time you log a snack.

**Memory**, from `task_vm_info.phys_footprint`: 43–50MB at rest against 41–45MB
with 1,028 entries, 83MB after merging in a second five years, 151MB peak across
the bench run. The document is about **5MB in memory** for 8.6MB on disk; the
peak is what an import costs, two whole documents plus their union live at once.

**The file's size is not where the problem is.** Of 9,044,537 bytes, 89,367 UUIDs
are 35.6% as text and 56.3% once their keys and formatting count — but run
against a `batchID`-free file, `Store()` took 137–142ms against 149–162ms. About
11ms. The argument for shorter ids is a smaller export and a file that opens in a
text editor, not speed.

## The ceiling, honestly

TECH.md used to say this design is "comfortable into the low hundreds of
thousands of entries". **At 30,000 — a fifth of the way there — two screens were
already unpleasant on a machine faster than any phone.** The claim was written
from a document benchmark and it measured the right thing about the wrong layer.
**The store holds:** decode is linear in the file, so 100,000 entries is roughly
400ms at launch, a merge roughly a third of a second, and the whole history some
17MB of memory — none of it a reason to put SQLite behind the store interface.
**The screens did not, and the reason was one line of structure.** The earlier
conclusion here, that the fix had to be "fewer rows on screen at once", was wrong
twice: the rows were not the cost, and showing fewer of them would have been the
one thing this screen may not do.

**One thing still scales with the data and is not a `List`.** Chart → All draws
1,826 `BarMark`s in 255–262ms against 62ms for 60 of them, where the work behind
it is 2.4ms — `TrackerChart.recompute` aggregates once per range change and holds
the points in `@State`, which is what TECH.md's "graph redraw" budget asked for.
The rest is Swift Charts laying them out. Left alone deliberately: the cure is to
draw fewer bars, bucketing "All" by week or month above some length, and that
changes what the chart *says* where everything above only changed how the same
rows go into a list. It also takes a tap on "All" to reach, so it is on nobody's
common path.

**What the ceiling is now.** Both screens are linear in rows and no longer in
days, so 100,000 entries would be roughly three times the 321ms History costs
today — about a second, and unpleasant again, but reached at fifteen years of
this use rather than five. Nothing else on the common path grows at all. The
honest statement is that the app is **comfortable at 30,000 entries and the next
thing to give way is the same `List`, at a size no one on this design will
reach** — and if someone does, the answer will be the same shape as this one:
find what the list is being charged for, not how much data there is.
