# TODO

**Most of this file is not a to-do list.** It is the record of an app built one
item at a time, and by now the finished items outnumber the open ones many times
over. They are kept, and kept long, for two reasons: *why* something is the way
it is has turned out to be the part worth having six months later, and several
of them exist specifically to stop a settled question being reopened for the
third time. A few record things that were built, measured and thrown away,
which is knowledge the code no longer contains.

So read it as a decision log with a short to-do list on the front, rather than
as a plan. **What is actually left:**

- [17. One pass on a real device](#17-one-pass-on-a-real-device) — the whole app
  on hardware, which no simulator answers. **The only numbered item left**, and
  every question in it needs a thumb, an ear or a real screen: items 27 and 30
  closed by handing it theirs.
- [Noted, not scheduled](#noted-not-scheduled) — real, unranked, no session
  assigned.
- [Small things, unscheduled](#small-things-unscheduled) — the standing queue
  for things not worth a session each, done in one pass whenever something goes
  near the same code. **Currently empty**; what it has held is collapsed there.
- [After v1](#after-v1)
- [iPad 1.1 scope](#ipad-the-scope-decided) — universal layout implemented;
  hardware pass and iPad listing screenshots remain before submission.

Everything else below is finished, reverted, or closed without a change, and
says so in its heading.

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

Item 12 is deliberately not collapsed, and it is not the only one. The rule
above is about *duplication* going stale, not about hiding the reasoning: where
an item's argument is the only place a rule is written down it stays where it
is, at full length. A done item collapses when what it decided has genuinely
moved to PRODUCT.md or TECH.md, not merely because it is finished.

**What stays long, and what points at it**, so the next pass does not have to
work it out again. Item 12, the number pad built and reverted, because the only
thing stopping somebody spending a week rediscovering it is this item saying so.
Item 21's kind-based repeatability and its three edge cases. Item 25's rejected
scrubber and month index. The geometry in 33b. Item 29's frequency order,
because [PRODUCT.md](PRODUCT.md) names this file as where it is written up.
Item 40's measurements, because three comments in `BoringTracker/` name this
item as where they are. And item 42's ratio table, for the same reason —
`CardPlus` points here. **The last three are held from outside this file**, so
moving one of those passages means fixing what points at it in the same
commit.

**Screenshots are not in the repository.** Several items name a directory like
`~/dev/boring-tracker-pairing/` and a file in it. Those renders and contact
sheets stayed on the machine that made them, deliberately — they are megabytes
of PNG that would sit in history forever to illustrate a decision the item
already states in words. The path is there to say *a picture was taken and this
is what it showed*, not as somewhere a reader can go. What was measured off
those pictures is written next to them.

**A measurement inside an item is dated by its commits**, which is the other
reason done items keep their SHAs — the device, the build config and the method
are stated where the number is, and `git log` says when. The 2026-08-19
documentation pass re-ran none of the timing or screenshot measurements here;
what it did re-run is every WCAG contrast ratio the accent items carried — they
are in [TECH.md](TECH.md) now, and all of them reproduce exactly from their hex
values — and the test suite. **That pass recorded 281 tests and the suite is
277**, re-run on 2026-08-19 at `cb2e60e` before item 32 touched it; 278 after.
The count is corrected here rather than argued about, and it is the kind of
number this file now asks people to stop writing down.

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

Settings draws home's shape — a heading above each run of trackers sharing a
group, bare rows for loose ones — so the two cannot disagree about an order.
Dragging within a run reorders that group's members, a group moves as a unit,
and membership still changes only in the tracker editor. `decae37`, `5076729`,
`7086673`, `394b82a`

Why that drag is hand-rolled and why a native `.onMove` was declined is in
[TECH.md](TECH.md), with the two measurements that cost a session each: a
`List`'s `frame(in: .global)` is already the safe area, and a named coordinate
space declared on a `List` is not reachable from inside its rows. Both silently
rewrote stored order and stamped it as a decision.

## 7. Put home's + in the thumb — done

The primary **+** left the navigation bar — roughly 63pt from the top, the least
reachable point on the screen holding the most frequent action in the app — for
a labelled bottom button in the thumb's arc. `34b2a16`, `59dbe11`

The three measured positions and the clearance under them are in
[PRODUCT.md](PRODUCT.md).

**Half of what this item did is gone, and the collapse is what noticed.** It
also folded in a fix for the log sheet's dismissal reflow, by snapshotting the
visible **recents row** and its values while saving — and item 11, the day
after, removed that row altogether — and this item has gone on describing the
fix in the present tense ever since. What survives it is the trap the snapshot
fell into: a `Dictionary` built with `uniqueKeysWithValues` traps on a store
file holding two trackers with one id, and it killed the app on the Log button.
That rule is in [TECH.md](TECH.md), and the two lookup tables that still exist
carry it as a comment.

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

## 13e. Form buttons lost the only thing that said they were buttons — done

A `Button` in a `Form` has no disclosure chevron, so item 13c's label colour
made the settings action rows pixel-identical to static ones — and the same bug
was one screen further out, on About's `Link`. They are `formRowAccent()` now,
at six call sites. `9d68102`, `24aff43`

**It is `.foregroundStyle` and not `.tint`, and that is why there are two
carve-outs rather than one modifier under a better name.** Both halves were
measured and they say opposite things for a bar button and a form row; the table
is in [TECH.md](TECH.md), with the rest of the accent rules and the colour set
item 18 built to unblock this.

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

## 16c. A 60-day counting window on the Repeat list — done, then removed

The frequency count reaches back 60 days instead of over all history, so a
staple you gave up stops outranking this month's breakfast — without dropping a
row from the list. `90dda62`

**Superseded by item 29**, which took the whole frequency order out for a
chronological one. The reasoning is kept there rather than only here.

## 16d. Lifetime count as a second tie-break on the Repeat list — done, then removed

`6d33fe8`

Between the 60-day count and recency, so a staple having a quiet spell beats
something new on the same small window count, and the window still decides
first. What it moved on a real diary, and what it cost, are in the commit
message.

**Superseded by item 29** along with the window it sat under.

## 16b. Search in History too — done

One `.searchable` over History, filtering through item 16's matcher rather than
a second one. `38f6b85`

## 17. One pass on a real device

Three things that no agent can settle, because each needs a thumb, an ear, or
a real phone rather than a simulator. **One errand, not three** — they were
separate items and that was wrong.

**Can a double-tap log twice? — settled, and guarded anyway.** It was tried
three times: two reviewers could not land synthetic clicks fast enough and both
reported it *unverified in either direction*, and Anton then tried it on a real
phone with a real thumb, around eight times, and got one entry every time.

- [x] Settle whether it reproduces, with a real thumb. **It does not** — three
      attempts, none of them reproduced it.
- [x] If it does, disable the action on first tap rather than debouncing by
      time. Done regardless, in `6a57cbd`: not observed is not the same as
      cannot happen, nothing prevented it, and the window may differ on a
      slower device, under memory pressure, or with Reduce Motion altering the
      dismiss timing. A `wrote` flag on the sheet's own state, so one
      presentation logs once; no timer, and `.disabled` still reads
      `amounts.isEmpty` alone, because adding the flag there would repaint the
      pill in its disabled style while the sheet is still sliding away.
- [x] If it doesn't, say so and close it. Said, and closed.

The one-tap last-time log needs no guard, and that is a different answer rather
than the same one: the control never goes away, so there is no gap between the
write and the button ceasing to be hittable. A second tap there is an intended
second log — `LastTimeTests.twoTapsAreTwoEntries` already pins it — and only a
clock could tell it from a slip, which is the debounce this item rejected.

It mattered more than its size suggested: a silent duplicate on the most
frequent action in the app is the kind of wrong number nobody notices until a
graph looks strange months later.

**VoiceOver.** Commit `0564080` claims `.accessibilityLabel` on the card's +
"had no effect at all", while `logButton` a few lines below and `HistoryView`
both do exactly that and work. Either the claim is wrong, or `children: .ignore`
makes that button a container and the hint has to move inside it. It cannot be
settled from the accessibility tree.

- [ ] Turn VoiceOver on and swipe through home, the log sheet and History.
- [ ] Settle the + button's label and hint, and correct the comment either way.

**One more thing to look at while the phone is in hand.** The card `+` is an
outlined ring, chosen off simulator screenshots (item 42, decided). The filled
disc it replaced is still in the code behind `CardPlus.outlined` for exactly
this reason.

- [ ] Look at the ring on a real screen. If it holds up, delete the disc; if it
      does not, the constant is one line.

**Three questions about a press that only a thumb can answer.** None of them is
about whether a press draws — item 32 settled that at 60fps, on taps down to
40ms — and all three are about how one *feels*. The third arrived here when
item 27 closed; the first was already shared with it.

- [ ] **Does the haptic help — and does it now fire while you scroll?**
      `.impact(.light)` on the press edge is on every row of five screens, which
      is most of the app's touch area. Item 40 turned off the delay a list put
      in front of a row's touch, and one thing that delay was doing was keeping
      a flick out of the pressed state entirely: a flick that starts on a row
      now enters it, so the same trigger that draws the wash fires the impact.
      Measured as pixels, not as a buzz — a simulator logs "Haptics:
      unsupported" and nothing reaches CoreHaptics, which is why this is the
      first thing to hold a phone for. **If it buzzes on every flick, deleting
      the press haptic is the fix already on the table**, and it costs nothing
      that has ever been felt.
- [ ] **Does the 2pt scale read as a press under a thumb?** Item 27 replaced
      colour with motion because colour alone had been measured and still was
      not noticed, and the motion was then judged the same way the colour was —
      by synthesized presses and a 60fps capture. Six controls were photographed
      held down and every one moves 2pt at each end of its longest edge, so it
      renders; whether 2pt is enough to feel is the question those pictures
      cannot answer, and it is the same gap item 26 fell into one step earlier.
      **If it is not enough, the number is one constant** — the mechanism is
      already right and `accentFilled(_:)` is the only place it lives.
- [ ] **What does a press called off look like?** SwiftUI reports a
      cancellation and a release identically, so a flick that starts on a row
      leaves that row washed while the list is already scrolling. Item 40 made
      it common rather than narrow — it is now every flick that starts on a row,
      not only one that rests first — and item 32's floor holds a press the
      scroll has already cancelled, for its 100ms and then the release fade,
      which on the numbers already recorded is 100 plus 82. The 90ms item 40
      first reported is too short to be that; see the correction there. Still
      cosmetic, and the fix is still a second gesture watching for movement, which
      `RowPress.swift` has three times decided not to add. Look at it on a phone
      before deciding it is worth machinery.

**Where the rate link actually lands.** Item 43 put a `Link` to
`apps.apple.com/app/id6803768789?action=write-review` on About. The simulator
has no App Store app, so it cannot answer this: Safari there refuses the URL as
invalid, and refuses a live app's identical link the same way.

- [ ] Tap *Leave a Review* on the phone and confirm it opens the App Store on
      **this** app, on the write-a-review sheet. No longer waiting on the
      listing: it went public on 2026-09-04 and the URL returns 200.

**Pressed states are otherwise done and are not waiting on a device.** They sat
here across four sessions as uncapturable — pressing a control in the simulator
needs synthesized clicks, which need the accessibility tree, which a locked
macOS console takes away. Item 26 found the console unlocked, held every
accent fill down and photographed it, and the answer this item recorded as
computed was wrong in exactly the place it mattered: pressing does *not* only
lighten. The one control that lightened was the prominent Log button in dark
mode, at 1.08:1 against its own rest colour, which is the complaint. The
numbers are in `bb14a4f` and in `Color.accentFillPressed`.

## 18. The app icon — done

Both halves are in: the accent became a colour set — `AccentFill`, `#009888`
light and `#00DAC3` dark — and the icon itself is the `ledger` candidate
`docs/SHIPPING.md` recommended, chosen by the user and installed without a pixel
changed. `24aff43`, `ec01bd7`

The candidate table that chose the light value, the two neighbours rendered
beside it and the pixel diff that says dark did not move are in
[TECH.md](TECH.md). What the icon is, and what any icon here has to be, is in
[SHIPPING.md](SHIPPING.md). The mark has since been redrawn — see item 42.

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

Both screens' undo offers now expire from one place. The fix was not to give
History a copy of home's timer but to stop home owning one: home answers only
*whose* write it is, `UndoBar` answers *how old*, and it is a net deletion on
home. `27e7859`, `072cc01`, `66836e6`, `c8d5a5a`

The deletion offer is deliberately not expired, and undo is deliberately absent
from the log sheet; both arguments are in [PRODUCT.md](PRODUCT.md).

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

A quiet footer under History's first day section, saying both gestures out loud:
"Tap a row to edit it, or swipe to delete." Under the first section only, not
under all 365 — repeating it every day would be the app nagging. `7b33703`

The rule it turned into is in [PRODUCT.md](PRODUCT.md), with item 38. The Log
again sheet was checked rather than assumed and needs neither: its rows have one
gesture and the repeat disc draws it.

## 23. History's disc still repeats a weight — done

Item 21 settled that repeating a measurement writes a reading nobody took, and
enforced it in exactly one place — the Log again list. The disc on a History row
never learned the rule, so one tap wrote a weight entry dated now and home's
card showed it as today's reading. Found by review, not by use. `8045e91`

**Closed at the choke point, not at the control.** `Store.repeatTargets` drops
measurement trackers beside the deleted and archived ones it already dropped, so
`logAgain` writes only what may be written and every caller inherits that
without knowing the rule exists — including the ones not written yet, which is
the trap disabling the control would have left. `isRepeatable` became
`belongsInRepeatList` in the same change, because after it the old name asserted
something false: a live weigh-in batch is rejected by it while `logAgain` writes
the batch's calories all the same.

What a tap writes, and what a row therefore says on each screen, are in
[PRODUCT.md](PRODUCT.md). The design problem this left — a Log again row was
built from what the batch *holds* while the screen promises what a tap *writes*
— went to "Noted, not scheduled" rather than riding in on this item, and has
since been built: `9583319`, `fc9fed8`.

## 24. Delete everything, recoverably — done

*Delete All Data* in settings, beside export and import, with **one**
confirmation naming what goes — *"Delete 5 trackers and 1,247 entries?"* — and
the document it destroys kept in the same recovery slot an import uses. A
number is what makes someone stop; a stack of confirmations is what people learn
to tap through. `1a55ac6`, `3f54a55`

`Store.clearAll` is the replacing import with a smaller argument, there are no
tombstones for what a clear removes, and the promise is conditional because
restoring is stricter than loading — all three are in [TECH.md](TECH.md). Why
the button is *Delete All Data* and not *Delete Everything*, which the tracker
editor already had and which genuinely cannot be undone, is in
[PRODUCT.md](PRODUCT.md).

## The ids stay UUIDs — decided

Asked whether the 36-character ids in `store.json` need to be that long. They
do: they are load-bearing for the merge design, and the size argument does not
survive being measured. The reasoning and the numbers are in
[TECH.md](TECH.md). `8a81d9f`, `567cff3`

## 25. Jump to a date in History — done

At five years History is 1,733 days of rows in one section, and reaching last
March means scrolling past everything since. Measured: 30 fast flings go 41 days
back, so the far end of five years is about 1,300 flings away and last spring is
a few hundred (docs/scale.md). Photos solves this with a scrubber, and the
pattern is right: a way to *go* somewhere, not a filter that hides the rest.

- [x] A control that jumps the list to a chosen date — a scrubber, a compact
      date picker, or a month index, whichever reads best at that length.
- [x] It **navigates, it does not filter.** Nothing leaves the list, and
      scrolling away from wherever you land keeps working in both directions.
- [x] Landing on a day with nothing logged goes to the nearest day that has
      something, rather than an empty screen or a dead control.

**This was never the answer to History's 1.5s freeze**, and it must not be used
as one. Loading only around a chosen date would make scrolling back slow or
impossible and quietly turn the record into a window onto it. The freeze has
since been fixed as a freeze — it was one `Section` per day, not the number of
rows (docs/scale.md) — so this item is now free to be judged on the only thing
it was ever about: whether it helps you find something in a list that is
genuinely long.

**A calendar glyph in the nav bar, opening a graphical `DatePicker` in a
popover.** One tap opens it, one tap on a day goes there, and the list is
exactly the list it was — one section, every row, newest first. What makes it a
jump rather than a filter is that it is a `ScrollViewReader` and nothing else:
`scrollTo` the day's heading, no state kept afterwards.

**The picker does not close itself, and that is the one thing the real control
taught that no amount of reading would have.** Dismissing on the first change
was the obvious design and it was written that way first. Then the month and
year wheels behind the picker's title turned out to *be* the selection rather
than a way to look around — so touching either jumped and closed the popover,
and crossing five years, which is the whole point here, needs both wheels. That
version made "March 2022" three visits to a control that shuts on contact.
Leaving it open scrubs the list underneath instead: pick a year, it is there;
spin the month, it is there too; close it the way every popover closes.

**And opening it is a jump too, which is the review's finding and one rule
rather than a patch: while the picker is up, the list is where the picker
points.** The tap the control could not answer was the obvious one — a
`DatePicker` reports *nothing* when you tap the day already selected, neither
through `onChange` nor through a `Binding` written by hand, which was built and
tapped to check rather than assumed. So scrolling by hand into 2022, opening the
calendar and tapping today — the way back — did nothing at all. Asserting the
position on the way in answers that before it is asked, and makes re-tapping the
selected day correctly nothing to do: the list is already there.

**Three were built at five years and compared on screen**, which is the half of
this item that was a taste decision rather than a code one.

- **A compact `DatePicker` in the nav bar** — the smallest amount of code, and
  wrong: it draws "Aug 18, 2026" permanently beside the title, so the screen
  reads as *showing* a date. That is precisely the thing this item says the
  control must not become, arrived at by accident rather than by design.
- **A month index** — a sheet listing the months that have something in them.
  Honest, scales with type size, and the closest thing to "last March" as a
  named place. It loses on the length it was meant to fix: 60 months at 15 to a
  screen, and 8.5 at AX5, so it answers a scrolling list with four screenfuls
  of scrolling, and seven at accessibility sizes.
- **The calendar popover** — the same number of taps at any type size, because
  the month/year wheel behind its title crosses five years without scrolling,
  and the only one of the three that can name a *day*. Its **day grid stays 289-306
  points wide at every text size**, which is what makes its one fixed
  320-point frame safe — photographed whole on a 360-point iPhone 13 mini, the
  narrowest phone iOS 18 runs on. (This first said the picker "does not scale
  with Dynamic Type at all", which the round below found is not true: the title
  grows from 42 to 69 pixels of glyph height, the weekday row relabels from
  `SUN` to `S`, and the popover gets taller. The width is the part that is
  fixed, and the width is what the frame has to hold.)

**A scrubber was not built**, on arithmetic rather than on taste: 1,737 days
down a screen 956 points tall is at best 1.8 days a point, so a fingertip
covers 80 days and cannot land on a date without a magnifier and a date bubble
drawn by hand — and the edge it would live on is the one History already gives
to swipe-to-delete.

**Landing is `DayKey.nearest`, and the gaps are the ordinary case.** A five-year
history has two holidays, 3.5% of days missed and a first day, so "nothing was
logged then" is what a date picker mostly asks about. Driven at 29,264 entries:
31 January 2023, inside a thirteen-day hole, lands on the 25th; 9 December 2012,
nine years before the first entry, lands on the first day rather than doing
nothing; today comes back to the top. After each of those the list still holds
**1 section and 17,788 items — 16,050 rows, 1,737 day headings and one hint** —
and scrolls to both ends.

**It costs 6 to 29ms to open, on a 360ms open — 2% to 8%.** Three batches of
alternating installs at 29,264 entries, medians +29, +23 and +6ms: real, small,
and not measurable to better than its own size on a machine where a long session
of builds moves the same two builds further than the change does
(docs/scale.md). It is *not* the `.id()` on 1,737 heading rows, which was the
obvious suspect after the section finding: a build with the identities removed
costs the same as the one with them. What the screen pays for is the
`ScrollViewReader` and the toolbar item.

**The search field and this one do not compete.** On iOS 26 `.searchable` draws
its field as a pill at the bottom of the screen and this sits in the nav bar, so
neither moves the other. They are modal to each other, though, and that is
iOS's doing rather than a choice here: focusing the field hides the whole nav
bar — title, back button and the calendar — until the keyboard goes away.

**Two more from the review, both about what a jump does not say.** `scrollTo`
posts nothing, so with VoiceOver on a tapped date was silent — focus stayed in
the picker and dismissing it landed you back on the calendar button with no cue
that five years had passed underneath; the landing now posts a `PageScrolled`
naming the day. And the DST test written for the tie-break did not discriminate:
with the short day *above* the target, a seconds distance and a calendar-days
one give the same answer, so it would have passed against the bug it was written
for. Moved so the short day is below, and checked by putting the seconds version
back and watching it fail.

**A later round re-drove all of this rather than reading it** (`b0f7fd8`, and
docs/scale.md). What held: the list never leaves — 1 section and 17,948 items
through every jump, both ends still reachable afterwards; nearest-day landing,
checked on three targets inside a fourteen-day hole; and the picker really does
report *nothing* when you tap the day already selected, proved by compiling the
open-time assert out and watching a re-tap do nothing while a tap on another day
moved the list 3,752 points. Opening, dismissing untouched and reopening
re-asserts the position both times, which is what the counter in `41d5515` is
for. The open cost has not grown: +13 and +15 ms on a 333ms open, about 4%, on
an independent fixture and harness.

**That round added the number item 25 said it did not have.** A jump costs
**331-354ms of blocked main thread**, and it is two costs: 178ms of `body`
re-evaluating and regrouping the whole log for a state change that cannot alter
it, and ~176ms of `scrollTo` reaching deep into 17,948 items. Left alone
deliberately — it is the order the screen already costs to open, on a
once-a-week control, and the regrouping half is what a search keystroke has
always cost here. A month wheel *drag* also fires one jump, not one per row it
passes, so the case that would have forced the issue is not there.

**One design question is left open, and it is not a bug.** When the day you pick
has nothing logged the list goes to the nearest day that does — but the calendar
keeps highlighting the day you tapped, and nothing on screen says the two
differ. Tapping 15 November on the five-year fixture lands the list on the
10th — correct, and from the popover indistinguishable from the control having
failed, since the calendar goes on highlighting the 15th. VoiceOver is told, by the
`PageScrolled` announcement; a sighted user is not. Moving the selection to the
day it landed on is the obvious answer and has a cost of its own — it would
fight the wheels, which *are* the selection.

**The design question this left is answered by item 25b** (`5aed442`): with a
single day of history the picker opened on one selectable square with both month
arrows dimmed — truthful, and a control that can only go where you already are.
The threshold that seemed impossible to defend turned out not to be a threshold:
**two days is the condition under which the control can do anything at all**,
because one day is one destination. Below it the glyph is absent rather than
greyed, since a disabled control invites the tap it cannot answer, and the two
empty states fall out of the same rule instead of needing their own. It reads
the *filtered* days the screen draws, so a search that leaves one day standing
takes the control with it — the control navigates the list as displayed.

## 26. A pressed button barely shows it — done

One pressed colour on every accent fill, and a disabled one you can see.
`bb14a4f`

## 25b. The jump control needs somewhere to go — done

The calendar is drawn only when two days have entries, and is absent rather than
greyed below that; the reasoning is with item 25. `5aed442`

## 27. The bottom bar: presses you cannot see, and a pairing that looks wrong — done

Two complaints about the pair of controls at the bottom of home, both from real
use. **The pressed state changed mechanism rather than number** — item 26 had
already measured a pressed colour and satisfied the measurement without reaching
the goal, so the fill now moves as well: 2pt off each end of its longest edge,
in one modifier, `accentFilled(_:)`, replacing four hand-written backgrounds.
Reduce Motion takes the movement and keeps the colour. **And the pairing was
decided from photographs** — five alternatives rendered by a throwaway
`-pairing <n>` probe, the user picked one, and it landed in item 33.
`71a1925`, `8ecdbfd`, `9b21d82`, `4c93cc7`, `15ce8ac`, `4d79720`

Item 37 has since reversed the direction of that scale, so the six-control table
this item recorded measures a build that no longer exists. How the travel is
derived, why it is a constant and not a ratio, and what iOS's own prominent
button actually does on press — it does *not* scale, which this item asserted
the opposite of before rebuilding it and checking — are in [TECH.md](TECH.md)
and pinned by `AccentTests`.

The standing constraint from the pairing half is in [PRODUCT.md](PRODUCT.md): a
peer beside Log competes with it, and prominence is carried by size and shape
rather than by hue. Swapping sides did not license making them equals, and
neither does resizing.

**Closed with nothing left to build here.** The two things it could not settle
are whether the haptic helps and whether 2pt reads as a press under a thumb, and
a simulator answers neither — UIKit logs "Haptics: unsupported" and a
synthesized click has no thumb behind it. Both are questions in
[item 17](#17-one-pass-on-a-real-device) now.

## 28. Rows should behave like controls — done

One problem wearing three faces, all three answered. Settings drew trackers at
**74pt against home's 52**; a row's middle was dead, because a `Button`
hit-tests its label's drawn content and settings' row was a name and a chevron
with a `Spacer` between them; and a press looked different on every screen.
`EdgeInsets.listRow`, `contentShape(.rect)` and `RowButtonStyle` —
`.buttonStyle(.row)`, on settings, History, the Log again sheet, tracker detail
and home's cards — answered all three. `3cbf54a`, `bd71d51`, `bb640b7`,
`ae12dd1`, `7be85d3`

**The press colour is iOS's own, measured rather than picked**: settings has one
row the platform draws itself, the `NavigationLink` to *About*, and it presses
`#FFFFFF` → `#D1D1D6` in light and `#1C1C1E` → `#3A3A3C` in dark — both
`UIColor.systemGray4` exactly. The movement is item 27's, reused.

The 44pt floor, and what a row that is really two controls does with the wash,
are in [PRODUCT.md](PRODUCT.md). The `.onGeometryChange` trap that silently ate
the insets, and the scroll measurement that says the extra layer costs nothing,
are in [TECH.md](TECH.md).

Still judged by a synthesized press rather than a thumb —
[item 17](#17-one-pass-on-a-real-device) settles that, with the haptic and item
27's scale.

## 29. Sort Log again chronologically — done

Most recently logged first, and nothing else: `canRepeat`, then the row's date
descending, then `sortID` — three comparisons where there were five.
Deduplication is untouched, and rows that cannot be repeated still sort below
everything that can, because that rule is about what a tap can do rather than
about order. `703894a`

**It did not get slower.** The frequency order was rebuilt in a temporary test
and alternated with this one in a single binary, ten runs each over four
fixture shapes: chronological is the faster column in all four by 0.3–1.0ms of
median, and every range overlaps — so the honest reading is that the difference
does not register, not that dropping the counts bought anything.

What the screen now promises is in [PRODUCT.md](PRODUCT.md). The order it
replaced is below at full length, because PRODUCT.md names this file as where it
is written up and because it is the first thing to try if chronological ever
feels wrong in use.

### The frequency order, kept because it worked

**Not deleted, recorded.** It was measured, it did what it was chosen for, and
it is the first thing to try if chronological feels wrong in use. The code is
`fd09535` and after it `90dda62` (the 60-day window) and `6d33fe8` (the lifetime
tie-break); this is the argument, so that nobody has to reconstruct it from a
diff.

The order was: **60-day count, then lifetime count, then date, then `sortID`**,
under the same `canRepeat` partition that is still there.

- **Why count at all.** Recency was right for the undeduplicated list and stops
  being right the moment duplicates collapse. Both orderings were built and
  screenshotted on a 56-day fixture: recency spent two of its first fourteen
  rows on one food at two portions while four rows in a row read "Today" — a
  one-off floats to the top merely because it was yesterday, and the date column
  says nothing where it is densest. Frequency's first screen was thirteen
  different foods at the portions actually eaten, with the variants below them.
  It was also **steadier**: the top of a recency list moves on every single log,
  so the row you tap each morning is never twice in the same place.
- **Why a window and not a lifetime count.** A lifetime count never falls. Eat
  porridge every morning for a year, switch to overnight oats for a month, and
  last year's staple still outranks this morning's — reachable only by search,
  on a screen whose job is one tap. Sixty days is long enough that a weekly
  thing is still counted about eight times and a seasonal one does not fall off
  when the weather turns, and short enough that a habit dropped two months ago
  stops holding the top of the screen. Whole local days, in the store's
  calendar, not 60×86,400 seconds — a seconds-based window slides under the list
  while you read it, and asking the calendar is what survives a DST change.
- **Why a lifetime count underneath it.** Inside 60 days most counts are small,
  so ties were the common case rather than the edge one: two things each eaten
  twice this month tie immediately, and the date then decides on which you
  happened to eat last, which says nothing about which you want. A thing eaten
  200 times over two years and twice this month is a staple having a quiet
  spell; a thing eaten twice ever is not. It never spoke first, so the window
  still decided which staples were quiet.
- **It degraded into recency rather than falling apart.** Someone who weighs
  food to the gram repeats no number exactly, every count is 1, and the
  tie-break was the whole ordering — which is exactly the case chronological is
  now right for by construction.
- **A count is not a filter.** Nothing ever left the list: a row with nothing
  inside the window counted zero and sank, and it is still listed today, sunk on
  its date instead.

**What it cost, and why chronological wins anyway.** The counts are invisible.
The list reordered itself on a number the screen never shows, so where a row
would be next time was not something you could work out by looking at it. And
the strongest argument for frequency was already conceded when recency was first
replaced — "for someone eating the same five things the two converge" — so for
staples chronological approximates it. What chronological adds is
predictability.

## 30. Confirm a log where the eye actually is — done

Logging from Log again did not feel like anything happened. It does now, and
**nothing was added to close this item** — what answers it shipped in `86f4b5e`
and three review rounds on top of it, and the last open box turned out to be
answered by a bar that was already there. `cc13790`, `8680d6b`, `956483e`,
`0eb4fc4`

**The diagnosis was placement, not strength.** The number counts up on the home
card and the undo bar appears on home — both *behind* the sheet you are looking
at. Item 15's animation is real and correct and you cannot see it from there.

**If you are reading this because logging feels silent, read
[PRODUCT.md](PRODUCT.md) before building anything.** The complaint has been
raised three times — this item, an earlier session that said the same thing
about repeating from History, and the brief that closed this item, which
restated the original diagnosis as though the fix did not exist. It exists, it
is described where the screen is described, and the three obvious alternatives
are each costed there.

## 31. Light mode's accent is murky — deferred, no change

**Closed on the user's own answer**, not on the analysis: *"i only care about
dark mode so far."* Light keeps `#009888`. Nothing here was rejected — four
rounds of candidates were rendered and measured, deeper, lighter, right around
the hue wheel, and then in both appearances for azure — but they were waiting on
a preference between two appearances and only one of those is being judged. An
item on the open list implying somebody owes a decision was the wrong thing for
it to be. `87b0711`, `930c322`, `c5eacea`, `c8c2552`, `f0337a4`

The window, why the light value sits at the top of it, the azure pair that is
the one real alternative, and the four values this would be reopened with are in
[TECH.md](TECH.md). The contact sheets were never committed, deliberately; the
candidate tables are in git history, in `docs/accent-options.md`.

## 32. A press you can see on a fast tap — done

Every pressed state applied on the frame the touch lands, and only the release
drawn. A row presses as a whole cell rather than a box behind its text, and
holds long enough that a list's delayed touch still shows one. `b9c0695`,
`5b4cfab`

The delay it was working around is gone — item 40 measured it and turned it off
— so the 0.1s floor now serves the ordinary case of a 40ms tap being two frames,
and the floor is what holds a cancelled press on screen during a flick.

## 33. Use pairing 1 for the bottom bar — done

A 50pt accent circle, the pill's height and corner, and the 70pt slot handed
back — pixel-identical to `pairing-1.png`. Log again stays right, Log left.
`d579aff`

The sixth shape this item rendered and left waiting on the user is answered by
item 33b: the bar stays as it is.

## 34. Does a settings row say it can be edited? — done

The chevron stays and the footer says the tap out loud, in the idiom item 22
already uses on two screens. Items 28 and 32 were checked as the alternative
answer first and are not one: both happen after a finger has landed. `18416ce`

**The footer half has since been replaced**: item 37 put the explanation on the
row itself, as a caption under the name, and took the sentence away — a caption,
a chevron and a paragraph is three explanations of one gesture. The rule that
settles which of the two a screen gets is item 38's, and it is in
[PRODUCT.md](PRODUCT.md).

## 35. Two rows, two reading orders — decided, done

Superseded by "35 (decided)" below — tracker detail leads with the name, like
History does. The rule, and the real argument that lost, are in
[PRODUCT.md](PRODUCT.md). `897c8aa`

## 36. The entry editor confirms where the log sheet used to — closed, no change

Superseded by "36 (closed)" below. `897c8aa`

## 33b. A rounded-square Log again — tried, keeping today's bar

**Decided: keep `33b-a`, the bar as it is.** Seven variants were rendered and
photographed; none was better enough to change.

The variant asked for is geometrically impossible as stated, and that is worth
keeping rather than rediscovering: the Log pill is a `Capsule` at 50pt, so its
corner radius is half its height by construction, and **a rounded rectangle
whose radius reaches half its shorter side is a capsule.** Carrying r25 without
being one requires being taller than 50pt, which contradicts "clearly smaller
than the pill". Three constraints, two can hold.

The escape that does exist, if this is ever reopened: give the **pill** a fixed
radius rather than a height-derived one — variant `d` drew both controls at
r18, which reaches "one family at two sizes" by changing the large control
instead of the small one.

## 33b-old. The original note — superseded by 33b above

Seven bars rendered and photographed, dark, iPhone 17 Pro, by a throwaway
launch-argument probe in a worktree — `33b-a-today.png` through
`33b-g-62x50-r25-capsule.png` in `~/dev/boring-tracker-pairing/`, with
`33b-strip.png` stacking all seven and `33b-corners-zoom.png`, which is the one
that decided it. `0d17171`, `f3efd5a`, `284ef77`

The conclusion is item 33b above, kept at full length there: the variant asked
for cannot exist while the pill is a capsule, and the escape that does exist is
to give the **pill** a fixed radius rather than a height-derived one.

## 37. Three fixes before release — done

- **The press grows instead of shrinking.** One line in
  `AccentFillPress.scale(for:reduceMotion:)`, which is the only place either a
  fill or a row works one out, so every accent fill and every row turned
  together and a mix of the two directions is not reachable. Judged by tapping
  fast, which is item 32's rule: three 40ms taps recorded frame by frame, and in
  all three the frame after the touch has the row's wash on and the disc already
  grown. `f97b671`
- **A settings row says what tapping it would edit**, under the name, in the
  caption slot — `Daily total · kcal`, `Measurement · kg` — and item 34's footer
  sentence goes, because a caption, a chevron and a paragraph is three
  explanations of one gesture. `f2d657a`
- **A two-line label no longer knocks the number off centre.** `StackingRow`'s
  side-by-side branch is `.center` rather than `.firstTextBaseline`, on all four
  screens at once rather than one screen taking a parameter. `a9487bc`

The direction of the press and the one rule for explaining a row are in
[PRODUCT.md](PRODUCT.md). `4215726` recorded what each fix cost.

## 38. One rule for saying a row is tappable — decided

**The row speaks when it can, and the footer is the fallback when it cannot.**
One rule with a stated exception, rather than two idioms competing — and it
beats forcing every screen into a footer for the sake of symmetry. History and
tracker detail genuinely cannot take the settings answer: no chevron, and their
trailing half is already a value. `af657b8`

- [x] Write the rule into `PRODUCT.md` beside the row descriptions, so the next
      screen does not have to guess. Done by this file's collapse pass.
- [x] Leave History and tracker detail as they are — they are the exception,
      correctly applied.

The ceiling this item left open — a grown fill is drawn about 2pt past its own
tap target, which is the limit on ever increasing the travel — is in
[TECH.md](TECH.md).

## 35 (decided). Tracker detail follows History — done

**Tracker detail leads with the name, like History does.** Consistency wins, and
the argument that lost was a real one, so [PRODUCT.md](PRODUCT.md) carries both
rather than this item. The two lines are `LogRowLabel`, drawn by History,
tracker detail and the Log again sheet alike — shared rather than matched by
hand, because three copies of one shape is how these came apart. `dac7619`,
`897c8aa`

## 36 (closed). The editors keep Save in the navigation bar

**No change.** Item 5 moved the *log sheet's* confirm above the keypad because
logging is the common path and the top-right corner is not in a thumb's arc.
Editing is rare, and `PHILOSOPHY.md` already says rare actions may live high.
The asymmetry is the rule working, not a gap in it. `897c8aa`

## 39. A "last time" kind, where the date is the data — done

**A third `Tracker.Kind`, and the other two are untouched.** Tyres, the water
filter, the boiler service, the dentist — things whose age you want and whose
number does not exist. `dad286f` model, `a04e447` UI.

What it is and what it must never become are in [PRODUCT.md](PRODUCT.md),
including the three decisions this item made that its brief did not: the reading
is the whole card and the date is not repeated under it, the ladder is days,
months and years and never weeks, and a one-tap log has no undo bar. Why
`Entry.value` stays non-optional is in [TECH.md](TECH.md).

## 40. A press you cannot see coming — done

Anton, on a real device: pressing and holding *Add Tracker* in settings, the
pressed highlight arrives late, and he suspected it was general rather than that
one row. It is general, and it is the list. **The fix is one line** in
`BoringTrackerApp.init`: `UIScrollView.appearance().delaysContentTouches =
false`. `220af79`, `14e6199`

**The measurements stay here** rather than moving to TECH.md, because three
comments in `BoringTracker/` name this item as where they are. What the app now
promises because of them is in [PRODUCT.md](PRODUCT.md).

**Method.** `xcrun simctl io booted recordVideo --codec h264` on an iPhone 17
Pro simulator, iOS 26.3, dark, debug build; frames decoded with `AVAssetReader`
and one rect's mean luminance printed per frame. The recorder emits only when
the screen changes, so on a still screen the emitted frames *are* the change
timeline; inside a press they average 16.0ms apart, so every number below has a
resolution of one frame, about ±17ms.

**Touch-down needs an anchor, and that is what makes the numbers mean
anything.** Nothing on screen changes when a finger lands — that is the thing
being measured — so a throwaway build carried a `UIGestureRecognizer` on the
app's `UIWindow` that recognises nothing and paints a strip of the left margin
white from `touchesBegan`. A recogniser on the window is handed the touch
immediately whatever the scroll view does with it, and the strip draws on the
next frame, which is the same frame budget the control has. Both ends of every
number are therefore "first frame after the state was set", so whatever the
simulator's own injection costs cancels out. The press is a `CGEvent` mouse down
held 800ms, three runs each.

**Before — touch-down to first changed pixel, in ms:**

| control | run 1 | run 2 | run 3 |
|---|---|---|---|
| *Add Tracker*, settings | 162 | 162 | 152 |
| the *Calories* row, settings | 152 | 152 | 142 |
| a History row | 150 | 138 | 142 |
| a probe button inside home's `List` | 153 | 148 | 143 |
| **the same probe button outside the list** | **0** | **0** | **0** |
| the Log pill on home | 0 | 0 | 0 |

The last two rows are the finding. The two probe buttons are one control with
one style, applied instantly and with no animation to wait for; the only thing
that differs is whether it sits inside a `List`. Inside costs ~150ms and outside
costs nothing, so this is `UIScrollView.delaysContentTouches` holding the touch
back while it decides whether the finger is scrolling. **After — same method,
three runs each: all six controls 0.0ms.**

**iOS's own settings list has the same delay**, and this is deliberately the
weaker measurement of the set: Preferences carries no marker, so touch-down
cannot be anchored inside it. Driven by the identical script, the *Camera* row's
highlight first appears 1990ms and 2005ms into two recordings, while the 53
marker-anchored recordings taken here put touch-down between 1786.7ms and
1846.7ms. Same delay, on an assumption rather than on an anchor.

**What it costs, measured rather than assumed:**

- **A flick that starts on a row flashes that row.** A 30pt flick off the
  *Calories* row: with the delay on the row never washes at all; with it off the
  wash is on at the touch frame and gone from the sampled band 90ms later.
  **That 90ms is not `AccentFillPress.minimumHold` expiring, which is what this
  first said.** `RowPressState.set` cannot tell a cancellation from a release,
  so it holds the press for the rest of the floor — 100ms — and then fades it
  out over `AccentFillPress.release`, 82ms recorded as visible. Nothing in that
  path can end a wash in 90ms. Likeliest is that the row scrolled out of the
  fixed band being sampled while it was still washed; that is reasoning, not a
  measurement, and a re-measure has to follow the row rather than a rect. The
  direction is not in doubt either way.
- **And the same flick fires the press haptic**, because `pressHaptic` triggers
  on the same boolean the wash does. That cannot be measured here — a simulator
  logs "Haptics: unsupported" — so it is recorded as a consequence rather than
  as a number, and it is [item 17](#17-one-pass-on-a-real-device)'s first
  question. Deleting the press haptic is the fix already on that table.
- **Scrolling itself is unchanged.** Same synthesized 120pt drag starting on a
  row, displacement read two seconds after release, six runs per side: 306–319pt
  with the delay on, 298–316pt with it off, ranges overlapping. Reorder,
  swipe-to-delete and the log path are unaffected, each driven one at a time.
- **Unchecked, and reasoning rather than measurement: a flick that starts on the
  reorder handle.** Settings' handle carries a `DragGesture(minimumDistance: 4)`
  as a `highPriorityGesture`, and it is fed by the delivery this one line
  changed — it used to see nothing until the scroll view had had its ~150ms to
  claim the touch, and now it sees the touch on the first frame and can win at
  4pt. `reorderGesture`'s `onEnded` commits from wherever the finger lets go, so
  if the drag wins that race a scroll rewrites the stored order. It needs a
  synthesized flick, not a thumb. If it reproduces, the cheap answer is a larger
  `minimumDistance`, since a reorder always starts from a finger that has
  already stopped.

**The second option was not built.** Driving the pressed state from a
`DragGesture(minimumDistance: 0)` is more code, it fights the scroll gesture it
would have to live beside, and it can only reach rows this app draws itself —
*Add Tracker*, *Share JSON…* and the *About* link wear the system's own
highlight, and the one line above fixes those too.

**The tension worth writing down.** PHILOSOPHY.md says boring and native, and
this is now one step off native: the app presses faster than iOS's own settings
list does. It also says nothing should animate that you have to wait for, and
150ms of no feedback at all is the purest case of that. The second rule wins,
because a person using the app reported the first one costing him something —
which is the only evidence either rule was ever going to get.

## 41. The home screen label is `Boring`, for a reason that is not true — done

**Changed to `Boring Tracker`.** iOS truncates a home screen label on rendered
*width* and not at some character count, the full name fits on both an iPhone 17
and a 375pt SE, and the short label cost every Spotlight search for the word the
app is named after. `0100a9e`, `82cf49c`, `2c19216`

The widths, the Spotlight results either way, and the new-app dot that looks
exactly like truncation and is not, are in [SHIPPING.md](SHIPPING.md).

## 42. The card `+` as an outlined ring — decided, done

**The ring ships, and the filled disc stays behind `CardPlus.outlined`.** Anton
picked the ring on 2026-08-20 and that choice is settled. `9f46446` went further
and deleted the loser, which is not what he asked for — *"dont delete for now, i
dont care, we can do later"* — and `d1c1d38` put it back. `68a6493`, `d0d6f55`,
`2af7a24`, `1361702`

**Deleting the disc waits on the device pass,
[item 17](#17-one-pass-on-a-real-device).** The ring has only ever been seen in
simulator screenshots, so while the comparison can still be lost, going back is
one line rather than unpicking a commit. Once the ring survives real use, what
goes is that branch, the mark it names, `plusMark` itself — a chooser between
one thing is not a chooser — and the `CardPlus` enum, leaving `logButton` naming
`CardPlusRing()` directly.

**What the disc knew, kept because its comment goes when it does.** It started
as a bare blue glyph, which was a different design language from the bottom Log
button it is a smaller version of, and low enough contrast that it did not read
as a control at all. A tinted `.bordered` fill was tried next, on the grounds
that eight solid dots down one screen is loud — and rejected on the original
complaint, because a blue glyph on a pale blue disc is that same low contrast
again. The accent-filled disc is what came out of that.

**The ratios are the shipped icon's**, sampled out of
`boring-tracker-1024.png`'s own IDAT bytes rather than through a colour-managed
reader. `CardPlus` names this item as where they are, so they stay here:

| what | px at 1024 | ÷ ring outer Ø | at 30pt |
|---|---|---|---|
| ring outer Ø | 702 | 1.0 | 30 |
| ring stroke | 48 | 0.0684 | 2.05 → **2** |
| plus overall width | 330 | 0.470 | 14.10 |
| plus arm thickness | 50 | 0.0712 | 2.14 |

The arms (50) and the stroke (48) are within 4% of each other, and **reading as
one weight is the property being copied**. The glyph is
`.font(.system(size: 17, weight: .semibold))`, arrived at by rendering nine
weights and then a ladder of sizes and counting pixels at 3× — no metric was
read off a documentation page. Weight first, because the arm-to-width ratio
belongs to the weight alone: `.semibold` renders **0.1528** against the icon's
0.1516, `.bold` 0.1769, `.medium` 0.1340. Then size, linearly: at 17pt the plus
measures **14.00pt wide with 2.15pt arms** against the 14.10 / 2.14 wanted.
Nothing about the mark moves at AX3 — both marks are fixed by design, so what
grows is the card around them.

**The press fills the ring** with the full accent rather than
`AccentFillPressed`, which recedes toward its surface and does nothing visible
to a 2pt stroke, and the glyph flips to `Color.onAccent` with it. Both arrive
instantly and scaled up through the existing press machinery; nothing was added
for it. So **a pressed ring is what the resting disc was** — the honest inverse,
not a coincidence to design around.

## 43. A rate link on About, now that there is an id — done

A `Link` row above *Support*, to
`apps.apple.com/app/id6803768789?action=write-review`. About deliberately
shipped without one — `017267c` — because the URL needs the numeric App Store
id and there was no app; the id turned up with the *app record* on 2026-08-20
rather than with the release, which is earlier than SHIPPING.md assumed when it
filed this under "after the first release". `52567eb`, `c54da7e`, `5f18e9f`,
`2ea154e`

**A link, not a prompt** — and why, and why it sits above the Support message
rather than inside it, is in [PRODUCT.md](PRODUCT.md). The dead-link window
closed when 1.0 went on sale on 2026-09-04; the URL returns 200 after a 301 to
the listing.

**Still unverified: that the row lands on the store page.** The simulator has no
App Store app, so the handoff fails there — Safari refuses the URL as invalid,
and it refuses a *live* app's identical link the same way, which is what says
the failure is the simulator and not the URL.
[Item 17](#17-one-pass-on-a-real-device) is where it is checked.

## Noted, not scheduled

Wanted, not yet queued. Written down with the part that isn't obvious, so
picking one up doesn't start with rediscovering why it's awkward.

- [ ] **An unknown *key* is dropped on save, and an unknown *value* is not.**
      `Tracker.kindRaw` fixed the value half. The key half is real and
      unfixed: `Codable` ignores a key it has no property for, so a field a
      later version adds to a tracker, an entry or the document is gone from
      the next ordinary save this build makes — the same silent data loss the
      `kind` work exists to prevent, one level up. Checked rather than assumed,
      at `1e6479f`: a document carrying `colour` on a tracker, `mood` on an
      entry and a top-level `reminders` array decodes with every record intact
      and re-encodes with all three keys gone.

      **The window it can happen in is narrower than it looks**, which is why
      this is noted and not queued. A newer version that adds a field almost
      certainly bumps `schemaVersion`, and a newer `schemaVersion` is refused
      outright by `StoreMigration` — the file is quarantined intact, nothing is
      rewritten, nothing is lost. The loss needs a newer build that adds a
      field *without* bumping, which is exactly the case the `kind` change was
      bought for and the one a future version has to be disciplined about.

      Fixing it properly is a design change, not a patch: every model type
      grows an `[String: JSONValue]` of leftovers, a hand-written `init(from:)`
      and `encode(to:)` to fill and re-emit it, a `JSONValue` type the app
      otherwise has no use for, and an answer to what merge does when two
      devices hold different leftovers under the same id. That is a real
      session with its own tests, and it should be measured against what the
      schema-version refusal already covers before anyone starts.

- [ ] **What a press should do to an accent fill too small to take 4pt.**
      `AccentFillPress.scale(for:reduceMotion:)` moves each end of the fill's
      longest edge 2pt, and outward since item 37. A fill shorter than 4pt is
      at least doubled by that; it is guarded at `2 * travel` and falls back to
      not scaling. What the guard does *not* cover is the range just above it —
      a 6pt fill solves to 1.67 and a 10pt one to 1.4, which reads as a control
      appearing rather than a control pressed. The same range read 0.33 and 0.6
      while the press shrank, and the boundary itself was worse then: a
      negative scale mirrored the fill rather than merely overstating it.

      Not guarded, deliberately, and this is the awkward part: every fix is a
      number nobody has measured. A floor on the scale, or `min(travel,
      longest / 8)`, both pick a threshold by taste on a case that does not
      exist — the smallest accent fill in the app is a 30pt disc, which is
      three times clear of it. Raised in review on item 27 and left, because
      the repo's own rule is that a best practice needs a concrete failure it
      would prevent. **The failure would be real when a small fill is actually
      added** — a badge, a dot, an indicator between 5 and 12pt — and whoever
      adds it should measure a press on it rather than trusting a rule
      extrapolated from a pill twenty times its length.

- [x] **What the reorder footer should say when there is only one section.**
      The sentence is worth a branch, and the string is split rather than the
      footer gated: `SettingsView.reorderHint(runs:)` keeps "Drag a tracker's
      handle to reorder." under `canReorder`, which is unchanged and right, and
      adds the second sentence only where the drop it describes can happen.

      **Two conditions, not one, because there are two ways for it to be
      untrue.** It needs somewhere to cross to — `runs.count > 1` — *and* a
      block holding more than the row you grabbed, or "its whole group" names
      the tracker already under your finger and says nothing the first sentence
      did not. The welcome screen reaches both misses: the two preselected
      starters are both in *Food*, so they are one run, and Calories beside
      Weight is two runs of one. Photographed on an iPhone 17 Pro in all three
      shapes plus the one-tracker list, which still has no handle and no footer.

      Dropping the sentence outright was the other legitimate answer and is not
      taken: a drag that moves four rows when you grabbed one is the surprising
      half of this control, and the only other sentence does not cover it.

      **"Groups", not "sections"** — this string was the last user-facing
      survivor of the rename in `0862976`, and its own second half already said
      *group*. Three tests, `@MainActor` like `HistoryTests` because a `View`'s
      statics are isolated with it.

- [x] **What the gap between two halves of a stacked row should be.** Two, and
      it stays. Looked at again on an iPhone 17 Pro at `.xxxLarge`, AX1 and AX5,
      light and dark, and closed unchanged.

      The gaps are equal and the lines are not, which is the whole answer: a
      stacked History row is a grey footnote, a large primary value and a grey
      footnote, so the value is bracketed by the two quiet lines and the
      hierarchy is carried by size and colour exactly as it is on the
      side-by-side branch. **All four callers have that shape** — the leading
      half always ends on the loud line and the trailing half is always the
      quiet one — so there is no row where the 2pt gap joins two things that
      look alike. Between *rows* the gap is 8pt of `.listRow` insets and a
      separator, so nothing runs together either.

      **What a second number would cost, since the note asked.** A parameter on
      `StackingRow` hands the arrangement to the caller, and the arrangement is
      the one thing that file exists to keep identical across home's card and
      the three lists — its own comment says the alignment is not a parameter
      for that reason. Changing the constant instead changes home's card, where
      the 2 was measured. And it would only apply from `.xxxLarge` up, which is
      six of the twelve sizes and exactly the six where vertical room is
      scarcest: 4pt a row, to make a distinction the colour already makes.

- [x] **What the gap between two days should be, now that there is no card.**
      Fixed at the top of the list and left alone between days, because that is
      where the measurements put it. `.contentMargins(.top, 0, for:
      .scrollContent)` on History's `List` gives back the band an inset-grouped
      list reserves for a section heading — the whole log is one `Section` with
      no heading, so the band was **35 points of empty screen** above the first
      day. `RepeatView` gives back the same band and takes 8; History takes 0,
      because the day heading under it already carries 18 points of its own top
      inset, and stacking a second gap on the first is the thing being removed.

      **`listRowInsets(top: 18, bottom: 6)` costs nothing and stays.** The day
      heading row has a floor of 52 points — the same height as a log row — and
      it only grows once top + text + bottom passes it: measured on an iPhone 17
      Pro, 18/6, 8/6 and 0/0 all draw a 52-point row and an identical list, and
      30/6 is the first that moves anything. What the 18 buys is where the text
      sits inside that row: 21.8 points above it and 9.8 below, so the heading
      hugs the day under it. At 0/0 it centres, and the day heading floats
      between two days instead of belonging to one.

      **The 3.0% and the 17 points a day were a measurement artefact, and are
      withdrawn** — the table and the reason are in docs/scale.md. `contentSize`
      read on arrival under-reports a card-per-day list by 21–22 points a *day*
      until every cell has been laid out, and does not under-report a
      one-section list at all. Measured again against a card-per-day build of
      this code, one section is **5.83 points a day shorter**, not 17 taller.
      The 47 points is real: 35 of it was the band, and the remaining 12 is the
      heading being a 52-point row rather than a 40.33-point section header,
      which two days of the saving pays back.

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

      **The review found that last paragraph half true, and it is now whole.**
      Deciding *membership* on listable is right, but the row's *content* was
      being decided on it too — so a batch that logged a live daily total
      beside one you have since archived was drawn with both values while a tap
      wrote only the live one. On an iPhone 17: a lunch of 300 kcal and 20 g of
      an archived Protein listed as "300 kcal, 20 g" with a live disc, and the
      bar said "Logged 1 of 2 again" from the very screen this item exists to
      keep honest. The projection now runs twice — listable to decide whether
      the row is here at all, writable to decide what it shows — and the
      listable row is kept only where writable leaves nothing, which is the
      fully archived row item 16 protects. Two tests, and the greyed
      "shake · Archived" row is unchanged.

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
      inset.

      **Corrected in review: it is not below the fold, and nothing about it
      depends on being.** This entry and the code comment both said "four or
      more trackers and it is below the fold". Measured on the iPhone 17 the
      work was checked on (1206×2622, default type size, loose cards with no
      groups): nine cards still leave the row fully visible above the Log bar,
      and it takes ten to push it off the screen — so on any realistic set it
      is on screen. What keeps it out of the way is that it is grey text and
      not a card, which is the claim that did survive checking. The row does
      scroll rather than pin, which is the thing that mattered: at ten cards it
      is off the screen at rest and comes back by scrolling.

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

**Nothing is open here.** What it has held is below, collapsed like any other
done item.

- [x] **A tracker detail row is taller than the History row it now matches** —
      74pt against 52, both 52 now. Decided rather than just fixed: detail takes
      `.listRow` whole, including the trailing 12 that was sized for a repeat
      disc it does not have, because a private set of insets for the one screen
      with no trailing control is exactly the drift this note was about.
      `f2ce523`
- [x] **Export through the share sheet** — done in item 18b. The platform bug
      that made it hard, the eight-way bisect that found it, and the reason
      those two settings sections must not be merged back together are in
      [TECH.md](TECH.md). `dd25193`, `3028257`, `35a5fd0`
- [x] **XcodeGen churns `TEMP_…` UUIDs on every regenerate** — fixed by moving
      `Signing.xcconfig` into `Config/`. A config file has to live in a folder;
      why is in [TECH.md](TECH.md). `cf6ea27`
- [x] **`validateImport` never looks at a tracker's name** — an empty one is
      refused at the import boundary now, naming the id, and **refused rather
      than repaired**. It sits beside `validateImport` rather than inside it,
      because `restoreImportBackup` runs that one too. [TECH.md](TECH.md).
      `c31c0ff`
- [x] **`(max ?? -1) + 1` traps on `Int.max`** — already guarded in `a1c42a5`;
      what was missing was a test for the value arriving the way import cannot
      stop it, in the store file this device wrote. With the guard removed the
      first of those tests kills the test process rather than failing an
      expectation, which is what a Swift overflow does. `66438a3`
- [x] **The log sheet has no signposted exit** since Cancel was removed.
      `.presentationDragIndicator(.visible)`, on the `NavigationStack` rather
      than the `Form` because it is a property of the presentation. It costs
      nothing: against the same build without it, the only rows of the
      screenshot that differ are the grabber's own 15px. `820feac`
- [x] **Releasing a settings drag outside the list commits it** rather than
      cancelling — deliberate, and in [PRODUCT.md](PRODUCT.md). The reason first
      recorded here was wrong and was corrected: it is not that requiring the
      finger inside would break reaching the first row (116…254 already picks
      it), it is tolerance — `row(nearest:)` answers at every y, so a refusal
      would disambiguate nothing and would throw away a drag released a few
      points past an edge the finger cannot see. `91217ab`, `4b7fa32`

## After v1

- [x] **A "last time" kind, where the date is the data** — pulled into v1 and
      shipped. It is item 39 above.

- [ ] **A graph for a "last time" tracker.** Anton: "for 'last time' tracker we
      also need some graphs, but we can put it on later todo." The kind shipped
      without one deliberately and the screen is bare because of it.

      **It is not either of the graphs the app already draws.** Both of those
      read a number off each entry — bars for a daily total, a line with a
      moving average for a measurement — and a last-time entry has no number to
      read. The series worth drawing is the **interval between events**: how
      long the filter actually lasted each time, one value per gap. That
      changes the shape as well as the source. There are n−1 points for n
      events, nothing at all to draw until the second one, no day to aggregate
      into, and the unit is days rather than whatever the tracker measures —
      it measures nothing.

      Worth deciding with it: whether the run in progress is on the chart. The
      interesting number when you open the screen is usually "it has been 90
      days and the last three were 60" — which is a bar that has not finished
      yet, and every other graph in the app only draws what has happened.

      `PRODUCT.md` and `TrackerDetailView` both say today that the interval is
      "a different idea this kind deliberately does not have". That sentence is
      what this item would be reopening, and it is why this is post-v1 rather
      than a small thing.

- [ ] Home screen widget, Lock Screen widget, App Shortcuts / Siri.
- [ ] Sync transport — the document already merges; this is only plumbing.
- [ ] Apple Watch.

### A welcome screen that sets units and picks the starting trackers

One screen on first launch: pick the **unit system**, and pick which trackers
to start with. **The same screen after "clear all data"**, which is the other
moment the app has no trackers and no idea what you want.

It replaces `Tracker.starterSet`, and it fixes three things that are each too
small to schedule alone:

- **The starter set has no `lastTime` tracker.** It is Calories, Protein and
  Weight — the macro-tracking origin story. So the newest kind is invisible on
  first run, while the App Store screenshot advertises it ("Water filter —
  2 months ago") and the README names it. The feature most likely to be missed
  is the one nothing introduces.
- **The weight unit is `kg` regardless of locale.** The US is the largest App
  Store market and gets kilograms. `Locale.current.measurementSystem` is the
  obvious default to offer, not to impose.
- **A fresh install and a cleared install disagree.** `StoreFile` seeds
  `.starter` on a genuinely fresh launch; `Store.clearAll()` writes an empty
  `StoreDocument()`, so clearing leaves the "No trackers" empty state instead.
  Neither is wrong, but nothing decided they should differ.

**The risk is that this becomes onboarding.** PHILOSOPHY.md rules out the
tour, the carousel, the account, the permission pre-prompt and the "you're all
set!" screen, and an app whose pitch is that it opens straight to a number pad
cannot greet people with three slides. So: **one screen, skippable, no
animation, and never seen again** unless data is cleared. If it cannot be one
screen, it is not worth having — the hardcoded three are a fine fallback.

Open: whether "skip" means the current three or nothing at all.

### iPad — original deferred brief

Deferred deliberately for 1.0 — `TARGETED_DEVICE_FAMILY` is `1`, and the
decision is recorded in `SHIPPING.md` as *Decide whether this is an iPhone app
or a universal one*. Anton wants it queued now that 1.0 has shipped.

**The build change is one line and it is the least of it.** What actually has
to be answered:

- **The bottom bar.** Home's Log pill and Log again disc are sized and placed
  for a thumb at the bottom of a phone. On a 13-inch iPad that corner is
  nowhere near a hand. Where the primary action lives is the whole design
  question, and getting it wrong makes the app worse on iPad than on iPhone.
- **The number pad.** The fastest path on a phone is a keypad under the thumb.
  An iPad has a hardware keyboard half the time, and a soft keyboard that is
  enormous. Whether the sheet stays a keypad is open.
- **Width.** A single column of cards across a 1024pt-wide screen looks broken.
  `NavigationSplitView` is the native answer — trackers on the left, history or
  a tracker on the right — but that is a second navigation model to keep true,
  and every screen has to work in both.
- **Size classes and multitasking.** Split View and Slide Over mean the app
  gets phone-shaped widths on an iPad and has to switch between layouts while
  running, not just at launch.

**The rule that keeps it honest: iPad gets no feature iPhone does not have.**
The moment the two diverge there are two apps to keep true, and `PHILOSOPHY.md`
is written for one. iPad is the same app at a different size.

Also required before it can ship: **iPad screenshots** for the listing, in
whatever sizes Apple demands at the time — the 1.0 set is iPhone-only and
`APPSTORE.md` says so.

Not scheduled against a version. It is the largest open piece of work in this
file and it should not start while 1.1 is unfinished.

### The welcome screen's introduction sounds alien

Anton, after using it: *"the only thing is the text 'start creates a tracker,
you tick' all sounds alien. You basically need to ask user to choose default
trackers and say that later you can always change that. In some normal english
way I dunno."*

Current: `Write down a number, done. Start creates the trackers you tick.`
The second sentence describes what the button does internally. Nobody says
that. It should ask the person to choose what they want to track and say they
can change it later, plainly.

**It cannot simply gain words.** `111c023` shortened this intro specifically so
the first tracker row clears AX4, and one of the phrases cut for space was
"you can change all of it later" — exactly what is now wanted back. The budget
has to come from somewhere, and it exists: *"Write down a number, done."* is a
pitch line for somebody deciding whether to install. They have installed it.

The reassurance may also already be there and failing: the Units footer reads
`A starting point.`, which was the justification for cutting the longer phrase.
He did not notice it, which is evidence it is not working where it sits.

**Re-run the text-size sweep after any change** — method in `111c023`. AX4 must
pass with margin. A copy change is exactly how that fix gets quietly undone.

### The welcome screen is a one-way door

Raised by the review of `af31f2b`…`111c023` and deliberately not fixed.

Start is the only exit and it creates trackers. With home's chrome hidden,
**Settings — and so Import and Restore Previous Data — is behind it.** Every
non-fresh way of arriving here is a recovery situation: an unreadable store,
Delete All Data, a replace-import of an empty document (`validateImport`
permits one).

Nothing is lost — the recovery slot survives, so it costs one tap and then
deleting trackers nobody wanted. But **somebody whose data just failed to load
is offered a setup list rather than a way back to it.**

Not fixed because hiding the chrome was an explicit instruction, and the
obvious fix — showing the gear when `store.origin` is `.unreadable`, or when an
import backup exists — is a design call on a screen already iterated twice.

### iPad: the scope, decided

For 1.1 the single-stack, centered-column design above is implemented. The
iPad simulator pass covered portrait, a resized 375pt-wide window, native
sheets and software input, long lists, and AX5 text. Independent review
found no actionable issue.

**Landscape is photographed and closed** (2026-09-16). The 1.0→1.1 review had
flagged it as reasoned about rather than measured — every iPad screenshot in
`docs/screenshots/ipad/` is portrait — so it was shot: home with the bottom
bar, the log sheet with the floating keypad and again with the docked
keyboard, History, a tracker detail with its graph, and the welcome screen at
default, AX4 and AX5, on an 11-inch and a 13-inch iPad Pro under iOS 26.3 —
dark throughout, with home and History shot in light as well. Nothing is
clipped and nothing is unreachable: the Log pill sits where it does in
portrait, the 640pt column is unchanged by the wider screen, and where the
shorter window cuts a list off — the welcome screen at AX4 and AX5 — the
first tracker row still clears the Start bar and the rest scroll.

Two findings are worth knowing rather than fixing. **A rotation dismisses the
floating iPad keypad**, leaving the field focused and the keypad one tap away;
the docked keyboard survives the same rotation. It reproduced on both iPads
and in both appearances; whether any `.decimalPad` app behaves this way was
not tested against a control app, so the attribution to iOS is unverified.
And **iPadOS 26 has no Split View or Slide Over** — Settings offers Full
Screen Apps, Windowed Apps and Stage Manager — so that question is now window
resizing. Under Windowed Apps the app was resized while running from a
phone-shaped window to nearly the whole screen (374pt to 1117pt wide, read
from the simulator's accessibility geometry), once with the log sheet open
across the resize, and redrew correctly at both ends: `readableContent()`
branching on the idiom rather than the size class costs nothing, because below
640pt the cap is simply inert.

The real-iPad pass remains, including a hardware keyboard and live resizing by
hand. iPad listing screenshots have not been prepared. The original decision
below is kept as the scope that led to this implementation.

At this decision point, `TARGETED_DEVICE_FAMILY` was `1`. The four questions
were in the *iPad* entry under *After v1*. **Anton's constraint, which decided
most of them:**

> "lets do ipad, i have ipad to test if we need. It doesnt have to be well
> done, just good enough to work. Iphone is primary device."

So: **small and correct, not a great iPad app.** The bar is that it runs, does
not look broken, nothing is unreachable, and it is defensible in App Review.

- **Default to not adopting `NavigationSplitView`.** It is a second navigation
  model every screen has to stay true in, and that cost is what is being
  declined. Say what it would buy before recommending against it.
- The cheap honest answer is probably one layout, a readable max width so a
  column of cards does not stretch across 1024pt, and the bottom bar where it
  is. **Check that on a 13-inch rather than assuming.**
- The number pad almost certainly stays. It works; replacing it is a redesign.
- **Split View and size classes still have to not break** — that is
  correctness, not polish. The layout changes while running, not at launch.
- iPad gets no feature iPhone does not have.
- **iPad screenshots become required** for the listing; the 1.0 set is
  iPhone-only.
