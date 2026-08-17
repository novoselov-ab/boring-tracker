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

      **"They desaturate themselves for dark mode" is wrong, and it came from a
      web article rather than from a pixel.** Measured across the seven system
      hues (docs/accent-options.md, re-checked for mint in the accent change
      below): blue, teal and mint are `S = 1.00` in *both* appearances, green
      goes **up** (0.74 → 0.77), and only cyan and indigo actually desaturate.
      What Apple changes in dark is **brightness** — the mint this app now ships
      is `S = 1.00, V = 0.78` in light and `S = 1.00, V = 0.85` in dark. So a
      system colour is still the right pick here, but for a different reason:
      both of its values are Apple's and there is nothing to keep in step by
      hand. Any argument of the form "use the UIKit values because Apple already
      desaturated them" does not survive measurement and should not be repeated.
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

Decided, from item 13's review. **White on the teal measures 1.86:1** — and the
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

**`#000000` on the teal, measured at every accent-filled site: 11.30:1 in dark
mode (`#00D2E0`) and 9.72:1 in light (`#00C3D0`).** Against 1.86:1 and 2.16:1
for the white iOS was drawing, and against a 3:1 floor. Sampled from
`xcrun simctl io booted screenshot` with an AppKit pixel scan, cropped inside
each fill so the surrounding row background could not be mistaken for the label;
WCAG ratios computed from the sampled sRGB.

**Those four numbers are corrections, and the ones they replace now have an
explanation — it is the sampler.** This item first recorded `#00D9E6` /
`#00CDD9` and 12.07:1 / 10.73:1; item 13c sampled `#00C3D0` / `#00D2E0` and
11.30:1 / 9.72:1 an hour later and could not reconcile them. The item 13d review
settled which one ships: **13c's.** The accent change to mint found out why, by
running both readings on one file.

`NSBitmapImageRep.colorAt(x:y:)` **does not return the bytes in the PNG** on this
machine, even for a screenshot tagged `sRGB IEC61966-2.1`. Written as a
one-pixel sRGB PNG and read back through it:

    in the file    via colorAt      where that number was recorded
    #00D2E0    →   #00D9E6          items 13 and 13b, teal in dark
    #00C3D0    →   #00CDD9          items 13 and 13b, teal in light
    #0091FF    →   #00A5FF          item 13, "the old blue"
    #00DAC3    →   #00DFCE          item 13, `.mint` as the runner-up
    #000000    →   #000000
    #FFFFFF    →   #FFFFFF

So both sets of sessions measured the same pixel and disagreed about what it
was: one read the decoded IDAT bytes, one asked AppKit and got a colour
converted out of sRGB. **Black and white are fixed points of that conversion**,
which is exactly why the check every session ran — "black reads `#000000` and
white `#FFFFFF`, checked" — passed every time and caught nothing.

Two things follow. The disputed hexes were never invented, so the harsher
reading of them in the paragraphs below can be retired; and **the sampling tool
is part of the measurement**. Anything sampling a screenshot here should read
the PNG's own bytes. The contrast conclusions are untouched either way: the
converted hexes sit 7 to 20 units per channel off the real ones — 7 for the
teal, 20 for the blue's `0x91 → 0xA5` — which moves a ratio by a few percent
and no verdict in this file by anything.

The deciding run was this commit itself. `b01fe00` checked out into a worktree,
built and screenshotted today on the same iPhone 17, renders `#00C3D0` in light
and `#00D2E0` in dark — byte for byte what 13c measured, at both the Log pill
and a card's +, with every pixel inside the fill identical. So the code is not
the difference. Nor is the sample site, nor **a colour-space conversion of the
file**, which is where this stopped: no *profile pair* maps one hex to the other
(Display P3 → sRGB of `#00C3D0` is `#00C7D3`), and Increase Contrast gives
`#3BDDEC` / `#008198`. That ruled out the image and left the reader unexamined —
the conversion was happening one layer up, inside the sampler, on a file whose
bytes were correct all along. Nor, crucially, was it **a machine that changed
underneath us**: the two sets were recorded 65 minutes apart, on one Mac, against
the one runtime installed here (iOS 26.3.1, 23D8133). There was no update to
blame.

The arithmetic was never the problem either — 10.73:1 follows exactly from
`#00CDD9`. What failed is the pixel, not the sum, which is the failure "Always
check, not just read" in WORKFLOW.md exists for; the correction is that the
unchecked step was the *tool*, not the person. Every conclusion drawn from it is
unaffected in either case; the fill clears the 3:1 floor by six to seven times.

The same doubt covered **every accent hex recorded before 13c** — the pressed
`#36E0EB` in item 13, the `#00CBD9` / `#00CDD9` foreground pairs below, the
`#00D9E6` in item 14's undo bar. Two of those three are literally the pair in
the table above, and the third was sampled the same way, so they are converted
readings of real pixels rather than doubtful ones. **What they are not is
invertible on paper:** the conversion is not per-channel — a grey ramp maps
`0xD2 → 0xDB` while the teal's green channel went `0xD2 → 0xD9` — so the only
way back to a true hex is to re-sample the screenshot, not to correct the
number. 13c re-measured every one of them on the day it changed them, so its
table is still the set to read; the numbers left in place around here are kept
for the reasoning attached to them, not for the digits. Two of 13c's have since been
re-checked independently and land on the same pixel — the nav bar gear at
2.13:1 light and 10.71:1 dark — so that table has now been reproduced by a
session that did not write it.

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

**Reproduced by the review, on its own probe build and its own pixel scan** —
and then unreproduced by two later ones, which is the whole of the correction
above. What that review recorded: `#000000` on `#00D9E6` at the Log pill, a
card's +, the empty state's *Add Tracker* and (after item 14) the History
repeat disc, **12.08:1** dark and **10.69:1** light. Read it now as the second
of the two sightings of a hex nothing since has been able to draw; the numbers
that describe what ships are 11.30:1 and 9.72:1. The disabled Log measured
`#3C3C3C` on `#000000`, **1.92:1** —
the system's own rendering, so `onAccentFill` did stand aside rather than paint
black on black. **There is no fifth site:** every other `.tint` in the app is a
foreground (the chart's line and area, the log sheet's chevrons) or the settings
drop highlight at 0.18 opacity, and no `Color.accentColor` survives anywhere.
Pressed stayed uncaptured for the review too — the console was still locked —
but the 13.02:1 above recomputes exactly from `#36E0EB`.

**The other half of the accent was never measured, and it fails in light mode.**
This item fixed what sits *on* the teal. Nothing here looked at the teal drawn
*as* a foreground on a light background, which is what every plain tinted control
does — and in light mode that is teal on near-white, measured on the iPhone 17:

    #00CBD9 on #FCFCFF   1.95:1   nav bar gear, and the History clock beside it
    #00CDD9 on #FBFBFD   1.89:1   the undo bar's Undo button (item 14)

Against the same 3:1 floor, and against 2.68:1 for the blue this replaced — so
again a failing pairing made worse rather than a working one broken. Dark mode is
fine at 10.21:1, and dark mode is where this app is used, but light mode ships
too. **Not fixed here, and not a fifth instance of what 13b fixed** — those four
sites were *fills* and this is the tint itself, at every plain tinted control in
the app including two that predate item 14. Moving it means changing the accent
or how a foreground tint is drawn app-wide — nav bar, chart, log sheet chevrons,
the undo bar — which is the same decision item 13b was, and the same one that
belongs to the user rather than to a review of item 14.

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

**Correction, from the review: only the *deleted* half of that explains itself.**
An archived tracker is still a record, so its row prints its value like any
other, and the sentence above is true of a deleted tracker's row and false of an
archived one — the disc is simply off, with nothing on the row saying why.
Checked on the iPhone 17 against a fixture holding both: the deleted row reads
"Deleted tracker: 3", the archived row reads "7 y". The disabled disc measures
1.25:1 against the row in light mode and 1.58:1 in dark, so it reads as *no*
button rather than a dead one, which is why this is a missing explanation and
not a control that lies. Left as it is on purpose: saying "Archived" on the row
changes what a row shows, and what a row shows is item 14b's question.

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
which is exactly what a second deletion already did to the first.

**And a newer write ends a pending repeat's offer, which the first pass did not
do.** The review found the hole: only `logAgain` and a deletion set the slot, so
a log through the sheet or an edit left the old offer standing. Repeat a row, log
a different food, come back to History, and the bar still read "Logged again"
over a list whose top row was the food you had just logged — Undo then deleted
the repeat, with no tombstone and nothing to recover it from. Editing the batch a
repeat wrote was the same shape and worse: Undo removes by id, so it took the
edit away with the entries. Adding an entry and editing one now withdraw a
pending repeat, and `logAgain` sets it again afterwards.

**Only the repeat's, because the two slots are not symmetric.** Undoing a repeat
*removes* records, so a stale offer destroys data; undoing a deletion only puts
records back, so it can go stale harmlessly — and tracker detail's undo row
surviving a log made while it is on screen is the forgiving behaviour that
already shipped. Withdrawing both would have paid for this bug with a working
undo somewhere else. A repeat that loses *some* of its members to a tracker
deletion drops out whole for the same data reason — "Logged 1 of 2 again" beside
a write that is now one entry describes a row that never existed. A save that
changed nothing withdraws nothing, by the same test that already decides whether
a member gets a fresh `modified`: opening the row a repeat wrote to check the
number should not cost the undo.

**The Undo button was a 20pt target inside a 40pt bar.** `Button("Undo")` is hit
only where the word is drawn, so the recovery for a control that writes data on
one tap was half the size of the mistake it exists to fix — while the repeat disc
eight lines below it carries an explicit 44pt frame. Its label now carries the
same 44pt, which took the bar from 74.3pt to 78.0pt overall on the iPhone 17
(measured off screenshots: the `.bar` material's top edge moved 11px at 3x, and
34pt of that total is the home-indicator safe area either way). The bar's own
vertical padding moved onto the message to buy that: at default sizes the
button's 44pt sets the height and the padding is slack inside it, and above the
accessibility sizes the message is the taller of the two, where without it the
wrapped lines render flush against both edges of the material. Padding the bar
instead bought the same margin at the cost of 12pt at every size. Swept to AX5:
the message wraps to two lines with room above and below, and nothing clips or
overlaps.

**Still unpressed, by the review as well.** The console was locked for both
sessions, so the repeat disc's tap target, the swipe-to-delete on the
restructured row and the Undo button's own tap were driven through the store and
looked at in screenshots, never touched. What the screenshots do settle: both
repeat paths write a new row into Today and leave the tapped row's values, name
and time exactly as they were; the partial row's bar reads "Logged 1 of 2 again";
the deleted-tracker row prints "Deleted tracker" beside a disc that is off. The
bar's Undo measures **10.21:1** (`#00D9E6` on the bar's `#171818`) in dark mode,
not the 7.3:1 recorded above — comfortably clear either way, but the smaller
number was the one that did not reproduce. In *light* mode the same button is
1.89:1, which is the accent's own problem rather than this item's — see the last
paragraph of 13b.

Undoing a
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

## 13c. Teal is a fill, not a text colour — done

Left by the item 14 review: the teal drawn as a *foreground* — tinted text and
glyphs on the ordinary background — was never measured and fails in light mode.
It predates item 14 and is the accent itself.

Rather than tune a second shade, apply the rule 13b already established:
**teal is something you put behind a dark label, not something you write
with.** Where it currently paints text or a small glyph directly, it becomes
either a fill with a dark label on it, or the ordinary label colour.

- [x] Find every foreground use of the accent and convert or revert it.
- [x] Measure light mode as well as dark. Dark is what this app is used in,
      but light still ships, and "we only look at dark" is not a reason for it
      to be unreadable.

**The accent stopped being the tint.** Finding them one at a time is how this
went wrong twice, and a tint is inherited by every standard control there is —
so the fix is at the root: `.tint(.primary)` in `BoringTrackerApp`, and teal
survives only where a line of code names `Color.accentFill` to fill something.
A foreground use cannot be missed now, because there is nothing left to inherit
it from. `.primary` rather than no tint at all, since the default is the system
blue item 13 deliberately stopped using.

Seven sites moved, measured on an iPhone 17 in both appearances. Light first,
because light is where it failed:

    nav bar gear, home            2.13:1  →  20.34:1     dark 10.71 → 15.84
    nav bar +, tracker detail     2.13:1  →  16.98:1     dark 10.71 → 15.99
    the Group picker's value      2.16:1  →  21.00:1     dark  9.15 → 17.01
    Export JSON, in settings      2.16:1  →  21.00:1     dark 11.30 → 21.00
    the log sheet's chevrons      2.07:1  →  19.00:1     dark  7.65 → 13.27
    a chart bar on its card       2.16:1  →  21.00:1     dark  9.15 → 17.01
    History's Undo                2.07:1  →   9.72:1     dark  9.93 → 11.30

The four fills item 13b fixed are untouched and measure what they did before:
black on `#00C3D0` in light, on `#00D2E0` in dark. **Those two hexes are not
the `#00CDD9` / `#00D9E6` recorded in items 13 and 13b, and the ratios that
follow are 9.72:1 and 11.30:1 rather than 10.73:1 and 12.07:1.** Sampled the
same way — `xcrun simctl io booted screenshot` and an AppKit pixel scan, on a
PNG that reports itself as `sRGB IEC61966-2.1`, cropped inside each fill.
Black reads exactly `#000000` and white exactly `#FFFFFF` in the same crops, so
nothing is shifting the whole image; the accent itself renders slightly darker
on this runtime than the one those numbers were taken on.

**Settled in the item 13d review: these numbers are the right ones**, and 13b
has been corrected rather than this item. Building `b01fe00` — the commit whose
message records the other hexes — reproduces `#00C3D0` / `#00D2E0` today, so
the difference is not the code; the reasoning that rules out the sample site,
the colour space and Increase Contrast is written up under item 13b.

**Undo is now a fill rather than a word.** It is the one control in the app
that exists to be found in a hurry, and "the ordinary label colour" would have
made it read as part of the sentence beside it. A 32pt capsule inside the 44pt
target item 14 gave it, which is the repeat disc's idiom in the shape a word
needs, so the bar's height did not move.

**The chart lost its colour, and that is the visible cost of the rule.** Bars
and the readings line were `.foregroundStyle(.tint)`, which is a foreground use
by anybody's definition — and at 2.16:1 a bar was barely a shape in light mode.
They are the label colour now: black bars on white, white on black. The moving
average stays `.secondary`, so the two lines are still told apart, by weight
rather than by a hue one of them can no longer have.

**And the nav bars read quieter.** Cancel, Save, the gear, the clock and
tracker detail's + are the label colour now, which on iOS 26 still sits inside
a glass capsule that says "button" — but a tinted nav bar is what an Apple app
looks like, and this is the one place the rule costs something rather than
buying something. Left as it is: the alternative is a second accent for
foregrounds, which is the "tune a second shade" this item exists to refuse.

## 14b. Put the name first, still grey — done

Item 14 found what its brief predicted: scanning History for a food now means
reading twelve small grey *second* lines while twelve large white numbers — the
part that does not identify anything — take the eye first. It refused to
re-loudify the name, which was right; that would have undone item 13 quietly in
a step not asked to revisit it.

The fix is **position, not weight.** A grey name on the first line scans far
better than a grey name below a large number, because reading order does the
work. So the name stays quiet, exactly as asked, and rows stay uniform — the
uniformity was always about every row having the same *structure*, not about
the name being hard to find.

- [x] The name leads the row; the numbers follow.
- [x] An unnamed entry keeps the same structure — the tracker or group name
      leads instead, so every row still has an identity line.
- [x] Do not change the name's colour or weight.

**It costs no density at all**, which was the thing worth checking, since every
row grew a line it did not have before. Measured off screenshots by finding the
list's separators — the only full-width faint lines in the card — on an
iPhone 17 in dark mode against the same fixture before and after: separators at
y = 622, 778, 934, 1090, 1246, 1450, 1606, 1762, 1918, 2074, 2230 px in **both**
builds. A 52pt row pitch, one 68pt row where the values wrap to two lines, and
not one pixel of movement. The repeat disc's 44pt frame was already setting the
row height, and a footnote above a body line still fits inside it.

**The identity line is `HistoryItem.line(trackers:)`, not two properties in the
view.** The two lines have to agree — the identity line names the tracker, so
the values line must stop repeating it — and that agreement is a rule worth a
test rather than a coincidence between two computed properties. Nine tests pin
it: a named batch, an unnamed one falling back to its group, a lone reading
falling back to its tracker rather than to that tracker's group, and the case
that made the rule necessary — `Cigarettes` has no unit, so its row used to
read "Cigarettes: 3" under a name that was about to say "Cigarettes" again.

Two rows say more than they used to, for free. **An archived tracker's row now
names it** — it reads "Old scale / 79.1 kg" beside a disc that is off, which is
the missing explanation item 14 recorded and declined to fix by adding a label.
And a deleted tracker's row leads with "Deleted tracker" instead of burying it
in front of the number.

Not changed: tracker detail's own list, which draws the same shape and is not
this item's question — there the tracker is the screen you are on, so a name
line would repeat the title on every row.

Checked in review against a fixture built to hold every shape at once: a named
batch, an unnamed one, a named single, an unnamed single with no unit
(`Cigarettes / 3`, which is the case the rule exists for), an unnamed lone
reading (`Weight / 79.1 kg`, its tracker and not its group), an archived
tracker, a deleted tracker alone, a deleted tracker inside a live batch, and a
batch whose two members share a unit. Every row leads with an identity line, no
identity line is repeated by the values under it, and every name is still the
footnote grey.

**And one shape the fixture did not hold, which is where the bug was.** Dropping
the tracker's name from the values line was conditioned on the row having one
entry, when the condition it meant was *the identity line is the tracker's
name*. A typed name takes that line first, so a named lone entry on a unitless
tracker read "after lunch / 3" — naming neither the number nor what it counts,
where the old layout said "Cigarettes: 3" — and a named lone entry whose tracker
had been deleted read "after lunch / 3" with no "Deleted tracker" at all, which
is the sentence this item's own doc comment promises and the only explanation
for the dead repeat disc beside it. `entries.count == 1 && displayName == nil`
is the whole fix, and three more tests hold the two broken rows and the one that
must not change: a named lone entry *with* a unit still reads "90 kcal", because
the unit is already doing the telling-apart.

A third round found the same mistake from the other end: "Deleted tracker" on a
value exists to tell that member apart from the ones that survived, so a batch
where *none* survived said it three times in one row — once as the identity line
and once per number. Two taps reach that, because settings offers a deletion
that keeps the history, so removing both members of a group orphans every batch
it ever logged. It reads "Deleted tracker / 100, 10" now, and keeps the prefix
when a name of your own has taken the identity line and nothing else is left to
say it. Fourteen tests, not nine — and two of them pin their tracker ids rather
than generating them, because with every tracker gone the row's order falls
through to the ids and a random pair makes the expectation a coin toss.

## 13d. Give the nav bar its tint back — done

Item 13c's rule — teal is a fill, not a text colour — was applied to nav bar
buttons too, so Cancel, Save, the gear and the clock are now the plain label
colour. The session flagged it as **the one place the rule costs rather than
buys**, and it is right.

A tinted nav bar button is not text painted in an accent; it is the standard
iOS affordance that says *this is tappable*, on a bar background Apple has
already tuned for it. 13c exists to stop teal being used to **write** — chart
bars, glyphs and labels on the ordinary background. System chrome is not that.

- [x] Restore the accent on nav bar buttons only.
- [x] Leave the chart monochrome and every other 13c change alone. This is a
      carve-out for system chrome, not a retreat from the rule.

**Ten buttons name it; nothing inherits it.** The root tint stays `.primary`,
and each bar button asks for the accent by calling `navBarAccent()` — the gear
and the clock on home, tracker detail's +, Cancel and Save in the three editors,
and the log sheet's group switcher. Per button rather than at the root because
13c's real fix was not the
colour but the *absence of inheritance*: with nothing left to inherit teal from,
a foreground use of it cannot appear by accident, which is how this went wrong
twice before. The failure mode of the explicit version is one black word beside
a teal one on the same bar, which is visible the first time the screen is
opened.

**What it costs, measured on an iPhone 17 in both appearances**, the gear on
home standing for all nine — glyph against the glass capsule it sits in:

    light   20.34:1  →  2.13:1
    dark    15.88:1  →  10.71:1

Dark is fine and light is not: 2.13:1 is the number 13c removed, and for Cancel
and Save it is *text* at 2.13:1 rather than a glyph. The capsule cannot make up
for it either — `#FBFBFF` on the `#EFEFF4` bar is 1.09:1, so in light mode the
glyph is doing nearly all the work of saying "button". This is the deliberate
cost of the carve-out and it is recorded rather than argued with; if light mode
ever gets a real pass, this is the first thing on its list.

**And the strongest argument against it, kept because it is a good one.** The
third review round put it exactly: "a bar background Apple has already tuned for
it" is true of the hue Apple tuned it *with*. The system blue `#007AFF` on that
same bar is **3.89:1** — over the floor — where teal is 2.13:1. So the standard
affordance carries its own contrast and this accent does not; what the carve-out
inherits from Apple is the shape, not the number. If that turns out to matter in
use, the honest fix is a darker teal for foregrounds, which is the "tune a
second shade" 13c exists to refuse — which is to say the two items disagree, and
this is where the disagreement lives.

**The back chevron does not follow, and it turns out it never did.** It is drawn
in the label colour whatever the app's tint is: the tint was set to `.primary`,
to teal on the destination, to teal on the `NavigationStack` and to teal at the
app root, and the chevron came back `#19191D` in light and `#F4F3F4` in dark
every time — the same 466 pixels, byte for byte, in all of them.
`UINavigationBar.appearance().tintColor` does nothing to it either, and
`toolbarForegroundStyle(_:for:)` is unavailable on iOS.

A null result is only worth as much as its proof that the experiment ran, so the
root-teal build carries a discriminator: that same build's settings screen draws
12,196 teal pixels where the shipping build draws none. The teal was installed,
it was inherited, and the chevron alone declined it. A review round read this the other way — that the chevron takes the stack's
tint and no per-button modifier can override it — and the second half is right
for the wrong reason: nothing overrides it because it never reads a tint at all.

So tracker detail's white chevron beside a teal + is what this OS draws, not
something 13c took away, and there is nothing here to restore.

**The log sheet's group switcher took two rounds to settle.** It was left out at
first, on the argument that a `Menu` sitting where a title goes is a title, and
a nav bar title is the label colour in every Apple app. Two review rounds read
it the other way and they are right: the same sheet draws a *static* title —
the same words, in the same place, for a group there is nothing to switch to —
and the only thing separating "this is what you are logging" from "this is what
you are logging, and you can change it" had become a 12pt chevron. It is the
one control on that screen. It is tinted.

**And the review found a second Undo that item 13c never got to.** 13c
redesigned History's undo bar into a filled capsule on the grounds that undo is
the one control in the app that exists to be found in a hurry — and a tracker's
own detail screen has its own undo row, for the swipe-delete that happens there,
which was still a bare `Button("Undo")`. With the tint at the label colour, the
recovery for a destructive action was drawn exactly like the "Deleted batch"
sentence beside it. Both now draw the same `UndoButton`, which is shared rather
than copied precisely because this is what copying it produced: one screen
redesigned, the other left behind, and nobody looking at both at once.

## 13e. Form buttons lost the only thing that said they were buttons

Found by the 13d review, and left for a decision rather than folded into 13d,
whose brief says to leave every other 13c change alone.

13c converted *Export JSON*, *Export CSV*, *Import JSON*, *Restore Data Before
Last Import…* and *Add Tracker* to the label colour, and recorded it as a win —
2.16:1 to 21:1. It is a win on contrast and a loss on affordance. Measured on
the settings screen in light mode, the same screen built two ways: the accent
build draws 12,196 teal pixels there, and every one of them is black in the
shipping build. A `Button` in a `Form` has **no** disclosure chevron, so with
its label and its icon in the label colour it is pixel-identical to a static
row. The tracker row above it still reads as tappable, because a
`NavigationLink` keeps its chevron.

So this is the same argument 13d just accepted for the nav bar — a tint on a
standard control is the OS saying "tappable", not the app writing in colour —
arriving at the other place the app relies on it. The options are the 13d
carve-out extended to `Form` action rows, or leaving them plain and giving them
some other affordance.

It reaches further than the Data section: `.alert` and `.confirmationDialog`
buttons take the tint too, so the import's *Merge Documents* / *Replace
Everything…* sheet is drawn the same way.

- [x] Measure mint as a `Form` button foreground, in dark and light.
- [ ] Decide whether a form action row is chrome, like a bar button, or writing,
      like a chart bar. **Blocked on item 18** — see the measurement below.
- [ ] If chrome: it is `navBarAccent()` under a better name at five call sites,
      and the name in `OnAccent.swift` should stop saying "nav bar".
- [ ] If writing: they need something that is not colour, and "a row that looks
      exactly like a label" is not an answer either.

**The mint was measured as a form button foreground, and it splits the same way
the nav bar does.** Built with `.tint(Color.accentFill)` on the settings action
rows — *Share JSON…*, *Share CSV…*, *Save …to Files…*, *Import JSON*, *Add
Tracker* — on an iPhone 17 / iOS 26.3, reading the screenshot's own IDAT bytes:

    dark   text #00DAC3 on the row's #1C1C1E   9.57:1
    light  text #00C8B3 on the row's #FFFFFF   2.12:1

Against a 3:1 floor that is a pass in the appearance this app is used in and a
clear fail in the other, so the tint is **not** restored here. It is the same
shape of failure as the light-mode nav bar (2.05:1, item 13f) and it has the
same fix: **item 18's colour set, a deliberate darker value for light mode.**
One hue cannot be both a legible fill and a legible foreground on white.

The light number is not a coincidence — 2.12:1 is exactly what 13b measured for
*white on the light mint fill*, because contrast is symmetric and it is the same
pair of colours. That is worth knowing: **the accent's foreground problem in
light mode is the white-label problem read backwards**, and one colour set fixes
both.

**A tint would also only recolour half of each row, which nothing has said
before.** Under iOS 26 the tinted rows draw their *text* mint and leave the SF
Symbol at the label colour — measured on the same screenshots, the glyph is
`#FFFFFF` in dark and `#000000` in light, both at their full 17:1 and 21:1
against the row. So "restore the tint" does not undo 13c's change; it produces a
two-colour row, mint word beside a label-coloured glyph. Whatever item 18
settles has to say what the icon does too.

## 13f. The accent is a mint — done

The teal is gone and **`Color(.systemMint)` is the accent**, one hue swap at one
constant. Everything 13b, 13c and 13d settled stays exactly as it was: the dark
label on the fill, the accent not used as text, the nav bar keeping its tint,
the chart monochrome. Items 18, 13e and 18b are deliberately untouched — they
get revised once this has been lived with.

- [x] `Color.accentFill` is mint; nothing else names a hue.
- [x] Re-measured on screen rather than taken from docs/accent-options.md.

**Measured on an iPhone 17 Pro, iOS 26.3, both appearances, reading the PNG's
own bytes** (see the sampler correction under 13b — this is the first set here
taken without AppKit in the path):

    dark   fill #00DAC3   black label 11.82:1   nav bar glyph  9.89:1
    light  fill #00C8B3   black label  9.91:1   nav bar glyph  2.05:1

The fill is `S = 1.00` in both appearances; what changes is `V`, 0.78 light to
0.85 dark. Every accent-filled site draws the same two bytes — the Log pill, a
card's +, History's repeat disc — and a whole-image scan of six screenshots
finds **no teal and no blue pixels anywhere**, which is what "one constant"
should mean and is worth checking rather than assuming.

**Mint is legal only because item 13b banned the white label, and those two
decisions are now coupled in a way the blue alternative would not have been.**
White on this fill is **1.78:1** dark and 2.12:1 light — the worst in the
candidate set bar cyan — against 11.82:1 for the black label the app forces.
A blue clears 3:1 with either label; mint clears it with one. So anything that
puts a white label back on an accent fill (dropping `onAccentFill()`, a new
prominent button that forgets it, a control that draws its own label) does not
look slightly different, it takes the accent under the floor everywhere at once.
`Color.onAccent` is load-bearing now, not tidy.

**The light-mode nav bar still fails, at 2.05:1**, on the `#FBFBFF` circle iOS 26
draws behind a bar button — marginally worse than the teal's 2.13:1, and the
number that opened item 18. Dark mode, which is the appearance this app is used
in, is 9.89:1. Nothing here fixes that, and item 18 is where it is fixed.

**A mechanism claim in docs/accent-options.md is narrower than it reads.** That
document has a SwiftUI system colour rendering a bar glyph exactly `+13/255` on
every channel where the UIKit value draws the fill unchanged. Built both ways
today: the fills are identical to the byte (`#00DAC3`), and under `Color.mint`
both bar buttons come out `#0DE7D0` — but under `Color(.systemMint)` home's gear
draws `#00DAC3` while History's clock *still* comes out `#0DE7D0`. Same constant,
same bar, two different bytes. So the offset belongs to the button as much as to
the constant; the table was taken from the gear alone. Both readings are 9.89:1
and 11.18:1 against that bar, so it changes nothing here beyond what may be
concluded from it.

## 15. Make a save feel like it landed — done

Logging a number should **show the number changing**. Today nothing
acknowledges a log beyond the sheet closing: you tap Log, the sheet goes, and
the card behind it is already showing the new total as though it had always
said that. The action has no result you can see happen.

This is the one place the app is allowed a moment of motion, and that exception
should be deliberate rather than accidental — everything else in
PHILOSOPHY.md's Design taste argues against animation, so this is the single
carve-out and it needs to earn the name.

- [x] The card's number animates from old value to new, briefly.
- [x] It must not delay anything. The sheet still closes immediately; the
      number catching up happens behind it, and nothing waits on it.
- [x] No confetti, no bounce, no sound, no haptic celebration. The number moves
      because it changed, not to congratulate you.

Deliberately after a week of real use: whether this is satisfying or annoying
is exactly the kind of thing that cannot be decided from a simulator.

**Three lines, and none of them is in the code that logs.** The card already
carried `.contentTransition(.numericText())` and nothing ever animated into it,
because nothing changed the total inside an animation. It now carries
`.animation(.easeOut(duration: 0.3), value:)` on the number itself, so the
motion belongs to the card rather than to the log sheet. That is what makes a
repeat from History, an undo, an edit and a deletion all get it without a
second implementation — and it is why `log()` is untouched: it still writes and
dismisses in the same breath, with nothing to wait for.

An ease, not a spring, because a spring is a bounce and a number that bounces
is congratulating you. `numericText(value:)` rather than the bare form, so the
digits roll up for a log and back down for an undo.

**The dismissal is unchanged, measured rather than asserted.** Three runs each,
on an iPhone 17, with `xcrun simctl io recordVideo` and frames pulled at exact
60 Hz through `AVAssetImageGenerator`; the write and the dismiss are triggered
together from a temporary launch-argument probe, because the macOS console was
locked for this session and a locked console has no synthesized taps in it. The
sheet is gone — its band matching the settled frame — at **+383, +400, +400 ms**
without the animation and **+383, +400, +400 ms** with it. Everything on screen
stops moving at +383/+400/+400 before and +400/+417/+400 after: one frame of
difference on two runs of three, which is the animation's tail outliving the
sheet by 16 ms.

**And it is visible, which was the other thing worth checking.** The sheet
uncovers the top of home first, so the first card is in the clear about 130 ms
into a 400 ms dismissal: the frame at press+133 ms shows "2,830" mid-roll with
its middle digits blurred on the way from 1,830 to 2,286, and the frame at
press+283 ms still shows the last of it. Against the same run without the
animation, the number's own region differs by a mean 0.078 → 0.055 → 0.031 over
those frames while the no-animation build's own frames differ by 0.011 across
the same span.

**Reproduced in review, by a second method that disagrees on the absolute
number and agrees on the answer.** Three runs each again, but the moment the
sheet is judged gone is a strip of screen it covers and home does not fill —
the last place it leaves — rather than a band matched against the settled
frame: **+353, +364, +356 ms with the animation and +355, +357, +365 ms
without.** The two builds are indistinguishable; the spread within one build is
larger than the gap between them, and both are under a frame at 60 Hz. The
absolute numbers are ~40 ms below the ones above because the two methods draw
the finish line in different places, which is worth knowing before someone
tries to reconcile them. The number's own region tells the two builds apart in
the same recordings — it is still settling at +300 to +400 ms in the animated
build (residual 0.005 falling to 0.002) where the plain one is quiet at 0.0005
by +314 ms — so the animation is visible, it outlives the dismissal by a few
frames, and it holds nothing up.

**What a repeat from History gets is the same code and a different view of
it.** The total does animate, but History is pushed over home, so nobody is
looking at the card — by the time you go back it has settled. The
acknowledgement on that screen is the undo bar item 14 put there, which appears
in the same instant. Left as it is: the alternative is a second, screen-specific
piece of motion, and this item exists to have exactly one.

**The number also moves at midnight, and that is left alone.** A review round
found it: `refreshToday()` runs on `scenePhase == .active`, so opening the app
the next morning rolls every daily total down to zero over 0.3 s, and the one
piece of motion in the app is acknowledging something the user did not do. Kept,
for two reasons. The number *did* change, which is the whole rule this item is
written to — the roll shows the day resetting, which is a true and useful thing
to see once a day. And the fix would be a flag set by the write paths, which
undoes the property that makes this item three lines: *none of it is in the code
that logs*, so a repeat, an undo, an edit and a deletion all get it for free. A
flag would buy silence at midnight by putting the animation back in the hands of
everything that writes. If it turns out to grate in use, that is the trade to
reopen.

**Confirmed wasteful-at-worst, not stuck**, since "it animates a card nobody is
looking at" is only harmless if it also stops. Recorded a repeat fired from
History with home underneath it: the screen is still from +2.4 s after launch
until the write, the write costs **one** changed frame — the new row arriving,
with the undo bar reading "Logged 1 of 2 again" — and the next six seconds are
at the noise floor. So the covered card produces no frames at all, and there is
nothing that could run on: `.animation(_:value:)` fires on a change and
`.easeOut(duration: 0.3)` does not repeat, so the worst case is one bounded ease
on one `Text` that nobody sees.

## 16. Repeat: a screen of things you have eaten — done

**Supersedes the search-field-in-the-log-sheet design**, which is deleted
rather than kept alongside. That put search inside the sheet you use to type a
new number; this is a separate door for the different job of logging something
again, and it is fewer taps for it — home, Repeat, tap, done, without ever
raising a keypad. Two doors to one action is what the export screen just lost.

- [x] **A control beside Log on home.** The risk is here: home's bottom already
      holds the most frequent action in the app, and a peer next to it competes
      with it. Try it as a smaller secondary control rather than a second
      equal button, and say how it reads.
- [x] **Every named entry, newest first. No deduplication for now.** The row
      is what you logged: its name, its values, its date. Forty logs of
      "chicken rice" are forty rows, and that is accepted deliberately —
      deduping by name alone hides that you sometimes ate a bigger portion, and
      deduping by name *and* values raises questions about someone who weighs
      food precisely and never repeats a number exactly. Neither is worth
      answering before the plain list has been used.
- [x] **Searchable**, filtering those names.
- [x] **One tap logs it again**, reusing item 14's `logAgain` — a new batch,
      today's timestamp, the original untouched, and undo. Do not write a
      second implementation of repeat.
- [x] Entries with no name are not in this list. The name is what makes
      something repeatable; an unnamed number is a measurement, not a meal.

Ordering: recency was right for the raw list. With duplicates collapsed,
**frequency deserves a look** — it puts the portion you usually eat first and
lets a rare variant sink, where recency floats a one-off to the top merely
because it was yesterday. Whoever builds it should try both and say which reads
better; it is a *displayed* decision, so it costs nothing to change again.

The failure mode to watch and report: someone who weighs food precisely never
repeats a number exactly, so nothing collapses and they see the raw list again.
If that is bad it wants rounding or grouping — a design decision, not a fix to
slip in.

**Still an experiment.** Settled enough to build, not settled enough to defend.
Watch for the one thing that would be expensive: a version of this that needs a
fact the document does not record.

### It is not fewer taps than History, and the item's own claim above is wrong

Both paths are **two taps**: home → Repeat → the row, and home → History → the
row's disc. The sentence at the top of this item — "it is fewer taps for it" —
was never true, and the brief was right to demand the count out loud.

What it actually buys, on the same 56-day fixture (364 entries, 336 of them
named), measured off screenshots on an iPhone 17 in dark mode:

- **12 candidates on the first screen against History's 9.** History spends the
  space on day headings and on rows this screen has no use for — an unnamed
  weight reading sat fifth in the list. Both were two taps to the top row and
  neither needed a scroll; past the first screen History has nothing but
  scrolling, and this has a search field.
- **The whole row is the target — 370×52pt against a 44pt disc.** Where a tap
  lands is half the budget (docs/PHILOSOPHY.md), and this is the larger half of
  the difference. There is nothing else a tap on this screen could mean, so
  nothing had to be given up to widen it; on History the row itself opens the
  editor.
- **Search is the only way to reach anything old.** 56 days is already 112 rows.

So the screen earns its place on *finding*, not on tapping, and the item's
opening paragraph is left standing above this correction rather than edited, so
that what was claimed and what was measured stay legible apart.

### It is noisy, exactly where the brief said to look

Searching "rice" on the 56-day fixture returns **eight rows, six of them
`620 kcal, 45 g`** — the same meal, the same numbers, six times. The screen is
readable and the top row is nearly always the one you want, but the bottom of
the list is repetition with dates attached.

**Not fixed here, and the reason is the one this item already gives.** The two
obvious answers each hide something real, and the plain list has not been used
yet. What the fixture does settle is that the *portion drift* case is real
rather than hypothetical: the same "pasta pesto" appears at 650 and 690 kcal
within one screenful, so deduplication by name alone would have to pick one and
silently drop the other.

### The list is built once, when the screen opens

`Store.repeatItems` walks and sorts every entry ever logged. Measured in the app
on the iPhone 17 simulator with a temporary `print` around the build (Debug
build, reverted before the commit):

| entries | rows  | build  | one search keystroke |
|---------|-------|--------|----------------------|
| 7,644   | 3,597 | 23.4ms | 5.3ms                |
| 15,294  | 7,197 | 43.4ms | 9.9ms                |

Both fixtures generated to the same shape as the small one, four meals a day
over 900 and 1,800 days. 43ms is one build, paid inside the push transition,
not per redraw — and reading the computed property from `body` instead would
have paid it again on every keystroke, which at 15,000 entries is a third of a
second to type "chicken". What a keystroke pays now is the 9.9ms above.

**The snapshot is also what stops the list moving under your thumb.** A repeat
writes a row dated now, which on a recency-ordered list belongs at the very top,
so a live list would push every row down by one on each tap — and logging
breakfast means two taps in a row. The undo bar is what says the tap landed,
exactly as on History. The cost is honest and small: the row you just logged
does not appear until you come back.

### The control on home reads as secondary, and costs the pill 78pt

A bordered glyph square on the **leading** side, `.controlSize(.large)` so the
bar's height does not move: measured **70×51pt against the pill's 292×50** on
an iPhone 17, and 90×82 against 272×93 at AX5. The pill lost 78pt of width and
nothing else — no accent, no word, no second prominent fill. Two equal buttons
were tried first and read as a choice to make on arrival, which is a decision in
front of logging.

Leading rather than trailing because a right thumb rests at the bottom right and
the pill still runs under it; the rarer control takes the further corner. A
first pass set an explicit 30×30 frame on the glyph and made the *secondary*
button 60pt tall against the pill's 50 — a secondary control overhanging the
primary one, which is precisely the competition the shape exists to avoid.

The glyph is `arrow.clockwise`, which already means "log this again" one screen
away on every History row. A word would have cost the pill another 60pt to say
what the screen's own title says.

### Three things that fell out of it

**`Store.recentValues` is deleted.** It has been uncalled since item 11 and was
kept twice: once for item 14, which turned out not to want it, and once for this
item's search, which does not either — it keys on tracker id and ignores names,
and every door onto repeating turned out to be a door onto a name. Its own
comment said to decide here rather than keep it a third time.

**The undo bar is one view now** (`UndoBar`), and the day heading one function
(`DayKey.label(today:calendar:)`). Both screens write through `logAgain` into
one undo slot and both name the same days; a second copy of either is a second
chance for the two screens to word the same thing differently.

**At AX5 the row wraps rather than breaking**, with the date hyphenating to
"Yester-day" beside a name on two lines. Nothing clips and nothing overlaps, and
it is the row shape item 14b already swept and accepted on History — but History
shows a *time* there, which never wraps, and this shows a date. The known remedy
is home's `isStacked` trick, and it is not worth a layout branch on an
experiment.

### What the review changed, and two things it raised that were kept

**The shared undo bar was showing History's deletions here.** A deletion's undo
is deliberately never expired — undoing one only puts records back, so it can go
stale harmlessly — which meant swiping a row away on History and then opening
Repeat pinned "Deleted batch" over a screen that had done nothing, offering to
restore a row it would not then show. The bar takes the repeat half only on this
screen. History keeps both, because the slot survives the trip.

**Tracker detail had a third copy of the day heading**, byte-identical, left
behind by the extraction. It calls `DayKey.label` now, which is what made the
extraction worth doing rather than a lateral move.

**Kept: disabling greys the whole row, where History greys only the disc.**
Here the row *is* the button, so a dimmed row is the platform's own way of
saying the action is unavailable — which is more than History manages, since
item 14 recorded that an archived tracker's row says nothing about why its disc
is off. The alternative is saying "Archived" on the row, which changes what a
row shows and is item 14b's question.

**Kept: a double tap writes twice and only the second is undoable.** True on
History too — one undo slot, settled in item 14 — but the target here is a whole
row rather than a 44pt disc and the list deliberately does not move under it. A
second slot was rejected in item 14 and a confirmation is rejected by the
philosophy, so this is a cost of the wider target rather than an oversight. It
is the thing to watch first if the screen turns out to misfire in use.

### Deduplicated after all, by name and values — done

- [x] Rows sharing **both** a name and its values collapse to one.
- [x] Not by name alone: a bigger portion stays its own row.
- [x] The row kept is the newest one, so its date says when you last ate that.
- [x] Still built once when the screen opens, and re-measured.

The key is the row's typed names and its `(tracker, value)` pairs, both sorted
(`HistoryItem.RepeatKey`). The tracker is part of a value because a number on
its own is not one — 20 kcal and 20 g are not the same log — and a batch of two
is not the same row as one of its members logged alone, because repeating them
writes different things.

On a fresh 56-day fixture of the same shape as the one that found the noise —
four named meals a day, a quarter of them a different portion of the same food —
**224 named rows become 46**, and the 23 rows matching "rice" become **four**:
`620/45`, logged 15 times, plus the three portions `775/56`, `992/72` and
`465/34` that a name-only rule would have hidden behind it, which is the whole
reason the key carries values. Counted over the fixture's own JSON by the same
grouping the app applies, and confirmed on screen in dark mode on an iPhone 17.

**Ordering is frequency, ties broken by recency.** Both were built and
screenshotted on that fixture. Recency spent two of its first fourteen rows on
chicken rice at two portions and opened with four rows all reading "Today" —
the date column says nothing exactly where the list is densest, and a one-off
floats to the top merely because it was yesterday. Frequency's first screen is
thirteen different foods at the portions actually eaten. It is also **stable**:
the top of a recency list moves on every log, so the row tapped every morning is
never twice in the same place. Displayed, so it stays cheap to change again.

Frequency degrades into recency rather than into nonsense, which matters for the
failure mode below: when nothing repeats, every count is 1 and the tie-break is
the whole ordering.

**Re-measured, Debug build on the iPhone 17 simulator, five runs each**, against
fixtures of four named meals and a weight reading a day (`store.json` seeded into
the data container, a temporary probe root and `print`, both reverted before the
commit):

| entries | rows before | build, plain | build, deduped | rows after | one keystroke |
|---------|-------------|--------------|----------------|------------|---------------|
| 7,644   | 3,399       | 15.7–16.4ms  | 20.6–21.1ms    | 61         | 0.08–0.16ms   |
| 15,294  | 6,799       | 31.6–36.7ms  | 41.0–42.4ms    | 61         | 0.09–0.16ms   |
| 15,294† | 6,799       | 32.2–32.8ms  | 49.9–51.0ms    | 6,799      | —             |

† the **15,294-entry** file re-jittered so that no two logs share a number, over
eight trackers: the worst shape there is, where nothing collapses and every row
still pays for the key. Deduplication is about 5ms and 8ms of the first two rows
and 18ms of the third; the rest is `historyItems`, which both columns pay.

Still one build, paid inside the push transition — `RepeatView`
snapshots the list and filters the snapshot, so a keystroke never reaches it.
**A keystroke got cheaper**, from the 5.3ms and 9.9ms recorded above to a tenth
of a millisecond, because there are 61 rows left to filter instead of thousands.
These are not the same fixture files as the 23.4ms / 43.4ms recorded earlier —
generating them again gives 4,248 and 8,498 history rows against that session's
3,597 and 7,197 — so the pair to compare is the plain and deduped columns here,
measured minutes apart on one machine.

**What the review caught, and it is frequency's own bill.** A lifetime count
never falls, so anything that used to sink on its own now stays where it is.
The sharp case was a row that cannot be written at all: archive a tracker — a
supported thing to do — and a year of porridge logged against it would own the
top of the screen for good, a screenful of greyed rows in front of every row
that still works. **A row that cannot be repeated now sorts below every row that
can**, whatever its count, and it stays on the list rather than vanishing,
because item 16 already decided that a screen which drops food when you archive
a tracker is editing your history. A test pins it.

Sorting on that flag meant asking it once per collapsed row, and asking it
resolved each entry's tracker by scanning the tracker list — so the second
review round asked for the set of writable ids to be hoisted out of the walk,
and it is. **Its 14ms figure did not reproduce here**: on the degenerate fixture
the hoist is worth 54.0–56.9ms → 49.9–51.0ms over eight trackers and
56.2–59.3ms → 54.4–55.5ms over three, so 4–6ms rather than 14, and it is kept
for that and for keeping the rule in one expression rather than two.

The soft case is left standing and is the user's call: eat porridge every
morning for a year, switch to overnight oats for a month, and last year's staple
still outranks this morning's, reachable only by search. **A window — count only
the last 60 days, say — keeps the stability argument and drops the museum
effect**, and it is not in because nothing measured says what the window should
be. Displayed either way, so it stays cheap.

**One known limit of the key**: values are compared as stored, not as drawn.
`decimals` is editable, so "rice" at 100.4 and at 100.0 are correctly two rows
on a one-decimal tracker, and setting that tracker to zero decimals afterwards
leaves both reading "rice / 100 kcal" with only their dates apart. Keying on the
formatted string would collapse them, at the cost of making the key depend on a
setting and paying a `Tracker.format` per value on a walk measured in
milliseconds over thousands of rows. Both rows write nearly the same thing, so
the wrong tap is nearly the right log.

**The failure mode is real and now has a number.** Take the same 56 days and
weigh every portion, so the numbers land near the same value and never on it:
jittering each value by ±0.5 kcal takes 224 named rows to **214** rows instead
of 46. Deduplication buys such a person 4% where it buys the fixture 79%, and
what they get is the plain list back — no worse to read than before, and paid
for: the walk still builds a key per row, which is the 18ms in the table's third
line at five years of that data, and a fraction of a millisecond at 56 days.
Nothing here rounds or groups to paper over it: both are design decisions about
what counts as the same meal, and both belong to the user rather than to this
step. Frequency ordering is what keeps the degraded case honest rather than
arbitrary.

## 16b. Search in History too — done

History is the general view of everything logged, and finding something in it
means scrolling. It should be searchable for the same reason item 16 is.

- [x] Search over History, filtering by entry name.
- [x] **Reuse item 16's search rather than writing a second one.** They filter
      the same field of the same records; two implementations would drift, and
      the second one would be the one nobody tests.
- [x] Unnamed entries stay visible when the query is empty — History shows
      everything, unlike item 16's screen, which is only the things you named.
      Decide what an unnamed entry does under a non-empty query and say why.

One `.searchable` and one `where item.matches(query)` inside the grouping that
was already there — `HistoryItem.matches` unchanged, so the two screens cannot
come to mean different things by one query. A day with nothing left in it is
not drawn, so a search leaves no empty headings behind, and a query that
matches nothing gets the system search empty state rather than a blank list.

**An unnamed entry disappears under a non-empty query.** It has no name, and
this searches names. The alternative — matching the identity line too, so that
"weight" found this morning's reading — was refused: that line falls back to a
*tracker* or a *group* for rows nobody named, so "food" would answer with every
meal ever logged in that group, and item 16's screen would have to either
follow or disagree. What stops it being a screen that silently hides half the
log: the field says **"Search names"**, the same words as the Repeat screen, and
an empty result says so with the query quoted back.

Checked on the iPhone 17 in dark mode against a 56-day fixture: with the field
empty the weight readings are on screen among the meals, "rice" leaves day
sections holding nothing but chicken rice — at two portions, since History does
not deduplicate and should not — with the days that held no rice gone entirely
and no weight reading anywhere, and "zzz" draws *No Results for "zzz"*. **The UI was not driven** — the macOS console was
locked for this session, which takes the AX tree and synthesized clicks with it,
so the query was preset through a launch argument on a temporary probe root and
the screens were read from screenshots. Nothing was typed and no row was tapped.

**A keystroke rebuilds the list, which History's every redraw already did.**
Measured in the same probe: **18.0–20.4ms at 7,644 entries and 35.3–36.1ms at
15,294**, of which the filter itself is 4.9–5.7ms and 9.3–9.8ms and the rest is
`historyItems`. Repeat's screen escapes this by snapshotting, and History cannot:
a deletion or a repeat has to show up here immediately. At five years of history
that is a dropped frame or two per keystroke, and the fix — if it ever bites —
is to cache `historyItems` on the store and invalidate it on write, which is a
change to the store rather than to this screen.

Deliberately after item 16, not merged into it: that screen is a new surface
with a placement risk, this is a field added to a screen that already works,
and bundling them would let the harder one drag the easy one.

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

**Pressed states, moved here after three sessions of deferring them.** Item 13
asked for the pressed fill to be checked alongside the disabled one, and every
session since has recorded it as uncaptured for the same reason: pressing a
control in the simulator needs synthesized clicks, which need the accessibility
tree, which a locked macOS console takes away — and the console has been locked
for three reviews running. A thumb has none of that problem.

- [ ] Press and hold each accent-filled control — the two Log buttons, a card's
      +, the repeat disc, Undo — and screenshot the held state.
- [ ] Check the pressed fill against `Color.onAccent` in both appearances. The
      computed answer is that it cannot fail (pressing *lightens* the teal, so
      black on it can only improve), and the recorded `#36E0EB` is from the
      same batch of hexes item 13b has since corrected, so it is a number to
      re-take rather than to trust.

## 18. Asset catalog: the accent, then the icon

Neither exists, and the accent question that 13c, 13d and 13e keep circling is
really a missing asset catalog.

**Define the accent as a colour set with light and dark variants.** One system
hue has to work on both appearances and doesn't: on a nav bar in light mode
this teal measures 2.13:1 where the system blue Apple ships measures 3.89:1.
Apple tuned that background for the hue it shipped, so 13d's carve-out
inherited the shape of Apple's decision without inheriting its number.

That is not an argument for abandoning a system colour for a hand-picked hex.
It is an argument for doing what the system colours themselves do: **two
deliberate values, one per appearance.** A darker teal in light, the current
bright one in dark — the mode this app is actually used in, and the one that
already works.

- [ ] An accent colour set, light and dark variants, measured on both.
- [ ] It resolves **13e** in passing: `Form` buttons, `.alert` and
      `.confirmationDialog` all take the tint, including the import's
      *Merge / Replace Everything…* dialog. 13e now carries the numbers this
      has to beat — a tinted form row is **9.57:1 dark and 2.12:1 light** — and
      the note that the tint reaches the row's text but not its icon.
- [ ] Then the app icon.

## 18b. Get the export into the share sheet — done

**The cheap fix was the whole fix, and no UIKit was written.** Export and import
are now two sections, the confirmation dialog belongs to the import one, and a
plain `ShareLink` presents from the export one. `UIActivityViewController`, the
window hierarchy and the app's first UIKit are all still not here.

- [x] Try the cheap fix first: give the confirmation dialog a different host.
- [x] JSON and CSV both go through it, under the dated name.
- [x] The Files exporter still works, as its own row.
- [x] Recorded next to the code and in docs/TECH.md.

**Reproduced before it was fixed, which is the half that gets skipped.** With
the rows in one section, a `ShareLink` carrying the real export did nothing on a
synthesized tap while *Import JSON* beside it opened the file importer on the
same tap — so the control was dead, not the input path. Splitting the sections
was the only change between that build and the one where the sheet presents.

**Driven to a destination rather than to a sheet.** Share JSON → Save to Files →
On My iPhone wrote `boring-tracker-2026-08-17.json`, 5,300 bytes, and it is
`diff`-identical to the app's own `store.json`; Share CSV wrote
`boring-tracker-entries-2026-08-17.csv` with the header row and one row per
entry. *Save JSON to Files…* then offered the same name in the same folder and
iOS asked whether to replace it — which is the Files exporter still working, and
a free check that both doors write the same name. Importing the shared file back
merged to "Added 0 trackers and 0 entries", the no-op an export of your own
document should be.

**What the share sheet is handed is a `Transferable` carrying the document, not
the bytes** (`ExportFile`). A `ShareLink`'s item is rebuilt on every body pass —
including during a reorder drag — so encoding there would encode the whole
document per frame; `StoreDocument` is a struct of arrays, so carrying one is a
retain, and the encode happens in the representation once a destination is
chosen. One representation typed `.data` rather than one per format: the
representation is static and cannot ask an instance what it is, so declaring
both would let a receiver asking for JSON be handed a CSV. The extension carries
the type, which is what sharing a file URL has always done — Reminders offered
itself for the CSV and not for the JSON, so receivers do read it.

The layout is now four export rows: *Share JSON…*, *Share CSV…*, *Save JSON to
Files…*, *Save CSV to Files…*. **That is one more row than strictly needed and
it is a judgement, not an oversight** — the share sheet contains "Save to Files"
already, so the last two are a second route to the same place, kept because the
scheduled export to the same folder is the one people repeat and the share sheet
costs a tap to get there. If it reads as clutter, deleting the two Files rows is
a two-line change and the exporter goes with it.

---

Found in `531d71c`. **`ShareLink` silently fails to present from settings' Data
section** — no sheet, no error — while a `Button` in that same section works on
the same tap.

**It was decided as "do it in UIKit", and that decision is suspended, because
the fact it rested on is not true.** The cause recorded in `531d71c` was the tracker editor's
`.sheet(item:)`; it is actually `.confirmationDialog` on the Data section —
measured eight ways, table in the small-things item below.

That matters because "there is no way to do this in SwiftUI" was the whole
argument for the app's first UIKit, and it is now unproven: the blocker is one
modifier on one section, so **moving the import chooser off that container may
be the entire fix**, at no UIKit and no window-hierarchy reach. It may also not
work, and nobody has tried it. Whoever picks this up **tries that first** and
only then writes the bridge.

The UIKit case, if it comes to that, is unchanged and still good: about fifteen
lines. Rule 10 bans *dependencies* and explicitly permits platform frameworks,
and rule 6 promises data leaves in one tap, where Files-only means save, find,
then share. `UIActivityViewController` presented by hand from that screen was
probed and does work.

The cheap fix was tried first and it worked, so the bridge was never written and
this paragraph is the case that was never needed. The checklist for this item is
at the top, ticked.

## 18c. One export door, not two — done

The share sheet already contains *Save to Files*, so keeping the Files exporter
beside it gave the export section four rows and two routes to the same place.
The argument for keeping it was that a repeat export to the same folder is one
tap cheaper — but export is not the common path, and this app does not spend
four rows to save a tap on something done monthly.

- [x] Both `Save to Files` rows removed; `Share JSON…` and `Share CSV…` remain.
- [x] The whole `.fileExporter` path went with them — state, modifier, three
      functions, and `ExportDocument`, which nothing else used. Dead code kept
      alive by one caller is how a small app stops being one.

## 19. CI

GitHub Actions build + test on push. Cheap, and the test suite is already good
enough to be worth protecting.

Moved to the end deliberately. CI protects a shared branch from contributors
who don't exist yet — the suite already runs on every change because every
session runs it, so until this repo has someone else pushing to it, CI buys
reassurance rather than safety.

## Noted, not scheduled

Wanted, not yet queued. Written down with the part that isn't obvious, so
picking one up doesn't start with rediscovering why it's awkward.

- [ ] **Appearance switch in settings — light / dark / system.** Ordinary
      `.preferredColorScheme` driven by a stored preference. It is **UI state,
      so it lives in `UserDefaults`, not the document** — it must not sync or
      appear in an export. iOS offers a per-app setting too, but in-app is more
      discoverable and there is no reason not to have both.

- [ ] **A configurable time for the daily reset.** Note that this **reverses a
      decision recorded in TECH.md** ("the day starts at midnight, local. No
      configurable day start; it multiplies edge cases in every aggregation for
      a minority want"). That is allowed — the reason was cost, not principle,
      and a person who eats at 1am is not a minority of one here.

      The cost is lower than it was written to be: entries store absolute
      dates, so a day-start offset is a **displayed** decision computed at read
      time, with no schema change and no migration. What it does touch is
      everything that derives a day — `DayKey`, totals, charts, History
      grouping — and every day-boundary test, including the DST ones. Cheap in
      storage, expensive in surface area.

- [ ] **An About screen, with a link to the repository.** Apple permits linking
      out to a website; the rule is about external *purchase* mechanisms, which
      this isn't. Worth having once the repo is public, because for the people
      who care about this app's promises the source is the proof — that
      argument is already in SHIPPING.md's listing strategy.

- [ ] **A subtle "add tracker" at the end of the home list.** Worth trying to
      see how it looks. The thing to watch: home already has a bottom Log
      button, and a second control down there competes with the most frequent
      action in the app. Inline at the end of the list, scrolling with it,
      rather than pinned above it.

## Small things, unscheduled

Real, small, and not worth a session each — the overhead of reading the docs,
testing and reviewing dwarfs the work. **Do them in one pass**, whenever one of
the numbered items is going near the same code.

- [x] **Export through the share sheet.** Done in item 18b: export and import
      are two sections now, the confirmation dialog went with import, and a
      plain `ShareLink` presents. No UIKit. The bisect below is what made that
      one-line-of-structure fix findable, and it stays for the same reason the
      wrong diagnosis above it does. Original note, unchanged:

      A `ShareLink` gives AirDrop,
      Messages, Mail and any app that takes a file, with Files still among
      them. About three lines. **It is not three lines, and the three-line
      version does not work at all** — see below. The *dated name* half is
      done: both exports are offered as `boring-tracker-2026-08-16`, verified
      by saving one into Files.

      **`ShareLink` does not present from the Data section.** Tapping it does
      nothing — no sheet, no log line, no error. A `Button` in the same section
      works on the same synthesized tap, so it is the control and not the input
      path.

      **The cause is `.confirmationDialog`, not `.sheet(item:)`**, and the
      first diagnosis had it wrong. Re-bisected on an iPhone 17 / iOS 26.3 by
      putting a probe `ShareLink` into the real screen — not a model of it —
      and building it eight ways:

          Data section, as shipped                        silent
          Data section, editor `.sheet(item:)` removed    silent
          Data section, `.fileExporter` removed           silent
          Data section, `.confirmationDialog` only        silent
          Data section, every presentation stripped       presents
          Data section, `.alert(item:)` only              presents
          Data section, `.fileImporter` + `.alert`        presents
          *Add Tracker* section, `.sheet` still attached  presents

      So `.confirmationDialog` on the same container is enough on its own, and
      that dialog is the import merge/replace chooser. The `.sheet(item:)`
      reading is disproved three ways: removing the tracker editor's `.sheet`
      does not bring the ShareLink back, a probe two sections up presents while
      that `.sheet` is still attached, and a 40-line throwaway app pairing a
      `Form`, a `.sheet(item:)` and a `ShareLink` — the shape the original
      bisect describes — presents every time. **A minimal repro that does not
      reproduce is evidence about the repro**, which is how the wrong modifier
      got the blame.

      What is left is a decision rather than a fix, and the corrected cause adds
      an option that was not on the list when it was taken: **host the
      confirmation dialog somewhere else** and see whether a plain `ShareLink`
      then presents. Failing that, present `UIActivityViewController` directly
      (about fifteen lines and the app's first UIKit, and it does work from that
      screen — probed), move the export rows out of the settings list, or leave
      the Files exporter alone. Not taken here, because a small-things pass is
      the wrong place to add the first UIKit bridge. See item 18b.
- [x] **XcodeGen churns `TEMP_…` UUIDs on every regenerate.** Fixed by moving
      `Signing.xcconfig` into `Config/`. With `createIntermediateGroups` on, a
      config file beside `project.yml` makes XcodeGen build a group for the
      *containing directory* to hold it — a group named after whatever the
      clone is called, and one nothing ever gives a deterministic id, so it and
      the file reference came out as fresh `TEMP_<uuid>`s and five lines of the
      committed `.xcodeproj` changed every run. Any subdirectory ends it; two
      regenerates in a row are now byte-identical. See docs/TECH.md.
- [x] **`validateImport` never looks at a tracker's name.** It checked ids,
      `decimals` and `sortIndex`, so an imported or hand-edited file could carry
      `"name": ""` — and a nameless tracker draws a blank card on home, a blank
      row in settings, and a blank identity line in History, which the last of
      those documents itself as the one thing it cannot promise. Now one check
      beside the others: a name that is empty **after trimming whitespace** is
      refused at the import boundary, naming the tracker's id so the file can be
      fixed.

      **Refused rather than repaired**, which was the choice. A repair — falling
      back to "Untitled" — rewrites a record the user never edited and stamps it
      as an edit, and the merge then carries that invented name to every other
      device; the blank row is at least honest about being a blank row. Refusing
      also matches what the app itself can produce: `TrackerEditor` trims and
      will not save an empty name, so no document this app has ever written can
      fail this check. Two tests, an empty name and a whitespace-only one.

      **It sits beside `validateImport` rather than inside it, because
      `restoreImportBackup` runs that one too.** The recovery slot holds a
      document this app wrote out of its own memory, and loading a local file is
      deliberately tolerant, so a hand-edited store file can put a blank name in
      there — and refusing it on the way back would disable the one action that
      undoes a destructive import, over a row that is only blank. The checks
      around it earn their strictness on both paths, being about merges that
      stop converging and formatting that crashes. A third test holds that line.
- [x] **`(max ?? -1) + 1` traps on `Int.max`.** Already fixed, in `a1c42a5`
      (item 10): `Store.add` renumbers the whole list when the largest index is
      within one of `Int.max`, and `validateImport` rejects the value at the
      import boundary outright. What was missing was a test for the value
      arriving the way import cannot stop it — in the store file this device
      wrote — so there are now two, and with the guard removed the first one
      kills the test process rather than failing an expectation, which is what a
      Swift overflow does.
- [x] **The log sheet has no signposted exit** since Cancel was removed. Swiping
      down works and nothing advertises it; `.presentationDragIndicator(.visible)`
      bought it back for one line, on the `NavigationStack` rather than the
      `Form` because it is a property of the presentation. Item 12 was the thing
      it waited on and item 12 was reverted, so the standard sheet is what
      ships. It costs nothing: against the same build without it, on an
      iPhone 17, the only rows of the screenshot that differ are the grabber's
      own 15px and the clock inside the *When* row, which moved because the two
      runs were minutes apart. The title, the fields, the keypad and the Log
      bar are pixel-identical.
- [x] **Releasing a settings drag outside the list commits it** rather than
      cancelling. Deliberate, and now written down: a comment at the gesture and
      a line under Screens in PRODUCT.md. Both halves were reproduced on an
      iPhone 17 first, against the list's measured 116…840pt band: releasing at
      866 moved the dragged block to the end, releasing at 54 (inside the
      navigation bar) put it on top.

      **The reason first recorded here was wrong and has been corrected.** It
      said requiring the finger inside would break dragging to the top edge to
      reach the first row. Measured from the frames the drop code reads, the
      first row is 166…210 inside a 116…840 band, so 116…254 already picks it
      without leaving the list — driven at 150, which landed on the first row.
      The real reason is tolerance: `row(nearest:)` answers at every y, so a
      refusal would disambiguate nothing, and it would throw away a drag
      released a few points past an edge the finger cannot see.

## After v1

- [ ] Home screen widget, Lock Screen widget, App Shortcuts / Siri.
- [ ] Sync transport — the document already merges; this is only plumbing.
- [ ] Apple Watch.
