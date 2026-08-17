# TODO

Numbers are stable once assigned — commit messages refer to them, so a gap
means an item was merged into another one, not that something was lost. Item 8
is now part of item 17.

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
- [x] **Delete `Pin`.** Superseded by search-and-repeat (item 16), which needs
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

## 9. History screen — done

Everything logged, newest first, grouped by day — today is just the top of it.
A batch is **one row** ("chicken rice — 100 kcal, 10 g"), deleted or edited
once rather than once per tracker.

Without it, fixing a mistyped food means opening each tracker's detail
separately and deleting a row in each. It's the natural consumer of `batchID`,
and it comes right after the log sheet that starts writing them.

## 10. Export, import, CSV — done

Rule 6 is unfulfilled until data can leave. `exportData`/`importData` already
exist and are tested; nothing calls them. Import needs an explicit
merge-or-replace choice, since it's the only destructive action in the app.

Deliberately before daily use: it's the escape hatch if anything eats data.

## 11. Home density and log feel, from real use — done

Five things noticed with four trackers on a real phone. Four are now; the
animation on save is later.

- [x] **Home cards are too big.** Four trackers should not fill a screen —
      aim for **6–10 visible without scrolling** on a current iPhone. Shrink
      the cards, not the numbers: "legible at a glance with one hand at the
      fridge" still holds.
- [x] **A card's + is too subtle and too small**, and it reads as a different
      design language from the bottom Log button. Give it a real 44pt target
      and the same idiom as Log, smaller. Tapping the card itself still opens
      that tracker's detail.
- [x] **Remove the recent-value bubbles from the log sheet.** People don't log
      the same number twice — they log the same *food*, which is what item 16
      is for. `Store.recentValues` was kept on the grounds that
      search-and-repeat would want it — **that reasoning looks wrong**: it keys
      on tracker UUID and ignores names entirely, which is the opposite of what
      item 14 needs. Decide when building item 16 whether to rewrite it around
      names or delete it; do not keep it out of habit.
- [x] **Move between fields without leaving the keypad.** Typing calories then
      reaching for protein costs a tap on the field; put previous/next chevrons
      in the keyboard bar beside Log.
- [x] **Make the sheet and the keyboard move together** — tried, measured, and
      **not done**, because the two cannot be made to overlap from here.

      This refines item 5 rather than reversing it. The rule is *nothing you
      have to wait for*, and a move that finishes exactly when the keypad does
      costs nothing extra — but **time-to-typeable must not increase**, so
      measure it before and after the way item 5 was measured.

      It increases it, by a lot. iOS will not raise the keyboard while a modal
      presentation animation is in flight, so the sheet's duration is *added* to
      the wait rather than hidden inside it: the keypad starts ~0.22s after the
      sheet is presented no matter what the sheet did to get there. Instant is
      one ramp at **0.713–0.823s**; animated over the keyboard's own measured
      0.3833s is two ramps with a stall between them at **1.270–1.278s**. Same
      two movements, further apart, for half a second more. The instant sheet
      stays.

      **The complaint is still true and is now a known design problem**: two
      things do arrive at two moments and it does read as a glitch. Anything
      that fixes it has to start the keypad and the sheet in the same instant,
      which means owning the presentation instead of asking `.sheet` for it.
      That is a much larger change than this item was scoped for, and it wants
      the week of real use in item 13 to say whether it is worth it.

Measured on the iPhone 17 simulator with the item 5 method — a synthesized tap,
`xcrun simctl io recordVideo`, and a frame-by-frame diff, first frame showing
the press to the last frame above the noise floor, three runs. Time-to-typeable
finished at **0.697–0.710s**, marginally under the 0.713–0.823s it started at:
nothing here was allowed to cost the common path anything, and removing the
recents row gave a little back.

Cards visible without scrolling, counting a card as visible when its number and
its + are entirely above the Log bar, against a 12-tracker file with two groups:
**4 → 10** on the largest phone (iPhone 17 Pro Max), **4 → 8** on the iPhone 17,
**3 → 6** on the smallest supported phone (iPhone SE 3rd generation). Read out
of the accessibility tree rather than counted by eye — the simulator reports iOS
element frames in device points, so the numbers above are the frames the app
actually laid out.

The row went from 118pt to 64pt without shrinking anything that matters: the
name and the number moved onto one line instead of stacking, and most of what
was reclaimed was never the card at all — the default inset-grouped row padding
was 46pt, and because every loose tracker is its own section, the gap *between*
sections was being paid once per card. The number is `.title2` rather than
`.largeTitle`, which is the largest size that fits beside a 44pt button without
making the row taller than that button already makes it.

**The + was already a 44pt target** — that part of the complaint was wrong, and
worth recording so the next person does not go looking for the bug. What was
actually wrong was contrast and idiom: a bare blue glyph floating in the row,
which is a different design language from the filled blue pill it is a smaller
version of. It is now a 30pt filled circle in the same tint, still inside a 44pt
frame, with `contentShape` keeping the target the frame rather than the fill.

Left open by item 11, worth revisiting: **settings is now visibly less dense
than home.** They still agree on order and shape, which is what item 6 required,
but they no longer look alike.

And the sheet still cannot move as one with the keyboard: iOS will not raise the
keypad while a modal presentation is animating, so it starts ~0.22s late
regardless, and matching the two produced a visible stall costing half a second.
The instant sheet stays. If this keeps grating, the answer is not a different
duration — it is not using `.sheet`.

**Item 12 answered it without that.** The constraint binds only while a keyboard
is being raised, and the pad is now drawn instead. `.sheet` stayed.


## 12. Draw our own number pad — tried, reverted

Built, measured, used on a phone, and reverted. **The code is `6bf00f7`** and
the revert is the commit after it; `6bf00f7` applies cleanly on its own if this
is ever revisited.

**It worked.** Press-to-settled went from ~0.70s to ~0.21s, with the 0.513s
keypad ramp gone entirely — the frame the sheet first appears in already holds
the pad, the caret and the Log bar. The method and the numbers are in the
commit body, including the check that the before-figure reproduces item 11's
independently recorded one.

**It was reverted anyway.** Half a second per log did not turn out to be worth
owning a keyboard, and what ownership costs is permanent and grows: dictation,
paste, hardware keyboards, and every accessibility affordance reimplemented by
hand and kept working across iOS releases. The system keypad reads as fine now
that item 11 removed the sheet's own animation — which was most of what made
the delay noticeable to begin with.

Worth revisiting only if something changes the trade: a Watch app, where a
custom pad may be the only sensible input; or the system keypad becoming the
dominant cost again after other work. Not on taste alone — the number is known
now, and it is half a second.

## 13. Make it look like one app — done

Four things spotted while using it. All the same kind of problem — a screen
saying the same thing two different ways — and all on screens looked at daily.

- [x] **A tracker's name on home is grey and hard to read.** Give it the same
      white as its number. Grey says "secondary", and the name is not
      secondary — it is what tells you which number you are looking at.
- [x] **The "Boring Tracker" title only exists at the top of the scroll.**
      Keep it visible always, smaller — a title that appears and disappears
      makes the screen feel like it is changing when only the scroll offset is.
- [x] **Replace the blue with a teal.** Use a **SwiftUI system colour**
      (`.teal`, or `.mint` if it reads too blue) rather than a custom hex: the
      system ones are dynamic, so they desaturate themselves for dark mode.
      That matters here — a colour tuned on white goes neon on black, which is
      the usual way a custom accent looks wrong in the mode we care about most.
      Judge it in dark mode first, since that is where this app is actually
      used, and check the disabled and pressed states too.
- [x] **In History, a named entry is drawn differently from an unnamed one**,
      so the macros shift shape depending on whether you typed a name. Make the
      row uniform and let the **name** be the grey, quieter part. The numbers
      are the thing every row has, so they should be what every row shows the
      same way.

The inline title **gains** a card rather than costing one: on an iPhone 17 with
twelve trackers, 9 cards were fully visible above the Log bar with the large
title and **10** are with the inline one, measured off the accessibility tree's
row frames rather than counted by eye. It is also what History, Settings and
every editor already do, so the app now has one title treatment.

Reproduced in review against a different twelve-tracker fixture (two groups,
eight loose trackers): **the list starts 52pt higher — the large title's whole
band — and one more card is on screen.** The count itself moves with the
fixture and the point gain does not, so 52pt is the number to check a future
change against: a row inside a group pitches at 52pt, while a loose tracker is
its own section and pitches at 64pt, so whether that 52pt buys a whole card
depends on which kind of row is at the bottom edge. Item 11's iPhone 17 figure
is not eaten back either way.

**The accent is one `.tint(.teal)` on the root view**, not an asset-catalog
colour — there is no catalog yet (item 18) — and the corollary is that
`Color.accentColor` is now *wrong* everywhere: it resolves from the catalog and
stays blue. Three sites that used it (home's card `+`, the sheet's field
chevrons, the settings drop highlight) read the `.tint` shape style instead.
Anything new that needs the accent must do the same, or the app goes
half-teal — which is worse than the blue was.

**A measured problem the colour brings with it, left as the user's call.**
Dark mode's `.teal` renders `#00D9E6`, and iOS draws a prominent button's label
white regardless of tint, so the Log button's own label sits at **1.74:1**
against its fill — where the old blue (`#00A5FF`) gave 2.69:1. Both are under
the 3:1 large-text floor; teal is 35% worse than a blue nobody complained
about. Light mode is the same story (`#00CDD9`, 1.96:1), so it is the
white-on-tint pairing rather than dark mode. `.mint` is no escape: `#00DFCE`,
1.69:1, and greener. A dark label on the teal measures 12.08:1 and was tried —
it reads much better and looks like a brand button rather than an iOS one,
which is the opposite of "boring and native", so it is **not** in. Sampled
from screenshots with an AppKit pixel scan; WCAG ratios computed from the
sampled sRGB.

**There are two of these, not one, and the decision has to cover both.** The
review found the second: a card's `+` is a white glyph the app itself paints on
the same teal disc, so it is the same 1.74:1 pairing, six to ten times down the
main screen. It was 2.69:1 on the old blue — already under the floor, so this
is a worse instance of a failing pairing rather than something teal broke.
Fixing only the small one was rejected on the spot: a dark glyph on the card
`+` beside a white label on the Log pill is two design languages again, which
is the complaint item 11 fixed and the complaint this whole item is named
after. Both sites move together or neither does, and what moves them is the
accent, which is the user's call.

**Item 13b is that call, and it went the other way on the paragraph above.** The
dark label is in, brand-button objection and all: 1.74:1 is not a look to weigh
against a look, it is a control you cannot read. The 12.08:1 recorded here
reproduces as 12.07:1 from a fresh screenshot.

Disabled and pressed both checked, in dark mode: the disabled Log is a black
pill with a grey label at 1.94:1 — **identical before and after**, because iOS
draws a disabled prominent button from a neutral fill and never touches the
tint. Pressed lightens the fill to `#36E0EB`. So the accent change leaves both
states exactly as blue left them, and the dim disabled pill is a pre-existing
system rendering, not something teal introduced.

Swept default → AX5 on home and History, dark mode, with a twelve-tracker
fixture holding the worst case ("Calories burned exercising" against
"1,234,567 kcal"): nothing clipped, nothing overlapping, the stacked fallback
above `.xxxLarge` still stacks, and the `+` disc stays a 30pt circle in a 44pt
target at every size. One thing the white name does cost: at the accessibility
sizes `.subheadline` and `.title2` converge, so the name/number hierarchy that
grey used to carry is left to the stacking order alone. It reads, because the
number is on its own line under the name, but it is thinner than at default
size.

The `#Preview` blocks do not inherit the accent — it is set in the
`WindowGroup` body and a preview never runs that — so all seven of them still
draw the old blue. **Left alone deliberately.** Nothing in this repo has ever
judged a colour from a preview; every recorded number came from a simulator
screenshot and a pixel scan, and adding the modifier to seven previews would
put the accent in eight places to protect a workflow nobody here uses. Item 18
retires the question, since an asset-catalog accent is inherited by previews
too.

## 13b. Dark labels on the teal — done

Decided, from item 13's review. **White on the teal measures 1.74:1** — and the
blue it replaced was 2.69:1, so this made a failing pairing worse rather than
breaking a working one. Both are far below the 3:1 a UI element needs, on the
screen this app exists to be glanced at one-handed.

Keep the teal, change what sits on it: **a dark label on the teal fill**, not
white. Teal is a light colour, so near-black on it reads easily, it stays a
system colour that adapts itself to dark mode, and light-fill-with-dark-label is
ordinary current practice rather than a workaround.

- [x] Both sites move together — the Log pill and a card's +. The review was
      right that fixing one leaves two design languages on one screen, which is
      the complaint item 13 is named after.
- [x] Measure the new ratio and record it.

**`#000000` on the teal, measured at every accent-filled site: 12.07:1 in dark
mode (`#00D9E6`) and 10.73:1 in light (`#00CDD9`).** Against 1.74:1 and 1.96:1
for the white iOS was drawing, and against a 3:1 floor. Sampled from
`xcrun simctl io booted screenshot` with an AppKit pixel scan, cropped inside
each fill so the surrounding row background could not be mistaken for the label;
WCAG ratios computed from the sampled sRGB.

**Four sites, not two.** The item named the Log pill and a card's +, and the
same white-on-tint pairing was also under the log sheet's own Log button and the
empty state's *Add Tracker*. All four are prominent-accent controls on the same
fill, so all four moved — leaving one behind is the two-design-languages
complaint at a smaller scale, and it is the same one-line change.

**The disabled state is why this is a modifier and not a `.foregroundStyle` at
each call site.** iOS draws a disabled prominent button from a neutral fill and
never touches the tint — measured in dark mode as `#3C3C3C` on `#000000`,
1.90:1 — so forcing the label black there paints black on black, and the log
sheet opens in exactly that state every time, with no number typed yet.
`onAccentFill` reads `isEnabled` from inside the button's label and stands
aside, which the probe confirms: the disabled Log is still the system's grey on
its neutral pill, unchanged by this item.

**Pressed was not captured this session, and the number below is computed rather
than measured.** The macOS console was locked for the whole of it, which takes
the AX tree and CGEvent clicks with it (`System Events` reports zero Simulator
windows), so there is no way to hold a button down and screenshot it. Nothing
here touches a fill, and item 13 measured the pressed fill as `#36E0EB`: black
on that is **13.02:1**, higher than at rest, because pressing lightens the fill
and the label is dark now. Worth capturing directly the next time the console is
unlocked, but it cannot fail — pressed only moves this pairing further from the
floor.

## 14. Log it again, from History — done

A button on each History row that logs that entry again, now. Same values, same
trackers, today's timestamp.

This is **search-and-repeat's idea arriving early through a different door**:
you don't search for a food, you scroll to the last time you ate it and tap
once. It is worth building before item 16 rather than after, because it may
turn out to be most of what search-and-repeat was for — and if it is, item 17
gets smaller instead of duplicating it.

- [x] One tap, no sheet, no confirmation. It writes a new batch; it does not
      edit the old one.
- [x] Undo, since a mistap now writes data.
- [x] Works for a batch and for a single entry, without two code paths.

**One code path, and it is now the only one.** `Store.addBatch` is where a batch
gets written, and both the log sheet and a repeat go through it. It takes pairs
rather than a `[UUID: Double]` for two reasons that only showed up here: a
repeat carries each member's *own* name, where the sheet has one name field for
all of them; and a row is a list, so keying by tracker would silently drop one
of two entries that an imported or hand-edited file put in one batch against the
same tracker — after the row had already displayed both. Nothing anywhere
branches on how many members a row has, which is what makes a single entry and a
batch the same case rather than two that agree.

**What a repeat writes to, and what it leaves out.** A tracker deleted with its
history kept, and an archived one, are both unreachable from the log sheet, so a
repeat does not write to them either — a number there would land somewhere no
other screen in the app offers to put one, and somewhere home would never show
it. A row whose trackers are *all* gone gets a disabled disc; the row already
prints "Deleted tracker" for those values, so it explains itself. A row with
some left writes the rest and **says so**: the undo bar reads "Logged 1 of 2
again" rather than letting a button quietly do less than it promised. Refusing
the whole row instead was rejected — deleting a tracker and keeping its history
is a supported choice, and it would disable the button on every row that tracker
ever touched.

**The undo moved to the bottom of the screen, and took the delete undo with
it.** It used to be a section above the first day, which works only while you
are already looking at the top — and neither thing it undoes happens there.
Repeating is a button on a row you scrolled to find; deleting is a swipe on that
same row. In both cases the tap had *no visible result at all*: the new entry
and the undo offer both appeared off screen, above where the user was looking.
An undo you cannot see is not an undo. One bar, at the bottom, in the thumb —
the store keeps one undo slot, so a second affordance in a second place would be
the screen saying the same thing twice.

**One undo slot, not two.** A pending deletion and a pending repeat behind one
Undo button would give that button two meanings and no way to say which; two
buttons is more screen than either case deserves. The newer write takes the slot,
which is exactly what a second deletion already did to the first. Undoing a
repeat records **no tombstone** — the entries are being unmade, not deleted, and
a tombstone would carry "never allow this id again" into every future merge for
a log that lasted two seconds. The same honest limit as the deletion undo
applies in reverse: export between the tap and the undo and a re-import brings
them back.

### The name is the quiet part, and finding a food by name is harder for it

Item 13 made a History row's name a small grey footnote under the values, on the
grounds that the numbers are what every row has. That was right and it stands.
But this item makes History the place you scroll to *find a food by name* to
repeat, and the two do pull against each other, exactly as the brief predicted.

Looked at on the iPhone 17 in dark mode against a twelve-row fixture: scanning
for "chicken rice" means reading eleven small grey second lines while eleven
large white numbers — the part that does **not** identify the food — take the
eye first. It is not unusable. It is slower than it was, and it is slower than
the thing it is standing in for: item 16's search field ranks by name and puts
the answer at the top with no scrolling at all.

**Not changed here, and deliberately not.** Re-loudening the name would undo
item 13 quietly, in a step that was not asked to revisit it, and the honest fix
may be item 16 rather than a font weight. Left as a design question for the
user: if repeating from History becomes the way you log, the name probably has
to grow back — and that is a decision about which of the two items was right,
not a tweak.

## 15. Make a save feel like it landed

Logging a number should **show the number changing**. Today nothing
acknowledges a log beyond the sheet closing: you tap Log, the sheet goes, and
the card behind it is already showing the new total as though it had always
said that. The action has no result you can see happen.

This is the one place the app is allowed a moment of motion, and that exception
should be deliberate rather than accidental — everything else in
PHILOSOPHY.md's Design taste argues against animation, so this is the single
carve-out and it needs to earn the name.

- [ ] The card's number animates from old value to new, briefly.
- [ ] It must not delay anything. The sheet still closes immediately; the
      number catching up happens behind it, and nothing waits on it.
- [ ] No confetti, no bounce, no sound, no haptic celebration. The number moves
      because it changed, not to congratulate you.

Deliberately after a week of real use: whether this is satisfying or annoying
is exactly the kind of thing that cannot be decided from a simulator.

## 16. Search and repeat

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

## 17. One pass on a real device

Three things that no agent can settle, because each needs a thumb, an ear, or
a real phone rather than a simulator. **One errand, not three** — they were
separate items and that was wrong.

**Can a double-tap log twice?** `log()` does not disable the button before
`dismiss()`, so a fast double-tap might write two entries. Two reviewers tried
and could not land synthetic clicks fast enough, and both reported it as
*unverified in either direction* rather than guessing.

- [ ] Settle whether it reproduces, with a real thumb.
- [ ] If it does, disable the action on first tap rather than debouncing by
      time — the action is idempotent per presentation, so state is the honest
      fix.
- [ ] If it doesn't, say so and close it.

It matters more than its size suggests: a silent duplicate on the most frequent
action in the app is the kind of wrong number nobody notices until a graph
looks strange months later.

**VoiceOver.** Commit `0564080` claims `.accessibilityLabel` on the card's +
"had no effect at all", while `logButton` a few lines below and `HistoryView`
both do exactly that and work. Either the claim is wrong, or `children: .ignore`
makes that button a container and the hint has to move inside it. It cannot be
settled from the accessibility tree.

- [ ] Turn VoiceOver on and swipe through home, the log sheet and History.
- [ ] Settle the + button's label and hint, and correct the comment either way.

## 18. App icon and asset catalog

Neither exists. Needed before TestFlight, not before daily use.

## 19. CI

GitHub Actions build + test on push. Cheap, and the test suite is already good
enough to be worth protecting.

Moved to the end deliberately. CI protects a shared branch from contributors
who don't exist yet — the suite already runs on every change because every
session runs it, so until this repo has someone else pushing to it, CI buys
reassurance rather than safety.

## Small things, unscheduled

Real, small, and not worth a session each — the overhead of reading the docs,
testing and reviewing dwarfs the work. **Do them in one pass**, whenever one of
the numbered items is going near the same code.

- [ ] **Export through the share sheet.** A `ShareLink` gives AirDrop,
      Messages, Mail and any app that takes a file, with Files still among
      them. About three lines. Give the file a dated name so a folder of
      exports is readable.
- [ ] **XcodeGen churns `TEMP_…` UUIDs on every regenerate.** Real diff noise in
      a repo that commits its `.xcodeproj` on purpose, and noise makes review
      worse. Pre-existing.
- [ ] **`(max ?? -1) + 1` traps on `Int.max`.** Reachable only from a store file
      with an absurd `sortIndex` — which was "you would have to hand-edit it"
      when it was found, but the app has an **import** now, so a foreign or
      hand-edited file is a real way in. A crash, however unlikely.
- [ ] **The log sheet has no signposted exit** since Cancel was removed. Swiping
      down works and nothing advertises it; `.presentationDragIndicator(.visible)`
      buys it back for one line. Wait until item 12 settles, since the pad may
      change the sheet anyway.
- [ ] **Releasing a settings drag outside the list commits it** rather than
      cancelling. Deliberate — requiring the finger inside would break dragging
      to the top edge to reach the first row — but it is nowhere in the docs, so
      the next person to see it will read it as a bug.

## After v1

- [ ] Home screen widget, Lock Screen widget, App Shortcuts / Siri.
- [ ] Sync transport — the document already merges; this is only plumbing.
- [ ] Apple Watch.
