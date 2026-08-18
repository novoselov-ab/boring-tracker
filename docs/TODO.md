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

## 6. Make settings and home agree — done

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

## 7. Put home's + in the thumb — done

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

## 18. Measure mint in light, then the icon

**Rewritten — its old premise is gone.** This item argued that the accent had
to become a colour set with light and dark variants, because one system hue
could not serve both appearances: the teal measured 2.13:1 on a light-mode nav
bar where the system blue Apple ships measures 3.89:1.

That teal no longer exists. Item 13f replaced it with a mint, chosen from
twelve candidates measured on the real screens — **but that comparison was
dark-mode only**, at the user's direction, because dark is what this app is
used in.

So the question is open again, and it is now a smaller one:

- [ ] **Measure mint in light mode**: as a nav bar tint, as a `Form` button
      foreground (that is item 13e, still unresolved and waiting on exactly
      this number), and as a fill behind a dark label.
- [ ] **If it clears 3:1 in light, there is no colour set to build.** Say so,
      tick 13e, and this item becomes the app icon alone. "The thing we already
      have works in both" is a result.
- [ ] **If it fails light, build the colour set**: a darker mint for light, the
      current one for dark. Two deliberate values, one per appearance, which is
      what the system colours themselves do — not a hand-picked hex replacing a
      principled choice.
- [ ] Then the app icon.

The reasoning that survives from the old version: a single hue serving two
appearances is a real constraint, and where it binds, a colour set is the
answer rather than abandoning system colours. It simply may not bind here.

## 18b. Get the export into the share sheet — done

Export and import split into two sections, so a plain `ShareLink` presents and
no UIKit was needed. `dd25193`

## 18c. One export door, not two — done

Both *Save to Files* rows removed, and the whole `.fileExporter` path with
them. `35a5fd0`

## 19. CI — done

Build, the whole test suite and an `xcodegen` drift check on every push, pinned
to Xcode 26.3 and with no third-party actions. **Both gates were proven to
fail** before it landed rather than assumed: breaking `DayKey.adding` turned
the run red after 6m15s, and drifting `project.yml` from the committed
`.xcodeproj` turned it red in 13s — the regenerate check runs first and fails
fast, so a stale project is caught before six minutes of simulator time is
spent. `267cc4f`

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

## 20b. Make the undo offers agree — done

Item 20 gave home's undo offer a ten-second life. History's still never
expires, so the same bar behaves differently depending on which screen wrote
it — and a bar that never leaves stops meaning *just now*, which is the only
thing it was ever saying.

- [x] History's undo offer expires like home's.
- [x] Both read their expiry from one place. Two screens with the same ten
      hard-coded twice is how they drifted in the first place.

      The place is `UndoBar.repeatOffer`, and the expiry moved into `UndoBar`
      with it — the predicate and the sleep both, since the bar is already the
      one view both screens draw. Home kept the ten and History kept none, so
      the fix was not to give History a copy of home's timer but to stop home
      owning one: home now answers only *whose* write it is, which is a question
      about the screen, and `UndoBar` answers *how old*, which is a question
      about the write. It is a net deletion on home — a constant, a `.task` and
      half a predicate.

      **The deletion offer is not expired, deliberately, and that is the one
      asymmetry left.** The two undos are not the same kind of thing: undoing a
      repeat *removes* entries by id, so an offer that outlives its write
      destroys data, which is why it expires. Undoing a deletion only puts
      records back — and it is the only way back from the app's one destructive
      gesture, since a swipe takes a row with no confirmation and nothing else
      restores it. Expiring it would trade a stale but harmless offer for data
      gone for good eleven seconds after a wrong swipe. `Store.forgetRepeatUndo`
      already recorded half of this reasoning at the model layer.

      Verified in the simulator, dark mode, the way item 20 verified home's:
      screenshots of History at +2s (bar reading "Logged again", the new row
      still marked), +7s (bar there) and +15s (bar gone, mark faded), and of
      home at +3s and +15s — the bar goes and the Log pill sits exactly where it
      does with no bar, so the safe-area inset collapses cleanly rather than
      leaving a gap. A deletion at +15s still offers its Undo, which is the
      asymmetry above holding. The screen was locked, so this was driven by a
      launch-argument probe root built in a throwaway worktree rather than by
      tapping; the write and the delete were made from the probe's `task`.

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

## 21. Repeatable is about the tracker, not the name — done

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

- [x] **Log again lists named entries, and that is the wrong filter.** A name
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

      Done: the filter is `HistoryItem.isRepeatable(kinds:)` — renamed
      `belongsInRepeatList` by item 23, which split the question it answers from
      the one a control asks. Three things it
      decided that the item did not say:

      **A batch that mixes kinds is not listed.** One tap writes every member a
      row can write, so a "weigh-in breakfast" of 200 kcal and 79.2 kg would put
      a weight nobody took into the history to save retyping the calories.
      Refusing the whole row is the conservative direction, and it costs nothing
      that is gone — the row is still in History, which is the screen for a row
      you want to act on one member of. The app produces this shape on its own,
      whenever a measurement shares a log group with a daily total.

      **A row whose trackers were all deleted drops out**, where item 16 kept it
      greyed. A deleted tracker has no kind left to read, so it can neither
      qualify a row nor veto one, and the row can never be written again either.
      Archiving is untouched and still keeps the row: an archived tracker is
      still a record with a kind, so those rows stay listed and sink to the
      bottom, greyed, which is what item 16 was actually protecting.

      **A query still matches names only, so any query empties the unnamed rows
      out of the list.** The field says "Search names" on both screens and this
      is it doing what it says; falling back to tracker names would answer a
      different question and return every unnamed calorie row for "calories".

      Timing, in a Debug build on the iPhone 17 simulator, the two filters
      alternating in one binary over fixtures of four named meals, two unnamed
      totals, a water and a weight a day: **19.0–20.2ms against 17.5–19.5ms over
      7,644 entries and 38.1–40.0ms against 34.7–37.3ms over 15,288**. On the
      shape where nothing collapses — 3,822 rows against 2,184 — **23.8–26.0ms
      against 20.2–22.6ms** and **48.3–49.4ms against 40.8–42.2ms**. A list about
      twice as long costs 2–8ms, paid once when the sheet opens.

### Why History and Log again stay separate

They answer different questions, and merging them makes one screen worse at
both. **History is "what did I do"** — chronological, everything, where you
review and fix and delete. **Log again is "do that again"** — deduplicated,
ranked, one tap and gone. Sharing a search and a repeat action is fine; sharing
a screen is not.

## 22. Say that a History row can be tapped and swiped — done

Neither affordance announces itself. Swipe-to-delete is invisible by design in
iOS, and tapping a row to edit is invisible too — both are discoverable only if
you already know the platform, and one of us wondered aloud whether they were
findable, which is the evidence.

- [x] A quiet footer saying both: a row can be **tapped to edit** and **swiped
      to delete**. One line, label-secondary, no icon.

      "Tap a row to edit it, or swipe to delete." One sentence, in the plain
      footer style, which is already secondary — no icon and no colour, because
      anything louder competes with the rows for the same glance. "Swipe", not
      "swipe left": the gesture is on the trailing edge, which is the other side
      in a right-to-left layout, and the word buys nothing the gesture does not
      already teach on the first try.
- [x] Put it where it is actually seen — under the first day's section, not at
      the bottom of a list that may be a year long.

      Under the first section only, not under all 365 — repeating it every day
      would be the app nagging.
- [x] Same question for the Log again sheet: check whether anything there is
      similarly silent, and say so rather than assuming History is the only
      screen with this problem.

      **Checked, and it does not have this problem.** Its rows have one gesture
      and it is drawn: every row carries the repeat disc, which is the same
      glyph home's bar and History's rows use, and the whole row is that button.
      A footer would explain what the disc already says, in a sheet that opens
      at half height where a line of text costs a row of list. The drag
      indicator says how to leave.

      **What is silent there is not a gesture but the search.** Since item 21
      the list carries unnamed rows, and the field matches names only, so typing
      anything empties them out of it. The prompt says "Search names" and that
      is the honest reading of it, but a row you can see and cannot search for
      is a real edge — recorded here rather than fixed, because a fallback to
      tracker names would return every unnamed calorie row for "calories" and
      answer a different question from the one the field asks.

It costs no tap and it is the ordinary iOS idiom — the app already uses footers
this way on the log sheet. A hint that never moves is cheaper than a gesture
nobody finds.

## 23. History's disc still repeats a weight — done

Item 21 settled that repeating a measurement is meaningless — you would take a
new reading, and a copy writes one nobody took — and it enforced that in exactly
one place: `Store.repeatItems`, which is the Log again list. **The action itself
never learned the rule.**

So on History, the disc beside "morning / 79.2 kg" is live, and one tap writes a
weight entry dated now. Home's Weight card reads `latestEntry`, so it shows the
copied number as today's reading with a "just now" caption, and the chart gains
a point that never happened. Found by review, not by use.

The mixed-kind batch is the sharper case, because it is the one item 21 refuses
to list *for this reason*: a "weigh-in" of 200 kcal and 79.2 kg is hidden from
Log again because one tap would write a false weight, while the disc on that
same row in History writes both. One rule, two answers, in the same app.

- [x] **Closed at the choke point, not at the control.** `Store.repeatTargets`
      — the set `repeatableEntries` filters a row against — drops measurement
      trackers now, beside the deleted and archived ones it already dropped. So
      `logAgain` writes only what may be written, and every caller of it
      inherits that without knowing the rule exists.

      **Why not the control.** Disabling the disc on any row
      `HistoryItem.belongsInRepeatList` rejects reads more simply, but it
      refuses the whole weigh-in row rather than only its weight, and it leaves
      `logAgain` willing to write a measurement for whatever calls it next. At
      the choke point the rule lives beside the kind, in one place, and the
      weight-only row still greys its disc — because `repeatableEntries` comes
      back empty, which is the same call that decides the write. The greying is
      a consequence of the rule rather than a second copy of it.

      **`isRepeatable` is now `belongsInRepeatList`**, because after this the
      name asserted something false: a live weigh-in batch is rejected by it and
      `logAgain` writes the batch's calories all the same. The trap the old name
      set is the next control to be wired up — a swipe action, a Shortcuts
      intent — guarding on it and refusing the whole row, which is the "at the
      control" shape this item turned down. What a control asks is
      `repeatableEntries`.

      A weigh-in of 200 kcal and 79.2 kg writes the 200 kcal and says **"Logged
      1 of 2 again"** — the wording archived and deleted members already had,
      reused rather than a second phrasing invented for this. Home's Weight card
      and the chart are clean afterwards: the scale still holds exactly the
      reading it had, at the time it was taken, so nothing shows as today's
      reading and no point is drawn that never happened. Undo takes back what
      the tap wrote, which is now sometimes fewer entries than the row displays.

- [x] **The mixed row is still hidden from Log again, and item 21's reason for
      hiding it has gone.** It was that one tap would write a false weight to
      save retyping the calories; the tap now writes the calories alone, so that
      objection is spent. What keeps the row out is no longer the write but the
      list.

      **Measured before deciding**, by listing them and counting: a row on that
      screen is `repeatKey`, and the key holds every value the row carries —
      including the weight, which is different every morning. Thirty daily
      weigh-ins of the identical 200 kcal breakfast list as **thirty rows**,
      each drawing a weight it would not write, and a plain 200 kcal logged
      without the scale makes a thirty-first rather than joining one of them.
      That is History with a search field, which is the one thing this screen
      must not become (see "Why History and Log again stay separate" above).

      So the honest answer is that the two screens still differ, and the
      difference is now only about *listing*: what a tap writes is one rule with
      one answer everywhere, which is what this item existed to fix.

      **The design problem underneath, for whoever picks it up:** a Log again row
      is built from what the batch *holds*, and the screen promises what a tap
      *writes*. Those were the same thing until this item, and the fix is to
      build the row from the writable members — which collapses the weigh-in
      breakfast onto the plain one, gives the row a value line it will actually
      write, and makes the "1 of 2" wording differ by screen (from History the
      tap skipped a member you could see; from Log again it did not). That is a
      change to what a row on that screen *is*, and it wants its own item rather
      than a rider on this one — queued in "Noted, not scheduled" below so that
      closing item 23 does not close it too.

      **Two things review raised and this item deliberately did not change**,
      because the brief settled both and they are questions about what a screen
      *says* rather than what a tap *writes*. Recorded rather than argued:
      a weight row's disc is now permanently greyed with nothing on the row
      saying why — and unlike the deleted case, which prints "Deleted tracker",
      the tracker is live and on home; and "Logged 1 of 2 again" is now most
      often produced by a weigh-in whose trackers are both live, which is a
      cause the sentence cannot express. Both are in the noted list below.

## 24. Delete everything, recoverably — done

There is no way to start over without deleting the app. Settings should offer
it, beside export and import where the other whole-document actions live.

**Make it recoverable rather than ceremonious.** The instinct is a stack of
confirmations, and confirmations are a poor defence: people learn to tap
through them, and the third one protects nothing the first did not. Import's
`replace` already solves this properly — it writes the current document to a
restorable copy *before* destroying anything, and offers *Restore Data Before
Last Import*. Clearing everything is the same action with a smaller argument.

- [x] Write the same pre-clear copy first, through the mechanism replace
      already uses, and let the existing restore path cover it.
- [x] **One confirmation, naming what goes.** Not "are you sure" — say the
      count: *"Delete 5 trackers and 1,247 entries?"* A number is what makes
      someone stop; a generic warning is what they tap through.
- [x] Destructive styling, and it is not the default button.
- [x] Say in the dialog that it can be undone from Restore, because that is
      the fact that makes the decision safe to make.
- [x] Export offers to run first if there is anything to lose — a suggestion,
      not a gate.

`Store.clearAll` is `applyIncoming(StoreDocument(), mode: .replace)` — the
import transaction with a smaller argument, not a second copy of it. So the
drained save queue, the staged copy committed only once the empty document is
durable, and the restore row all arrive for free, and the confirmation is the
only thing that had to be written.

**Five things this turned up that the item did not say**, three from building
it and two from the review.

The restore row was called *Restore Data Before Last Import…*, and a clear
fills the same slot — so after clearing, the one action that undoes it offered
to undo an import instead. Renamed to **Restore Previous Data…**, which is what
the alert it raises has always called itself.

**No tombstones for what goes**, inherited from `replace` rather than decided
again, and now held by a test. A tombstone per record would have made "start
over" leave a file as long as the history it removed — 29,756 of them after
five years (docs/scale.md) — for the six months `tombstoneLifetime` keeps a
deletion. The cost is `replace`'s cost: merge an older export afterwards and
the data comes back.

**Export is offered in words, not as a button.** A `ShareLink` cannot be an
alert action, and presenting the share sheet from code would be this app's
first UIKit bridge — turned down for the same reason in item 18b. The Export
rows are two sections up on the same screen, so the sentence points at
something that is actually there. If that ever reads as a shrug, the fix is a
share row *inside* the clear section, not a second dialog.

**The button is called *Delete All Data*.** *Delete Everything* was the obvious
name and it was already taken: the tracker editor's second deletion says
exactly that, means one tracker with its history, and tells you — correctly —
that it cannot be undone. Two buttons with one name and opposite promises, both
two taps apart on the Settings screen, is how somebody learns the wrong thing
here and acts on it there.

**The promise is conditional, because restoring is stricter than loading.**
`StoreFile.load` validates nothing and `restoreImportBackup` runs
`validateImport`, so a hand-edited `store.json` — a duplicate id, `decimals`
outside 0…3 — opens fine and can then be refused on the way back. The dialog
would have promised an undo that was not there, in the one case where the
sentence is doing all the work. `Store.currentDocumentIsRestorable` is asked
before the wording is chosen, and the replacing import says the same thing for
the same reason. The gap itself is older than this item; the unconditional
promise was new.

## The ids stay UUIDs — decided

Asked whether the 36-character ids in `store.json` need to be that long.

**They do.** They are load-bearing for the merge design: two devices generate
ids independently, with no coordination, and must never collide. That is what a
UUID buys. A shorter id means writing a generator and owning a collision
argument forever, in the one part of this app where being wrong is silent.

Size is not the problem it appears to be. Five years of heavy use is about 2 MB
and decodes in 41 ms, and the file is deliberately pretty-printed with sorted
keys — which costs more than the id length does. Shrinking ids while keeping
that would be optimising the smaller half of a cost we chose on purpose.

The honest argument the other way is readability, since the file is meant to be
opened and read. But you read names and values; ids are noise at any length.

## 25. Jump to a date in History

At five years History is 1,733 days of rows in one section, and reaching last
March means scrolling past everything since. Measured: 30 fast flings go 41 days
back, so the far end of five years is about 1,300 flings away and last spring is
a few hundred (docs/scale.md). Photos solves this with a scrubber, and the
pattern is right: a way to *go* somewhere, not a filter that hides the rest.

- [ ] A control that jumps the list to a chosen date — a scrubber, a compact
      date picker, or a month index, whichever reads best at that length.
- [ ] It **navigates, it does not filter.** Nothing leaves the list, and
      scrolling away from wherever you land keeps working in both directions.
- [ ] Landing on a day with nothing logged goes to the nearest day that has
      something, rather than an empty screen or a dead control.

**This was never the answer to History's 1.5s freeze**, and it must not be used
as one. Loading only around a chosen date would make scrolling back slow or
impossible and quietly turn the record into a window onto it. The freeze has
since been fixed as a freeze — it was one `Section` per day, not the number of
rows (docs/scale.md) — so this item is now free to be judged on the only thing
it was ever about: whether it helps you find something in a list that is
genuinely long.

## Noted, not scheduled

Wanted, not yet queued. Written down with the part that isn't obvious, so
picking one up doesn't start with rediscovering why it's awkward.

- [ ] **What the gap between two days should be, now that there is no card.**
      The section fix left the day heading's `listRowInsets(top: 18, …)` sitting
      *on top of* the spacing a headerless `Section` already reserves rather
      than instead of it, and the review measured what that costs: History is
      **3.0% taller — about 17 points a day — and its first heading starts some
      47 points further down** the screen you arrive on (docs/scale.md). The
      commit's claim that the rounded corners were the only visible difference
      was corrected there.

      Not fixed on the spot, deliberately: it is spacing, the screens read
      perfectly well as they are, and picking a number is a taste decision
      nobody has made — the old spacing was the *card's*, and the card is gone.
      What makes it worth writing down rather than shrugging at is the length
      of this particular list: 17 points a day over five years is 29,000 points
      of extra scrolling in the one screen whose whole problem was its length.
      `.listSectionSpacing` on Home and `.contentMargins(.top, 8)` on Repeat are
      where this app has tuned the same thing before.

- [x] **Appearance switch in settings — light / dark / system.** Done as
      written: a segmented picker under an *Appearance* heading, between the
      trackers and the data actions, driving `.preferredColorScheme` from
      `@AppStorage`. `.system` is `nil` rather than a third scheme, which is
      what makes it "follow the phone" including the phone's own per-app
      setting.

      **No test, and that is the point of where it lives.** There is no code
      path from the preference to `Store` — the app root reads it and the
      picker writes it, and nothing in between — so "it must not appear in an
      export" is a property of the wiring rather than something an assertion
      could usefully hold. Putting it in the document is what would have needed
      one.

      Two things worth knowing next time. The segmented style **drops the
      picker's own label**, so without a section heading the row is three words
      and a paragraph about "System" with nothing saying what is being chosen.
      And a segmented picker survives this app's `.tint(.primary)` where a
      `Toggle` does not (docs/TODO.md item 13c): its selection is a background,
      not a fill drawn in the tint. Checked on an iPhone 17 with the *system*
      in light mode and the app set to dark — the app draws dark, which is the
      override doing its job rather than the simulator's setting leaking
      through.

- [x] **A Log again row should show what a tap writes.** Done, and it turned
      out to *delete* a concept rather than add one: `belongsInRepeatList` is
      gone. It could only accept or reject a whole row, which is why a mixed
      weigh-in batch had to be refused; `HistoryItem.keeping` projects instead,
      and "is anything left" is then the same question asked where the
      projection already is.

      The two sets that came out of it are the thing to remember, because they
      are nearly the same and must not be merged. **Listable** is present and a
      daily total, *archived included* — item 16's rule, that archiving a
      tracker must not make your food vanish. **Writable** is
      `Store.repeatableEntries`: present, unarchived, a daily total. Deciding
      membership on the second empties the list the moment you archive
      something.

      Both predicted consequences happened. A weigh-in breakfast collapses onto
      the plain one, and two tests now say so on purpose. And "Logged 1 of 2
      again" is right from History and never appears from Log again, because
      `skipped` counts what the row holds and the row on that screen no longer
      holds anything the tap will not write — which is a better answer than the
      note expected, and it is why the undo bar needed no new wording.

- [x] **Say why a repeat disc is off.** Done with the first of the two cheap
      options — a word on the row — and it goes on the *identity* line, after
      the identity, in the same footnote grey, only when the disc is off.
      "morning · Measurement", "shake · Archived", and nothing at all on a row
      that can be repeated. The deleted case stays silent here because the
      identity line already prints "Deleted tracker" and saying it twice on one
      row is what item 14b's `identitySaysDeleted` exists to stop.

      Three reasons, one label, and the classification is **not** a second
      opinion about whether the row can be repeated: `Store.repeatableEntries`
      answers that, `HistoryItem.repeatBlockedReason` only says which of the
      reasons it was. A third copy of the writability rule is exactly what item
      23 was about.

      A row mixing an archived total with a live measurement says "Archived",
      which is the actionable half — it names the thing you could unarchive.

      **The undo bar needed no new wording, because item 6 removed the gap.**
      "Logged 1 of 2 again" can now only come from History, where the row
      visibly holds more than the tap writes and now says why; from Log again a
      row holds only what the tap writes, so `skipped` is zero and the sentence
      never appears. The answer is on the row you tapped rather than in the bar,
      which is better than either option this note listed.

      No disc at all on an unrepeatable row was the other option and is still
      not taken, for the reason recorded: "no control" is how History says
      nothing about a row, not how it says "not this one".

- [x] **A configurable time for the daily reset.** Done, and it was the
      largest of the seven by some way — the estimate above is right about
      where the cost is. **It reverses a decision recorded in TECH.md** ("the
      day starts at midnight, local. No configurable day start; it multiplies
      edge cases in every aggregation for a minority want"), and both of that
      document's copies of the line now say so and why.

      No schema change, no migration, nothing stored: `DayStart` is one
      `UserDefaults` key, `DayKey` takes a `dayStartHour` defaulted to 0, and
      `Store.dayKey(_:)` is the single place inside the store that applies it.
      Turning it back re-derives exactly the totals that were there before,
      which a test holds.

      **The trap is arithmetic, and it is not the one the estimate names.**
      Subtracting `hour × 3600` from the date before deriving the day is the
      obvious implementation and it is wrong across DST: on a spring-forward
      morning, 04:30 minus four *absolute* hours walks back through the hour
      that never happened, lands at 23:30 the previous evening, and files the
      entry under yesterday. Reading the wall-clock hour and stepping one
      calendar day cannot do that. Six new tests cover it, including both
      passes through the repeated hour and the day whose 2am does not exist —
      where a 2am day start simply begins at 3am.

      The existing day-boundary suite was the specification and none of it
      moved: every one of those tests still asserts midnight behaviour, because
      the parameter defaults to 0. The count is in the commit, where it is a
      statement about that commit — the CI item learned an hour earlier that a
      number written into a done entry goes stale on its own.

      One thing found by a test rather than by reading: `Date.formatted`
      defaults to the *device's* time zone, so the picker's "4:00 AM" label came
      out as "9:00 PM" the moment a test pinned a calendar to another zone. The
      app never saw it, because there the two zones are the same one.

      **Four things the review found, and two of them were real bugs shipped
      under passing tests.**

      `startOfDay` **added** the offset in absolute hours instead of setting a
      wall-clock hour. Spring forward survives that; fall back does not — on
      3 November 2019 in New York every start from 2am to 5am landed an hour
      early and round-tripped to the *2nd*, so on that one day a year the chart
      drew the bar before the day began, the measurement range pulled in an
      hour belonging to yesterday, and the counting window sat an hour wide.
      The fall-back test passed because it asserted the day was 25 hours long
      and the bug made it exactly that: cut at 4am the long day is the **2nd**,
      not the 3rd. An expectation and a bug agreeing with each other is the
      thing a round trip catches and a length does not, so there is now a round
      trip over all 24 hours and the tiling test runs on both DST days instead
      of a June one.

      `setDayStartHour` wrote `UserDefaults.standard` and `Store.init` read it,
      so one day-boundary test moved every other suite's midnight — in process,
      in parallel, and on a simulator across runs. The **app's** convenience
      init reads the key now; the designated init takes the hour and defaults
      to midnight, so nothing under test touches `UserDefaults` at all.

      And a regression the feature introduced rather than found: the only thing
      that rolls the day automatically is
      `significantTimeChangeNotification`, which fires at **midnight**. Move
      the boundary to 4am and nothing announces it — an app left open overnight
      went on showing yesterday's total under today's heading. There is now one
      sleeping task, rescheduled only when the moment it waits for moves, and
      skipped entirely at midnight where the notification already does the job.
      The graph's staleness key gained the hour for the same class of reason.

      **And one the review did not find, because looking at a screen found it
      instead.** `TrackerEditor`'s footer — the one sentence in the app that
      explains what a daily total *is* — said "start again at midnight", hard
      coded. It reads the setting now. It turned up while screenshotting the
      new add-tracker sheet for a different item, which is the argument for
      looking at the screen rather than only at the diff.

- [x] **An About screen, with a link to the repository.** A pushed screen at
      the end of Settings: the version, a plain `Link` to the repo, and the two
      sentences that say what this app does not do. Nothing to test — it draws
      two rows and reads `CFBundleShortVersionString`.

      The version is read from the bundle rather than written into the source,
      so it cannot disagree with what was built, and the build number is shown
      beside it because a bug report naming only "0.1.0" cannot say which
      build. It reads **0.1.0 (1)** today.

      Pushed rather than folded into Settings as rows: the version and the
      promises are read once ever, and the screen that arranges trackers should
      not spend rows on them. The link draws as the app's other rows do — plain
      label under `.tint(.primary)`, no blue — which is consistent and does not
      advertise that it leaves the app. Left that way rather than inventing a
      third treatment for one row.

- [x] **A subtle "add tracker" at the end of the home list.** Tried, and it
      reads better than expected — which is entirely down to it not being a
      card. A section with a clear row background and secondary text draws as a
      grey line *under* the last tracker rather than as another tracker, so the
      eye that came to log a number goes past it. On the starter set it sits
      just below the last card with the whole lower half of the screen empty
      beneath it, and it still does not compete with the Log pill, because it
      is grey text in the scroll and the pill is a filled bar in the safe-area
      inset. With four or more trackers it is below the fold, which is the
      right place for something you do a handful of times ever.

      The thing to watch turned out not to bite, because it was answered by
      *not* pinning: nothing was added to the bottom bar, so Log and the Log
      again disc keep the thumb arc to themselves — the same answer item 16
      gave when it made Repeat visibly not a peer.

      It opens the tracker editor directly rather than pushing Settings. The
      empty state's button still pushes Settings, and that difference is
      deliberate: a label reading "add tracker" that delivers a screen with an
      *Add Tracker* button on it is a promise kept a step late, while somebody
      with no trackers at all has more to do on that screen than make one.
      Home's third sheet, and the only editor it owns.

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
