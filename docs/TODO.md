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

A **done item is one line and its commit SHA.** How something was done is in
its commit message, and the same paragraph in two places means one of them goes
stale without anyone noticing. The exception is a *durable decision* — something
still true about the app that a future reader needs — which moves to
[PRODUCT.md](PRODUCT.md) or [TECH.md](TECH.md) first, in that doc's voice, and
then the item collapses like any other. Nothing is deleted that does not already
exist somewhere else.

Item 12 is deliberately not collapsed: it records a thing that was built,
measured and reverted, and its length is what stops someone trying it again.

## 1. Settings screen and tracker editing — done

Settings, the tracker editor, and both deletions labelled apart. `d6520b2`

## 2. Schema changes, all at once — done

`group`, `name` and `batchID` added, `Pin` deleted, and `sortIndex` given its
own timestamp, at schema version 2. `d6520b2`, `719eac9`

## 3. The group log sheet — done

One sheet per log group, opened straight into the last-used one with the keypad
up and nothing in front of it. `a401c5b`

## 4. Terminology pass — done

Renamed the old grouping term to *group* everywhere, and stopped a row's
position on a screen doubling as its membership. `0862976`

## 5. Log sheet polish, from first real use — done

*Save* became *Log*, the presentation animation went, and the confirm moved
from the nav bar to directly above the keypad. `8cbbe54`

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

Everything logged, newest first, grouped by day, with a batch drawn as one row.
`8b8e17c`, `e2acc99`

## 10. Export, import, CSV — done

JSON and CSV out, JSON back in, with merge or replace stated before it happens
and the replaced document kept. `a1c42a5`

## 11. Home density and log feel, from real use — done

Home's cards cut from 118pt to 64pt, a card's + given the Log button's idiom,
and the recents row removed. `0564080`, `3248a86`

The sheet still cannot rise with the keyboard; why not is in TECH.md, and item
12 is what answered the complaint instead.

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

One title treatment, a readable tracker name, a uniform History row, and the
blue replaced by a teal. `6649952`

## 13b. Dark labels on the teal — done

A black label on every accent fill, in place of the white one iOS draws
whatever the tint. `b01fe00`

## 14. Log it again, from History — done

A repeat button on every History row, writing a new batch through the one code
path, with a single undo slot in a bar at the bottom. `08edf17`, `ff0da3d`

## 13c. Teal is a fill, not a text colour — done

The accent stopped being the root tint, and seven foreground uses of it became
the ordinary label colour. `12ae4b0`

## 14b. Put the name first, still grey — done

The name leads a History row and the numbers follow, through one shared
identity line. `e62a599`, `bce288a`, `437cfac`

## 13d. Give the nav bar its tint back — done

The accent restored on nav bar buttons alone, named per button rather than
inherited. `5aa96bf`

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

`Color.accentFill` swapped from teal to `Color(.systemMint)`, at one constant.
`6f8cb2f`

## 15. Make a save feel like it landed — done

The card's number rolls from the old value to the new, and nothing waits on it.
`776939e`

## 16. Repeat: a screen of things you have eaten — done

A searchable screen of the things you have logged and named, deduplicated by
name *and* values, one tap each to log again. `fd09535`, `ce5de86`, `d71580f`,
`9b1ba61`

## 16c. A 60-day counting window on the Repeat list — done

The frequency count reaches back 60 days instead of over all history, so a
staple you gave up stops outranking this month's breakfast — without dropping a
row from the list. `90dda62`

## 16d. Lifetime count as a second tie-break on the Repeat list — done

`6d33fe8`

Between the 60-day count and recency, so a staple having a quiet spell beats
something new on the same small window count, and the window still decides
first. The rule is in PRODUCT.md; what it moved on a real diary, and what it
cost, are in the commit message.

## 16b. Search in History too — done

One `.searchable` over History, filtering through item 16's matcher rather than
a second one. `38f6b85`

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

Export and import split into two sections, so a plain `ShareLink` presents and
no UIKit was needed. `dd25193`

## 18c. One export door, not two — done

Both *Save to Files* rows removed, and the whole `.fileExporter` path with
them. `35a5fd0`

## 19. CI

GitHub Actions build + test on push. Cheap, and the test suite is already good
enough to be worth protecting.

Moved to the end deliberately. CI protects a shared branch from contributors
who don't exist yet — the suite already runs on every change because every
session runs it, so until this repo has someone else pushing to it, CI buys
reassurance rather than safety.

## 20. Five things from using it — done

All from real use, all on screens looked at daily, and all separate commits.

- **"Repeat" became "Log again"** — the screen's title and home's accessibility
  label; the home control stays a glyph. `e91208c`
- **History's delete swipe got its word back**, and its red: the root
  `.tint(.primary)` reaches a swipe action, so `role: .destructive` drew as a
  blank white capsule with no glyph and no label. `9dbb6c7`
- **Log again is a sheet now, not a pushed screen** — half height over home,
  one tap on a row logs and dismisses. The undo moved to home with it, since
  the presentation that wrote the thing is gone by the time you would reach for
  it. `1116942`
- **The number counts up over 0.8s** instead of rolling its digits over 0.3s,
  and the sheet still dismisses in +359–360ms, unchanged. `c7f48dd`
- **The row a repeat writes arrives marked**, in the accent at a fifth, and the
  mark fades out on its own about 2.9s later. `e5a1b42`

What the two performance claims are worth is in docs/TECH.md rather than here:
the list is still built once when the sheet opens (re-measured, and counted),
and the counting animation delays nothing (three runs against a build without
it).

## 20b. Make the undo offers agree

Item 20 gave home's undo offer a ten-second life. History's still never
expires, so the same bar behaves differently depending on which screen wrote
it — and a bar that never leaves stops meaning *just now*, which is the only
thing it was ever saying.

- [ ] History's undo offer expires like home's.
- [ ] Both read their expiry from one place. Two screens with the same ten
      hard-coded twice is how they drifted in the first place.

**Not doing: undo on the Log sheet.** Item 20 noticed the asymmetry — logging
again offers undo, logging does not — and it is deliberate rather than an
oversight. **Undo exists where a single tap writes data without confirmation.**
Tapping a row is easy to do by accident; typing a number and pressing Log is
not, and a mistyped number is already fixable by editing the entry you are
looking at. Adding undo to a deliberate action buys a control nobody needs and
makes the one that matters less distinct.

Left alone, recorded rather than fixed: a long tracker name re-truncates
mid-count when the total crosses a grouping boundary (950 → 1,050). `minWidth`
was tried in that file before and reverted, for the common short name.

## 21. Repeatable is about the tracker, not the name

Two things from use.

- [x] **The Log again button is a different colour on home and in History.**
      Same action, same accent, two answers. Fix it, and check every other
      place that action appears while you are there.

      Three places, not two: home's bottom bar, a History row, a Log again row.
      The third one **agreed** — the sheet's disc was copied from History's, and
      copying is what kept them the same rather than anything structural. Home's
      was the outlier and the app's only `.buttonStyle(.bordered)`: a grey square
      with a white glyph, against two accent discs with a black one.

      All three are `RepeatDisc` now, one view, beside `UndoButton` — which
      exists because the same thing happened to Undo in item 13c. Home's stays
      secondary on size and shape, which is what item 16 was actually protecting;
      it never needed a colour of its own. Its 70pt-wide target is kept, so the
      Log pill does not move.

      **The glyph gained a plus**, so it reads as logging rather than only as
      repeating: `plus.arrow.trianglehead.clockwise`, one native symbol rather
      than a plus composited onto `arrow.clockwise`. There is no `.badge.plus`
      variant to prefer — of the 64 `.badge.plus` symbols in iOS 26.3's
      CoreGlyphs not one is an arrow, a clock or a rotate — and this is the only
      symbol in the set that pairs a plus with a clockwise arrow. iOS 18.0,
      which is the deployment target.

- [ ] **Log again lists named entries, and that is the wrong filter.** A name
      is not what makes something repeatable — the tracker's **kind** is.

      A **daily total** can be logged again: you can eat 450 kcal and 30 g
      again whether or not you called it anything, so an unnamed one belongs
      in the list and is currently missing from it.

      A **measurement** cannot. Repeating yesterday's weight is meaningless —
      you would measure again, not copy. Nothing measurement-kind belongs
      there however carefully it was named.

      So the rule becomes kind-based, and the list gains the unnamed daily
      totals it was wrongly hiding. An unnamed row shows its values, which is
      what identifies it.

      **This is instead of a "show all" toggle.** A toggle would make Log again
      into History with a filter, which is the direction that blurs them; the
      right rule does the work without a control.

### Why History and Log again stay separate

They answer different questions, and merging them makes one screen worse at
both. **History is "what did I do"** — chronological, everything, where you
review and fix and delete. **Log again is "do that again"** — deduplicated,
ranked, one tap and gone. Sharing a search and a repeat action is fine; sharing
a screen is not.

## 22. Say that a History row can be tapped and swiped

Neither affordance announces itself. Swipe-to-delete is invisible by design in
iOS, and tapping a row to edit is invisible too — both are discoverable only if
you already know the platform, and one of us wondered aloud whether they were
findable, which is the evidence.

- [ ] A quiet footer saying both: a row can be **tapped to edit** and **swiped
      to delete**. One line, label-secondary, no icon.
- [ ] Put it where it is actually seen — under the first day's section, not at
      the bottom of a list that may be a year long.
- [ ] Same question for the Log again sheet: check whether anything there is
      similarly silent, and say so rather than assuming History is the only
      screen with this problem.

It costs no tap and it is the ordinary iOS idiom — the app already uses footers
this way on the log sheet. A hint that never moves is cheaper than a gesture
nobody finds.

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
