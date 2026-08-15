# TODO

In implementation order. Short by design — if it's not here, it's either done
or in the "not now" parts of [PRODUCT.md](PRODUCT.md).

The ordering follows one rule: **settle the stored document's shape before the
first App Store release.** That is the freeze point, not daily use on our own
phone. Until then a schema change costs nothing real — delete the app and start
over, or export the JSON and hand-edit it. After it, every change is a migration
over history that belongs to somebody else, and a fresh chance to be wrong about
their data.

## 1. Settings screen and tracker editing — done

Nothing else can be tested without it — the app currently can't create a
tracker, so it's stuck with the two it ships with. `Store` already has `add`,
`update`, `delete`, `deleteWithHistory` and `move`, all tested and unreachable.

Includes the `group` field, since the tracker editor is where you set it.

- [x] Settings, reached from the home screen. One list; the tracker editor is
      the only subscreen, because five fields don't fit in a row.
- [x] Create, edit, archive, and reorder by drag in one flat list. Group
      membership is edited only in the tracker editor.
- [x] Both deletions, labelled apart and explained, in the editor where there
      is room to say which is which.

## 2. Schema changes, all at once — done

One version bump, while there's no data to migrate:

- [x] **`group` on Tracker.** A plain string, not a Group entity — groups
      are display grouping, so there's nothing to manage, no empty groups and
      no orphans. Pick from existing groups or type a new one.
- [x] **`name` on Entry**, replacing `note`. One field, used as the label, and
      the thing search looks at.
- [x] **`batchID` on Entry.** One logged food is two entries — 100 kcal and
      10 g protein — and this is what makes them one thing to edit or delete.
      Optional UUID, free now, a migration later.
- [x] **Delete `Pin`.** Superseded by search-and-repeat (item 12), which needs
      no stored preset at all. Not merely an unused struct — it sits in the
      serialized document with merge and tombstone handling, so removing it is
      a schema change and belongs in this window.

Default groups on first launch: **Food** (Calories, Protein) and **Weight**.

- [x] **`orderModified` on Tracker**, added after review. `sortIndex` is
      rewritten for every row a drag passes, so under one timestamp a reorder on
      one device silently discarded an edit made on another. The field that
      moves without being edited needs its own stamp.

No version bump for that one, and none for the next either: the number is for
recognising a file some *other* build wrote, and while this is a prototype there
is no other build. An older file on a simulator is caught by the decoder on the
first field it is missing, and quarantined. The number starts being maintained
at the first release, which is the same moment the shape freezes.

Schema version 2, and **no migration system, on purpose.** Nothing has been
released, so no v1 file exists outside a development simulator; one left there
is quarantined and started over, exactly as any unreadable file already is.
What stays is the three-line guard that accepts the current version and nothing
else — a *newer* file because it comes from a build that knows more, an *older*
one because no step reads it — rather than misreading either and saving the loss
back over the original. That one matters from the first release, and it is not a
migration system. A step from N to N+1 gets written the day there is a released
version to migrate from, and it takes the older versions with it.

## 3. The group log sheet — done

The core loop, and the reason for all of the above: tap +, land straight in the
last-used group's sheet with the keypad already up. Type 100 and 10,
optionally name it, log. One log, one batch.

**+ must not open a group picker.** Choosing a group is a tap on the common
path, and the common path is the product. Group switching lives inside the
sheet, for the log that isn't the usual one.

Measure the result in taps and milliseconds, not in whether it looks tidy.

- [x] The sheet shows one log group — a group's trackers, or one loose
      tracker on its own — and writes what was typed as a single batch.
- [x] + opens the last-used group straight away, keypad up and the first field
      focused; a card's + opens that card's group, focused on it.
- [x] Switching is the sheet's title — one tap to open, one to switch, and the
      keypad never goes down. Nothing stands in front of the sheet.
- [x] The last-used group lives in `UserDefaults`, not the document: it is UI
      state, so it must not sync, export, or appear in the store file.
- [x] Home is one ordered list of cards, since that is where the sheet is
      launched from: a run of trackers sharing a group gets that heading,
      everything else is a bare card, and nothing is gathered under "Other".

**Two taps and a number** on the common path: + , type, Log. Three from a cold
launch, counting the icon — the target in PRODUCT.md.

## 4. Terminology pass — done

Renamed the old grouping term to **group** everywhere — model, `Store`, views,
tests, docs — and checked `tracker` and `favourite` while in there. The
reasoning is in the Vocabulary part of PRODUCT.md; this item is just the
execution.

Its own session, with a test run: `group` reaches the model, the store, the
tracker editor, the log sheet and the tests, so it is mechanical but wide.

**The rename must not smuggle in an entity.** "Group" sounds more like a noun
than the old term did, and the next reasonable-seeming step is a `Group` type with
an id and an ordering — which is the management screen this app has twice
decided against. It stays a plain string on the tracker. See "Why a group is a
string, not an entity" in TECH.md.

Cheap now, pre-release. Worth doing before step 5 writes the word into a
history screen too.

### And: stop using position to mean membership

The step-3 review found that the two leftovers it was told to skip share one
root, and it is a design problem rather than a code one. **Position on a screen
is currently doing two jobs: order, and which group you belong to.** Because
there is no "drop outside" gesture, membership cannot be read back from
position on a screen that has no *Ungrouped* heading — so settings still needs
the very heading PRODUCT.md forbids, home cannot offer regrouping drags at all,
a settings drag silently reshuffles home, and a loose tracker can never be
placed above the first group.

So separate the two jobs:

- [x] **Settings becomes one flat, reorderable list** of every tracker — a
      single `ForEach`, no headings — with each row showing its group as a
      subtitle. Ordering only.
- [x] **Membership changes only in the editor's group field**, where it already
      works and is typo-proof (None / existing / New…).
- [x] The *No group* heading disappears with nothing to replace it, and no
      drop-target semantics are needed anywhere.
- [x] **Home is unchanged**: still one ordered list drawing a heading above each
      run of trackers that share a group.

This killed the forbidden heading, the drop-target ambiguity and the whole
broken-drag class of bug, at no cost to the common path.

**But it over-corrected, and the claim above was only true for loose
trackers.** Separating ordering from membership was right; also discarding the
*shape* was not. A flat settings list and a home screen that gathers a group at
its first member disagree — see item 6, which keeps the fix and drops the part
that didn't work.

Two loose ends it resolves in passing: `Store.move` gets a production caller
again (the flat list), so it stops being dead code; and `Store.add`'s comment
arguing against slotting a new tracker beside its group is stale — pushing rows
down restamps `orderModified`, which exists precisely so a position change
cannot outrank an edit. Appending still stamps nothing else, because nothing
moved and there is no position to claim.

## 5. Log sheet polish, from first real use — done

Three things that only showed up once the app was on a phone. All small, all on
the common path, and all wanting judgement on the device rather than in a
simulator — so they go in as one focused pass, then get used for a day before
being called done.

- [x] **"Save" becomes "Log".** You are not saving a document, you are recording
      that something happened, and *log* is the verb the whole product already
      uses. Keep **Save** in the entry editor, where you genuinely are saving an
      edit to something that already exists — different action, different word.
- [x] **Kill the presentation animation, or shorten it.** What is left after the
      half-height fix is the standard sheet slide plus the keyboard behind it:
      roughly half a second of watching before you can type, several times a
      day, forever. Measure time-to-typeable before and after, the way the
      step-3 review measured the detent. It is a displayed decision, so if
      instant feels abrupt after a few days, reverting costs nothing.
- [x] **Move the confirm out of the nav bar and into the thumb.** See "Where a
      tap lands matters as much as how many" in PHILOSOPHY.md. The best spot is
      not the bottom of the sheet but **directly above the keyboard**, as a
      keyboard toolbar item: the thumb is already on the number pad, a numeric
      keypad has no return key to submit with, and a bar pinned above the digits
      is the shortest travel there is. Cancel may not need to exist at all —
      a sheet already dismisses by swiping down.

Measured from the first frame showing the press to the first settled frame, on
the iPhone 17 simulator: **1.25 s before, 0.65 s after**. Reproduced from a
clean build in a later session, three runs each: 1.23–1.33 s before,
0.65–0.66 s after. Half a second back, on the one path that runs several times
a day.

The method, since there is no UI test target to point at and the number is only
worth as much as its repeatability: a synthesized tap, `xcrun simctl io
recordVideo`, and a frame-by-frame diff of the recording. The recorder emits a
frame only when the screen changes, so the first frame after the tap is the
press and the last is the screen coming to rest — no frame counting by eye. The
sheet itself now appears in a single frame; what is left is the system keypad
animation, which the app does not own and cannot shorten.

SwiftUI's native `.keyboard` toolbar placement emitted no visible accessory in
this iOS 26 sheet, so the Log action uses a bottom safe-area inset instead. It
sits directly above the keypad, drops to the bottom of the sheet if the keypad
goes down, and lands in the same place on the smallest supported phone.

## 6. Make settings and home agree

Found by the item 4 review. Settings and home can disagree about where a
grouped tracker sits, and a settings drag can be a **visible no-op**: with the
starter set, drag Weight between Calories and Protein and settings shows
Calories, Weight, Protein while home still draws Food(Calories, Protein) then
Weight — identical to before you dragged. Drag Calories to the bottom and it
returns second from top, because home gathers a group at its first member.

A settings screen showing an order home will not honour is lying, and no amount
of care in one screen fixes a disagreement between two.

- [x] **Settings draws the same shape as home** — a heading above each run of
      trackers sharing a group, bare rows for loose ones. The two agree by
      construction, which is the only way they can be relied on to agree.
- [x] **Dragging within a run reorders that group's members; a group moves as a
      unit.**
- [x] **Membership still changes only in the tracker editor.** The *No group*
      heading and drop-target semantics stay gone — that part of item 4 was
      right and is not being reversed.

The two rejected alternatives, so they don't get re-proposed: letting home
follow the flat order means a group can be drawn split under two identical
headings, which one commit already fixed; and accepting the disagreement means
a control that visibly does nothing.

**Settings' drag is hand-rolled, and that is a decision.** A `List` confines a
drag to the `ForEach` it starts in, so a section per run gives within-run
reordering for free but leaves a loose tracker — the common case — unable to
move at all. Reordering therefore uses an explicit handle, a `DragGesture` in
`.global`, and a nearest-row drop, with the moving rows faded and the target
tinted while the finger is down. The review offered a native `.onMove` over one
flat `ForEach`, with group names drawn inside each run's first row instead of
as section headers; it was **declined**, because settings drawing literally the
same shape as home is the whole point of this item. Don't re-propose it, and
don't quietly convert it while working in a neighbouring file.

The feedback is not decoration. The first version drew nothing at all while
dragging, and compared row frames against touch locations resolved in two
different coordinate spaces — so every drop landed on the first row, and the
reproduction that was supposed to prove it worked passed by coincidence,
because in the starter order the wrong target gives the right answer. A drag
that shows what it will do is what makes that class of bug visible in one
screenshot. Known cost, accepted: there is no edge autoscroll, so on a list
longer than the screen a tracker moves a long way in more than one drag.

**A drop candidate is filtered against the list's plain frame, and nothing is
added to it.** The second version of this drag narrowed that band by
`safeAreaInsets.top`, on the reasoning that a `List` runs full height under the
navigation bar and rows behind the bar must not win a drop. Measured on an
iPhone 17, the proxy reports `(0, 116, 402, 724)` with insets of 116 and 34:
the frame is *already* the safe area, so the inset was being counted twice and
the first row — 166 to 210 — fell outside a band starting at 232. Letting go
squarely on the first row dropped the tracker below it instead, and an
accidental nudge that should have moved nothing moved a row and stamped the
whole list's `orderModified`. `DropTargetTests` pins the row-picking rule
against the geometry the device actually reports; the band is one expression in
the view and is still held only by that measurement, so change it by measuring
again rather than by reasoning about where a `List` is laid out.

Not on the common path, so it is judged by correctness rather than taps.

## 7. Put home's + in the thumb

Found by the item 5 review, and it is the same mistake that item caught one
screen earlier. Item 5 moved the log sheet's confirm into the thumb zone, but
**the tap that opens the common path — home's + — is still in the nav bar**, at
roughly 63pt from the top: the least reachable point on the screen, holding the
single most frequent action in the app.

PHILOSOPHY.md's "Where a tap lands matters as much as how many" argues against
exactly this, so the principle was already written down before the button was
built. Worth remembering that stating a rule doesn't apply it.

- [x] Move the primary **+** into the bottom third, in the thumb's arc.
- [x] Check the same question for every other frequent control while there —
      settings is fine in the nav bar (touched weekly), but anything on the
      common path is not.
- [x] Measure it the way item 5 was measured, and record the real method.

The primary action is now a labelled, prominent bottom button whose target
fills the available phone width. A card's small `+` is still attached to that
card and opens its group; the bottom **Log** still opens the last-used group.
Settings stays high because it is rare. Tracker detail's `+` also stays in its
nav bar: detail is an occasional, context-specific alternate path, not the
home → log common path. The sheet's frequent confirm remains directly above
the keypad, where item 5 put it. Home's list, grouping and order did not move.

Measured on clean iOS 26.3 simulators from `xcrun simctl io screenshot`, using
an AppKit pixel scan to find the rendered blue button bounds and divide their
vertical centre by the screenshot height. On the smallest supported phone,
iPhone SE (3rd generation), the centre is **635.5 / 667 pt = 95.28%** from the
top. On the largest phone, iPhone 17 Pro Max, it is **890.7 / 956 pt = 93.17%**.
The project currently also targets iPad; on the largest advertised device,
iPad Pro 13-inch (M5), the regular-width button is constrained and centred at
**1319.5 / 1376 pt = 95.89%**. All three are inside the bottom third.

The dismissal reflow was folded in too. A visible recents row and its values
are snapshotted while saving, so losing focus or inserting the first recent
value cannot reflow the form before it leaves. Verified on the
first-log case with a temporary local UI-test target (created for the run and
removed afterward): it tapped home's **Log**, confirmed the keypad and first
numeric field, typed `123`, and tapped the sheet's **Log** while
`xcrun simctl io recordVideo` recorded the iPhone 17 simulator. Exact 60 Hz
frames extracted with AVAssetImageGenerator show the settled form unchanged
through 13.083 s and the sheet/keyboard dismissal beginning together at
13.100 s. The repository still has no UI-test target.

Review reproduced all three positions from simulators created for the run —
95.31%, 93.18%, 95.91%, against the 95.28 / 93.17 / 95.89 above — and measured
the snapshot against its own counterfactual, which is the more durable number
than a single run's clock. Building the parent revision's `LogSheet` and
driving the identical flow gives **two frames of form motion, a coarse-grid
mean pixel difference of 7.74 then 7.85 over the form region, before the sheet
begins to leave**. With the snapshot in place the same two frames read 0.28 and
0.00. That is the "~2-frame content jump" this item set out to remove, and it
is what earns the two pieces of frozen state their place.

Clearance below the button, which is the thing a 95% position actually risks:
40pt on iPhone 17 Pro Max and 31pt on iPad Pro 13, both clear of the home
indicator and its swipe region. The SE's 6pt is the tightest and the safest —
it has a Home button, so no bottom gesture region exists to collide with.

Two defects in the new code came out of the review and are fixed here. The
`.bar` material was drawn behind only the width-constrained button, so on a
regular-width screen the list scrolled through untinted gutters either side of
it with rows sitting half-clipped at the screen edge; the background now spans
the inset while the button keeps its 440pt cap. And the recents snapshot built
its dictionary with `uniqueKeysWithValues`, which traps: a store file holding
two trackers with the same id loads, draws home and opens the sheet, then
killed the app on the Log button — confirmed by seeding such a file and reading
the crash report. It now uses `uniquingKeysWith`, the form `Store.reorderAll`
already uses, so bad data stays survivable the way the rest of the store layer
intends.

## 8. History screen

Everything logged, newest first, grouped by day — today is just the top of it.
A batch is **one row** ("chicken rice — 100 kcal, 10 g"), deleted or edited
once rather than once per tracker.

Without it, fixing a mistyped food means opening each tracker's detail
separately and deleting a row in each. It's the natural consumer of `batchID`,
and it comes right after the log sheet that starts writing them.

## 9. Export, import, CSV

Rule 6 is unfulfilled until data can leave. `exportData`/`importData` already
exist and are tested; nothing calls them. Import needs an explicit
merge-or-replace choice, since it's the only destructive action in the app.

Deliberately before daily use: it's the escape hatch if anything eats data.

## 10. CI

GitHub Actions build + test on push. Cheap, and the test suite is already good
enough to be worth protecting.

## 11. Use it on a real phone for a week

The step that decides everything after it. Whether logging is genuinely fast,
and what search and pinning should feel like, are not answerable from a
simulator.

## 12. Search and repeat

A search field at the **bottom** of the log sheet, in thumb reach. Empty query
lists your most-used foods by frequency and recency — the common case, with no
typing. Typing filters past entry names. Tapping a result logs it immediately
from that name's latest values, with a brief undo.

This replaces pins, favourites and recents with one control, and it is why
`Pin` was deleted rather than built.

**Treat this whole item as an experiment.** It is settled enough to build, not
settled enough to defend. Every part of it — the ranking, the prefill, what the
empty state lists, whether a tap logs or opens a sheet — is a *displayed*
decision computed from an append-only history (see "Two classes of decision" in
TECH.md), so it can be reworked or thrown away after real use at no cost and
with no migration.

The one thing to watch for during the week: an experiment that needs a fact the
document doesn't record. That's a stored decision, and it's the expensive kind —
flag it early rather than working around it.

## 13. App icon and asset catalog

Neither exists. Needed before TestFlight, not before daily use.

## After v1

- [ ] Home screen widget, Lock Screen widget, App Shortcuts / Siri.
- [ ] Sync transport — the document already merges; this is only plumbing.
- [ ] Apple Watch.
