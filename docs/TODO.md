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
  on hardware, which no simulator answers.
- [27. The bottom bar: presses you cannot see, and a pairing that looks
  wrong](#27-the-bottom-bar-presses-you-cannot-see-and-a-pairing-that-looks-wrong)
- [30. Confirm a log where the eye actually
  is](#30-confirm-a-log-where-the-eye-actually-is)
- [31. Light mode's accent is murky](#31-light-modes-accent-is-murky) — open on
  a decision the user makes, not on work. Why the light value is where it is is
  in [TECH.md](TECH.md).
- [Noted, not scheduled](#noted-not-scheduled) — real, unranked, no session
  assigned.
- [Small things, unscheduled](#small-things-unscheduled) — done in one pass
  whenever something goes near the same code.
- [After v1](#after-v1)

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
an item's argument is the only place a rule is written down — item 21's
kind-based repeatability and its three edge cases, item 25's rejected scrubber
and month index, the geometry in 33b — it stays where it is at full length. A
done item collapses when what it decided has genuinely moved to PRODUCT.md or
TECH.md, not merely because it is finished.

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
what it did re-run is every WCAG contrast ratio in items 13e and 18, all of
which reproduce exactly from their hex values, and the test suite. **That pass
recorded 281 tests and the suite is 277**, re-run on 2026-08-19 at `cb2e60e`
before item 32 touched it; 278 after. The count is corrected here rather than
argued about, and it is the kind of number this file now asks people to stop
writing down.

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

## 13e. Form buttons lost the only thing that said they were buttons — done

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
- [x] Decide whether a form action row is chrome, like a bar button, or writing,
      like a chart bar. **Chrome** — it is the case the nav bar already settled,
      arriving at the one other control the app has that cannot say "tappable"
      any other way. Unblocked by item 18, which gave light a value that clears
      the floor as a foreground: **3.59:1** on the row's `#FFFFFF`, against the
      system blue control's 3.52 and the system mint's failing 2.12.
- [x] It is `formRowAccent()`, at **six** call sites — *Share JSON…*, *Share
      CSV…*, *Import JSON*, *Restore Previous Data…*, *Add Tracker*, and
      *Source on GitHub*, which this item's list of five had missed. **Not
      `navBarAccent()` under a better name**, which is what this item expected:
      the two carve-outs are one idea with two mechanisms, and sharing a
      modifier would have shipped a defect either way round. See below.
- [x] **The About screen was the same bug one screen further out**, found by the
      review of this change. `Link("Source on GitHub")` draws its label in the
      environment tint, which is `.primary`, so it was the label colour with no
      chevron — pixel-identical to the static *Version* row above it, on the one
      row of that screen that goes anywhere.

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

**Two things this item asserted did not survive being checked.** The tracker
rows above *Add Tracker* do not keep a chevron because they are
`NavigationLink`s — `SettingsView.rowButton` is a `.plain` `Button` drawing
`Image(systemName: "chevron.right")` itself, in `.tertiary`. The affordance
argument is unchanged; the mechanism named for it was wrong, and it matters
because "the platform draws that chevron" is a belief under which somebody
deletes the image. And the list of affected rows was five, not six.

**Resolved by item 18's colour set, and the `.tint` this item kept assuming
turned out to be the wrong mechanism.** Both halves measured on an iPhone 17 Pro
/ iOS 26.3, reading the screenshots' own IDAT bytes:

| | `.tint` | `.foregroundStyle` |
|---|---|---|
| the row's SF Symbol | label colour — `#000000` light, `#FFFFFF` dark | the accent, with the text |
| the row when disabled | plain black, indistinguishable from a static row | `#7FCBC3`, a 50% blend that reads as off |

So `.foregroundStyle` at each row, which answers the icon question this item
raised — the glyph goes with the word, and there is no two-colour row.

**And that is why it is not one shared modifier.** The same test run the other
way says the opposite for a bar button: `TrackerEditor`'s *Save*, disabled with
an empty name, draws `#B0B0B2` grey under `.tint` and the full `#009888` under
`.foregroundStyle` — a dead button that reads as live. `navBarAccent()` keeps
`.tint` and keeps its name; `formRowAccent()` is `.foregroundStyle`. One name
over both would have taken a defect with it whichever mechanism won.

**`.alert` and `.confirmationDialog` did not need deciding after all.** This
item expected a section-level tint to reach them; the accent is stated per row
instead, so nothing is applied to those buttons and they are unchanged. That
was not re-tested — there was nothing left to test — and a button in a dialog is
already unmistakably a button. Naming each row is also what keeps *Delete All
Data…* red rather than accented.

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

**Two questions about a press that only a thumb can answer.** Neither is about
whether a press draws — item 32 settled that at 60fps, on taps down to 40ms —
and both are about how one *feels*.

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
      **this** app, on the write-a-review sheet. If the listing is not public
      yet, the check waits for it rather than being reported as passed.

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

Both halves are in: the colour set below, and the icon itself — the `ledger`
candidate `docs/SHIPPING.md` recommended, chosen by the user and installed from
`~/dev/boring-tracker-icon/final/` without a pixel changed.

The item originally argued that the accent had to become a colour set with light
and dark variants, because one system hue could not serve both appearances: the
teal measured 2.13:1 on a light-mode nav bar where the system blue Apple ships
measures 3.41:1. Item 13f then replaced that teal with a mint chosen from twelve
candidates measured on the real screens — **but that comparison was dark-mode
only**, at the user's direction, because dark is what this app is used in, so
the question reopened as a smaller one: does the mint need the colour set too?

It does.

- [x] **Measure mint in light mode**: as a nav bar tint, as a `Form` button
      foreground, and as a fill behind a dark label. **It fails, on both
      foreground uses**, and the constraint binds after all.
- [x] **Build the colour set.** `AccentFill` in a new asset catalog: `#009888`
      light, `#00DAC3` dark.
- [x] 13e resolves with it — the `Form` action rows have their colour back.
- [x] **Then the app icon.** `AppIcon.appiconset` holds one image — the 1024
      square, byte-identical to the source — because Xcode has derived every
      smaller size from it since Xcode 14, and a hand-cut ladder would be the
      same artwork to keep in sync in four places. The source is flat RGB with
      no alpha channel (PNG colour type 2, no `tRNS`) and its four corners are
      all `#00786C`, so nothing is pre-rounded and iOS applies its own mask
      once. `ASSETCATALOG_COMPILER_APPICON_NAME` is `AppIcon` in `project.yml`,
      which was deliberately empty until there was something to point it at.
      Seen on the simulator home screen, in Spotlight and in Settings › Apps,
      light and dark.

**The numbers.** iPhone 17 Pro / iOS 26.3, `simctl io screenshot`, sRGB-tagged
PNGs read through their own IDAT bytes rather than `NSBitmapImageRep` — black
reads `#000000` and white `#FFFFFF`, and so does every value between, which is
the part the old sanity check could not tell you. Each candidate rendered on the
real screens by a probe build that reports the argv it received, so a stale
install fails loudly. Contrast is the WCAG 2.x ratio against a 3:1 floor.

| | fill | nav-bar glyph on `#FBFBFF` | `Form` row fg on `#FFFFFF` | black label on the fill |
|---|---|---|---|---|
| **mint, light** — `Color(.systemMint)` | `#00C8B3` | **2.05** | **2.12** | 9.91 |
| **blue, light** — the control Apple ships | `#0088FF` | 3.41 | 3.52 | 5.97 |
| **the new light value** | `#009888` | 3.48 | 3.59 | 5.85 |
| *mint, dark — unchanged, for reference* | `#00DAC3` | 9.89 (on `#191919`) | 9.57 (on `#1C1C1E`) | 11.82 |

**`#009888` is the mint darkened, not a new colour.** Same hue (173.7°) and the
same full saturation as `Color(.systemMint)`, brightness taken down until it
measures what the system blue measures on those two surfaces — which is the
honest reference, since it is the one Apple tuned that bar for. The window is
narrower than it looks: `#00A493` clears the bar circle by 0.02 and `#009081` is
deeper than the mint has to be. Both were rendered before this one was picked.

**Dark did not move.** The dark value is the byte the system mint already
rendered, and the check is a pixel diff rather than an assurance: the settings
screen before and after is a **byte-identical** PNG, and home differs in six
near-black anti-aliasing pixels, each off by one.

**What did not need building.** `Color.onAccent` stays black. The new light
value would carry iOS's white label at 3.59:1, so for the first time a label
that flipped with the appearance would be legal in both — it stays black because
the dark value has no such choice at 1.78:1, and one control should not be two
designs. The colour set is called `AccentFill` and not `AccentColor` for the
reason in `OnAccent.swift`: the magic name would restore the inherited tint item
13c removed, by filename.

The reasoning that survived from the old version was right: a single hue serving
two appearances is a real constraint, and where it binds, a colour set is the
answer rather than abandoning system colours. It binds here.

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

Size is not the problem it appears to be. **The two numbers first written here
were the pre-measurement estimate and they were both low** — five years of heavy
use is 8.6 MB and decodes in 122 ms, not 2 MB and 41 ms (docs/scale.md). The
conclusion survives the correction and is now measured rather than reasoned:
the ids really are 35.6% of the file, and a build against a `batchID`-free
document loads in 137–142 ms against 149–162 ms. That is about 11 ms, against
the 1.5 s that opening History used to cost — so the file's size is not where
this app's problem was. The file is also deliberately pretty-printed with sorted
keys, which costs more than the id length does; shrinking ids while keeping that
would be optimising the smaller half of a cost we chose on purpose.

The honest argument the other way is readability, since the file is meant to be
opened and read. But you read names and values; ids are noise at any length.

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

## 27. The bottom bar: presses you cannot see, and a pairing that looks wrong

Both from real use, both on the pair of controls at the bottom of home.

### The pressed state still is not visible

Item 26 gave every accent fill one pressed colour and measured it — and it is
still hard to notice on Log and Log again. **The measurement was satisfied and
the goal was not**, which means the target was wrong, not the work.

So change the mechanism, not the number. **A scale on press is the primary
fix** — the button should physically respond under the thumb, the way iOS's own
prominent buttons do. Colour is secondary and already measured; it was not
enough on its own and more of it will not become enough.

`PHILOSOPHY.md` rules out bounce, confetti and celebration, and animations you
have to wait for. **A press-down scale is none of those** — it is instantaneous
feedback under a thumb, and it is what iOS itself does. Earlier guidance to
prefer colour over motion was mine and it was wrong in practice.

- [x] **Make it feel like a button.** Done in `71a1925`: the fill goes down 2pt
      at each end of its longest edge, whatever size it is, in 66ms and back in
      82ms. A ratio was rejected — 0.97 moves the pill 4.4pt and a disc 0.45,
      and the disc is half of what this was reported for.
- [x] Whatever it is, it applies to **every** accent fill. One modifier,
      `accentFilled(_:)`, replaces four hand-written backgrounds; all five
      controls were photographed held down and all five move 2pt.

      Re-photographed in review on an iPhone 17 in dark, six controls this
      time, in points off 3x screenshots of a synthesized press held down:

      | control | rest | held | each end |
      |---|---|---|---|
      | Log, home bar | 292.0x50.0 at 16.0,784.0 | 288.0x49.3 at 18.0,784.3 | 2.0pt |
      | Log, log sheet | 52.7x34.0 at 333.3,525.0 | 48.7x31.3 at 335.3,526.3 | 2.0pt |
      | Undo capsule | 65.3x32.0 at 320.7,750.0 | 61.3x30.0 at 322.7,751.0 | 2.0pt |
      | a card's + | 30.0x30.0 at 337.0,167.3 | 26.0x26.0 at 339.0,169.3 | 2.0pt |
      | Log again, home bar | 30.0x30.0 at 336.0,794.0 | 26.0x26.0 at 338.0,796.0 | 2.0pt |
      | History's repeat disc | 30.0x30.0 at 337.0,370.0 | 26.0x26.0 at 339.0,372.0 | 2.0pt |

      Every one of them `#00DAC3` at rest and `#07AA9A` held. The disabled
      disc on History's measurement row is `#636366` and does not move or
      recolour when held, so the state item `1947688` restored is intact.

- [x] **Reduce Motion took none of it, and does now.** Found in review: the
      scale shipped ungated, so a phone with the setting on rendered the held
      Log pill at the identical 288.0x49.3pt as one without it. The gate is on
      the scale only — the fill still crosses to `Color.accentFillPressed`
      over 0.12s, recorded at 60fps as a seven-frame, 100ms ramp — so a press
      under Reduce Motion is the app as item 26 left it rather than a control
      with no pressed state at all.

      The comment two lines from the gap said "the app has exactly one
      animation, and this is it — so this is the only place that has to ask",
      and this item is what made that false. Both places ask now.
- [ ] **The haptic is in and unfelt.** `.impact(.light)` on the press edge. The
      one thing that could be checked was that a scroll did not fire it, and at
      the time it did not: a flick that started on a Log again row never entered
      the pressed state. **Item 40 changed that** — with the list's delay off, a
      flick that starts on a row does press it, and the impact goes with the
      wash. Whether either *helps* cannot be answered in a simulator — UIKit
      logs "Haptics: unsupported" there and nothing reaches CoreHaptics.
      **Item 17's device pass keeps it or deletes it.**
- [ ] **The scale was judged by a synthesized press, not a thumb**, which is
      the same gap. Screenshots of a held control and a 60fps capture of the
      motion say it renders; they cannot say it feels like a press. Also item
      17.

**What was checked and was not true:** iOS's own prominent button does *not*
scale on press. Rebuilt with `.borderedProminent` and held down on an iPhone 17
Pro in dark, it renders 876×151 device pixels at the same origin as at rest —
identical to the pixel — and changes only its fill, `#00DAC3` to `#33E1CF`. The
paragraph above said the opposite. The decision stands on its own legs: colour
alone was tried and missed.

### The pairing looks wrong

The Log again control beside Log does not align and reads as poor taste — wrong
size, wrong relationship. It is currently a 70×51 glyph square against a 292×50
pill.

- [x] **Five alternatives rendered and photographed**, dark mode, iPhone 17 Pro,
      by a throwaway `-pairing <n>` probe in a worktree — the argv discriminator
      from the accent explorations, all five confirmed. The
      images are outside the repo in **`~/dev/boring-tracker-pairing/`**:
      `pairing-0.png` … `pairing-4.png` are whole screens and
      `pairing-strip.png` stacks the five bars for comparison.

      | # | what it is | what it is trying to do | pill |
      |---|---|---|---|
      | 0 | today: 30pt disc in a 70pt slot | the thing being complained about | 292 |
      | 1 | 50×50 accent circle | agree with the pill's height and its fully-round corner, and stop the control floating | 312 |
      | 2 | 50×50 rounded square, 16pt radius | the same, but echoing the *cards* rather than the pill | 312 |
      | 3 | 40×50 capsule | height and corner radius of the pill, at clearly less optical weight | 322 |
      | 4 | 30pt disc, gaps evened | keep today's weight and fix only the spacing: 16pt to the pill, 16pt to the margin | 324 |

      **Recommendation: 3.** It is the only one that agrees with the pill on all
      four of alignment, height, corner radius and weight — a shorter member of
      the same shape family, unmistakably the smaller of the two. 1 aligns just
      as well but is the heaviest, which is the peer problem arriving by size
      instead of by colour; 2 disagrees with the pill's radius and reads as an
      app icon parked in the bar; 4 is the tidy minimum and leaves the height
      mismatch that started this. Every alternative also gives the Log pill
      20–32pt back, because a 70pt slot around a 30pt disc is mostly air.
- [x] **Log again moves to the right, Log to the left.** Done in `4c93cc7`.
      It reverses the original placement, whose reasoning was that a right
      thumb rests bottom-right so the primary action should sit there — but the
      pill spans most of the bar either way, so it stays under the thumb
      wherever the small control goes. That argument was weaker than it looked.
- [x] **The user picks one.** Pairing 1, applied in item 33. The standing
      constraint still holds — a peer beside Log competes with it; two equal
      buttons were tried early on and read as a choice to make on arrival,
      which is a decision placed in front of logging. Swapping sides did not
      license making them equals, and neither does resizing.
- [x] Alignment, height, corner radius and optical weight should agree with the
      pill, whatever shape it ends up. All four do: 50pt against the pill's 50,
      a fully round corner against its capsule, and a sixth of its width.

The user picks from the photographs. Do not merge a favourite and call it
settled.

## 28. Rows should behave like controls — done

One problem wearing three faces, all three answered. `3cbf54a`, and four
review rounds' worth of corrections on top of it: `bd71d51`, `bb640b7`,
`ae12dd1`, `7be85d3`.

- [x] **Settings draws trackers at home's size now.** It drew them at **74pt
      against home's 52**, read off the accessibility tree on an iPhone 17 Pro,
      with the name at `.body` where home's is `.subheadline`. Home's numbers
      were settled in item 11, so they moved rather than a third size being
      chosen: `TrackerRowName` is the card's name block extracted, and the row
      metrics are `EdgeInsets.listRow`, one constant that home, History, the
      Log again sheet and settings all name. Both lists report 52 now, archived
      rows included — those carry the group as the caption, in the same
      `.caption2` home dates a reading in.

      **`.listRowInsets` has to be applied outside `.onGeometryChange`.** Under
      the reader settings uses for its drop target, it is silently dropped — the
      build compiles, the row draws, and it keeps the platform's 74pt. Two
      builds looked identical before the tree said why.

      **The first diagnosis blamed `.swipeActions` and was wrong**, because the
      fix moved the modifier past both at once and nothing isolated them. The
      third review round caught it by noticing that `HistoryRow` does the thing
      the comment forbade: insets inside the row, swipe outside, and it measures
      52pt. A probe build settled the rest — settings' archived rows in that same
      order measure 52, while the active rows under the geometry reader stay at
      74. One binary, both answers, read off the accessibility tree. Exactly the
      failure WORKFLOW.md's "always check, not just read" describes: the number
      was right and the mechanism beside it was invented.
- [x] **The whole row is the target.** A `Button` hit-tests its label's drawn
      content unless it is given a shape, and settings' row was a name and a
      chevron with a `Spacer` between them, so the middle — most of the width —
      was dead. `contentShape(.rect)` plus a 44pt `minHeight`. Tracker detail's
      rows had exactly the same hole between the value and the time and got the
      same fix. Checked by tapping the dead middle of a settings row and of a
      detail row: the tracker editor and the entry editor open.
- [x] **A row presses, and presses the same everywhere.** `RowButtonStyle`,
      `.buttonStyle(.row)`, on settings, History, the Log again sheet, tracker
      detail and home's cards. Two halves:

      - **The colour is iOS's own, measured rather than picked.** Settings has
        one row the platform draws itself — the `NavigationLink` to *About* —
        and it presses `#FFFFFF` → `#D1D1D6` in light and `#1C1C1E` → `#3A3A3C`
        in dark. Both are `UIColor.systemGray4` exactly, so that is the colour.
        The app's rows now read the same two values on the same surfaces; on
        the Log again sheet, whose rows are `#2C2C2C`, the press lands at
        `#48484A` — the same step, through the presentation's own compositing.
      - **The movement is item 27's, reused.** `AccentFillPress` — 2pt off each
        end of the longest edge, 0.12s easeOut. Measured on a home card by the
        total's trailing edge: **961 device pixels at rest, 955 held**, which
        is exactly 2pt at 3x.
- [x] **Reduce Motion gets the colour and not the movement**, through item 27's
      gate rather than a second one: `AccentFillPress.scale(for:reduceMotion:)`
      already answers 1 for the setting. Proved as a counterfactual on one
      binary — with the setting on, the same press leaves that trailing edge at
      **961** and still paints `#3A3A3C` behind the row.
- [ ] **Judged by a synthesized press, not a thumb.** Item 26's lesson is that
      a perceptual goal is not a number, and what is above is screenshots of a
      held row, not a hand. It reads as unmistakable in the images and it is the
      platform's own colour, which is the best a simulator can say. **Item 17's
      device pass is what settles it**, with the haptic and item 27's scale.

**A row wearing this draws into its own layer, and it costs 14,485 pixels at
rest.** Text rasterised inside a `visualEffect` lands fractionally differently,
so home at rest differs from the build before this in 14,485 of 3,162,132 pixels
— 0.46%, the widest single move being a card's total one point narrower on its
leading edge with its trailing edge unmoved. Deleting the `visualEffect` line
makes home byte-identical to before, which is how the cause was pinned. Kept:
the alternative is a row press with no movement in it.

**It does not cost the scroll**, which is the question a per-row layer actually
raises now that the style is on History. A `CADisplayLink` probe, eight scripted
flings over a 3,200-row History (8,000 entries) on an iPhone 17 Pro simulator,
960 frame intervals a run, against a build with only the `visualEffect` line
deleted:

| build | median | p95 | frames >20ms | frames >33ms |
|---|---|---|---|---|
| Debug, with | 16.67 | 16.67 | 25, 27, 24 | 18, 18, 17 |
| Debug, without | 16.67 | 16.67 | 20, 21, 24 | 12, 13, 14 |
| Release, with | 16.67 | 16.67 | 20, 19 | 14, 12 |
| Release, without | 16.67 | 16.67 | 20, 26 | 16, 16 |

Median and p95 are a full 60fps frame in every run of both builds. The tails do
not separate — Debug leans against the scale by about five frames in 960 and
Release leans the other way by about the same — so that is noise, not a cost.
The 250–280ms frame both builds show is History's first build on that fixture,
with the line and without it.

**What a Log again row gives up.** It was `.buttonStyle(.accentFill)` so that
the disc inside it recoloured on press; it is `.row` now, so the whole row goes
down and greys and the disc only moves with it. Handing the accent's pressed
state down as well would scale the disc twice. On History and home the disc is
its own button inside a row that does something else, so those two keep
`.accentFill` and are unchanged.

**The wash stops short of the trailing edge on three of the five screens**,
and that is a design call rather than an oversight. A History row, a home card
and an *active* settings row each pair the button with something that is not
part of it — a repeat disc, a `+`, a drag handle — so the highlight ends where
that 44pt box begins: measured on a pressed settings row, 282pt of the card's
366, stopping 66pt short. iOS's own `NavigationLink`, the row this colour was
sampled from, fills the whole cell. What does span is an archived settings row,
which has no handle, and a Log again row. Kept, on the argument that a row with
a second control in it is two controls and washing the half you hit says which
one you got. Filling the row instead means lifting the press state into a
`@State` on every row of five screens, two of which build their rows in methods
on the enclosing view. (Written as "two of five" first, which missed settings'
own handle — the fourth review round counted it.)

**Every `.row` button is at least 44pt tall**, which is one line in the style
and does two things. It makes the wash the same height on every screen — before
it, the same press painted 26pt on a home card, 38 on a History row and 44 on a
settings row, all inside 52pt rows, so one screen showed a pill around the words
and another a pressed row. And it gives two rows a target they never had: a
tracker detail row's label was 40pt and home's *Add Tracker* about 22, both under
Apple's 44. Measured against a build with that one line deleted, it costs height
only where the row was short — detail's entries **68pt to 74**, *Add Tracker*
**51 to 55** — and every row that already held a 44pt control stays at 52 to the
point.

**The haptic now covers most of the app's touch area, and item 17 should weigh
that.** `pressHaptic` was on three small deliberate targets and is now on every
row as well. A flick does not fire it — with no pause a drag leaves a settings
row at `#1C1C1E` for the whole gesture — but a finger that rests does, and the
row is at `#3A3A3C` within 0.3s, so dragging away after that cancels the tap and
not the impact. That is item 27's "press called off" on a much bigger surface,
and it is the strongest argument yet for deleting the haptic outright.

## 29. Sort Log again chronologically — done

Most recently logged first. `703894a`

- [x] Most recently logged first. The list is `canRepeat`, then the row's date
      descending, then `sortID` — three comparisons where there were five.
- [x] Rows that cannot be repeated still sort below everything that can. It was
      already the first comparison and it stays the first comparison: the rule
      is about what a tap can do, not about order.
- [x] Deduplication is untouched. One row per distinct name-and-values, dated
      by the last time it was logged, projected onto what a tap writes before
      it is collapsed.
- [x] **It did not get slower.** Ten runs each, the frequency order rebuilt in a
      temporary test and **alternating with this one in a single binary**, Debug
      on the iPhone 17 simulator, over fixtures of four named meal batches, two
      unnamed totals, a water and a weight a day, ending on the store's today.
      Medians with ranges, in ms:

      | shape | entries | rows | chronological | frequency |
      |---|---|---|---|---|
      | collapsing | 7,644 | 7 | 21.3 (20.3–22.7) | 21.6 (20.8–22.9) |
      | collapsing | 15,288 | 7 | 41.6 (41.0–42.2) | 41.9 (41.3–42.5) |
      | nothing collapses | 7,644 | 4,459 | 25.9 (25.1–26.4) | 26.4 (26.2–27.0) |
      | nothing collapses | 15,288 | 8,918 | 52.3 (51.7–54.3) | 53.3 (52.5–55.3) |

      Chronological is the faster column in all four, by 0.3–1.0ms of median,
      and every range overlaps — so the honest reading is that the difference
      does not register, not that dropping the counts bought anything. A second
      run reproduced every figure within 0.5ms. Still built once when the sheet
      opens, and a search keystroke still filters the snapshot.

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

## 30. Confirm a log where the eye actually is

Logging from Log again does not feel like anything happened.

**The diagnosis is placement, not strength.** The number counts up on the home
card and the undo bar appears on home — both *behind* the sheet you are looking
at. Item 15's animation is real and correct and you cannot see it from here. A
session already noticed the same thing about repeating from History: "a repeat
from History animates a card nobody is looking at", and left it.

So the acknowledgement has to happen **on the row you tapped**, or on the way
out, or both.

Things to try, and judge by thumb rather than by argument:

- [ ] **The row itself confirms** — built, recorded, and it **cannot work**.
      `dismiss()` stops a presentation's content updating, so a checkmark set
      on the same tap as the dismissal is never drawn: the sheet slides away
      for about 300ms showing the state it had before the tap. Held for 0ms and
      for 50ms the mark still never appeared; at 500ms it did. That is a delay
      on the most repeated action in the app and the rule below forbids it, so
      the row is not where this goes. Recorded at 60fps on an iPhone 17 Pro
      with a synthesized tap.
- [x] **A success haptic**, distinct from item 27's press haptic. `.success`
      against the press's `.impact(.light)`, so the two say "touched" and
      "written" rather than "touched" twice. One modifier, `logHaptic(_:)`,
      on home and on History. Unfelt in a simulator like every haptic here —
      item 17's device pass keeps it or deletes it.
- [x] **The dismissal carries the information.** Home's Log again disc — the
      control the sheet came *out* of — becomes a checkmark for a second, and
      it is already a checkmark in the frames where the sheet is still sliding
      away. Under the thumb that just tapped, with nothing in front of it.
- [x] Whatever it is, **it delays nothing.** Nothing waits: the write and the
      dismissal are unchanged, and what was added draws on the screen
      underneath.

**History already had the visual half and nobody noticed.** Item 20's
`highlighted` marks the row a repeat *wrote*, for two seconds, and it marks it
whether the write happened on that screen or arrived from the sheet. It was
photographed here doing exactly that. So History gets the haptic and nothing
else; a second mark on the tapped disc would be two marks for one write. Home
is the screen that had no answer at all, and now has the same one History has.

- [ ] **Except when the tapped row is a long way down**, which is the one gap
      left and it is not new (found reviewing this item). The mark goes on the
      row the repeat *wrote*, dated now, so it lands at the top of today and
      nothing scrolls to it — repeat a row from last month with the list
      scrolled there and the only signal that arrives is the haptic. Not
      answered here: scrolling the list under the thumb that just tapped it
      moves what you were reading, and marking the tapped row as well is two
      marks for one write. Worth a decision, not a patch in a review round.

**Do not solve this by keeping the sheet open** so the user can see the card.
That trades a clear confirmation for a sheet that has to be dismissed by hand,
which costs a tap on the most repeated action in the app.

## 31. Light mode's accent is murky

The mint reads badly in light — too dark, not aesthetic.

**That is a consequence of how it was made.** Mint failed light-mode contrast
as a tint and as a form-button foreground (2.05:1 and 2.12:1), so item 18 built
a colour set by *darkening the same hue* until it passed. A dimmed pastel is
not a colour anyone would choose on purpose; it is a bright colour with its
brightness taken away.

**A colour set's two values do not have to be one hue at two brightnesses.**
They are two deliberate choices, one per appearance — that was the argument for
having a set at all, and it got applied as arithmetic instead of as a decision.

- [x] **Six candidates rendered and photographed**, light, iPhone 17 Pro, home
      and settings, by the same launch-argument probe item 27 used. Outside the
      repo in `~/dev/boring-tracker-pairing/` as `31-light-*.png`, with strips
      for the bar, the cards, the `Form` row, and black label against white.
      Every shot's fill was sampled back out of the PNG and matches the hex it
      was asked for. The numbers, the surfaces they were measured against and
      the recommendation were the last section of `docs/accent-options.md`,
      which is now in git history; the conclusion that outlived it is in
      [TECH.md](TECH.md).
- [ ] **The 3:1 constraint is not what is choosing here.** Every candidate
      clears it as a tint and as a form-row foreground, today's included, so it
      separates nothing. What separates them is the black `Log` on the fill:
      today measures 5.85 and a genuinely deep light accent lands near 3.9,
      which clears the 3:1 a UI element needs and misses the 4.5 that size of
      text wants. Light has a **window**, and today's colour sits inside it near
      the top — which is the murk this item reports, arriving as a ceiling
      rather than as a mistake.
- [ ] **So the real question is the label, and it was rendered too.** White on
      a deep light fill measures 5.3–5.5 — a shade under today's black on
      `#009888` at 5.85, and well over black on the deep fill itself at about
      3.9. So the trade is a slightly quieter label for a much deeper colour,
      not a free win; this item said "better than black on today's" and that
      was the wrong comparison. It would also make `Color.onAccent` a colour
      set and give the app one control whose word changes colour with the
      appearance — which that property's own doc argues against, from a time
      when the light fill was `#009888` and black worked.
- [x] **Rendered again, upward**, because that finding says the deep
      direction was chosen by the label rather than by the constraint the item
      names. Six more candidates on today's own hue line, lighter than
      `#009888` and past the point where the accent stops working, as
      `31b-*.png` beside the first set with today's colour as the control in
      every strip. **The window's ceiling is `#00A493`, at 3.02 as a nav-bar
      glyph** — twelve units of green above today, `L*` 60.7 against today's
      56.3. A mint that actually reads as lighter, `#00B3A0`, measures 2.56
      and fails. Numbers and surfaces were in `docs/accent-options.md`, now in
      git history; the window they describe is in [TECH.md](TECH.md).
- [x] **Rendered a third time, across the hue wheel**, because a ceiling on
      one hue line says nothing about the others. Ten candidates as
      `31c-*.png`, every one of them the most chromatic colour of its hue that
      still sits under the ceiling, so the set differs in hue and in nothing
      else: bar glyph 3.01–3.04, `Form` row 3.10–3.13, black label 6.70–6.77,
      `L*` 60.3–60.6. **Black on the fill is a function of the luminance
      alone**, so the label opens by the same 0.9 over today at every hue and
      hue buys none of it. What does change is apparent lightness — the blues
      read lightest and the mint and cyan-teal heaviest — but the gain is
      outside the family, the hue 15° from the mint reads no lighter than the
      mint, and on the nav glyph the lightest-reading candidates read the
      weakest. Numbers, the H-K model behind the ordering, and the same-app
      comparison against dark's `#00DAC3` were in `docs/accent-options.md`, now
      in git history; the finding is in [TECH.md](TECH.md).
- [x] **Rendered a fourth time, in both appearances**, because the user likes
      azure and that is a question about the app rather than about light mode:
      a dark azure was derived for each of the two candidates and photographed
      beside it as `31d-*.png` — home, settings and History, light and dark,
      with today's `#009888` / `#00DAC3` as the control in every strip.
      **No azure in sRGB is as colourful as dark's mint at any lightness**
      (`C*` 45.9 against 49.3), so a dark azure gives up a little light and a
      little colour at once: nav glyph 9.89 → 8.29, `Form` row 9.57 → 8.02,
      black label 11.82 → 9.90, every one of them still two to three times its
      floor. **The pairing holds**: `#009DD2` with `#04BFFF` reads as one app
      the way today's pair does, which retires "blue in light, mint in dark" —
      that was azure against *today's* dark, not against a dark azure.
      `#2693FF` is the one to drop; its dark half is pale at 6.55 on the glyph.
      Numbers, the gamut walk behind them and the pair strips were in
      `docs/accent-options.md`, now in git history; what the azure pair would
      cost is in [TECH.md](TECH.md).
- [ ] Dark mode is settled and measured. **Not touched** — until item 31d,
      which reopened it on purpose and left it unchanged.
- [ ] **The user picks, and nothing was merged.** Deeper, the recommendation
      is `#00796B` with a white label, or `#00857A` if the black label has to
      stay — and the second one is the compromise, because it is the same hue
      with less light in it again. Lighter, the recommendation is to keep
      `#009888`: the ceiling is four `L*` points away and nothing inside that
      gap is visible in the photographs, so a lighter mint costs contrast
      margin for a colour change the strips do not show. There is no third
      direction on this hue line; what is left is a different hue — and across
      the hue wheel the recommendation is `#009888` again, because at this
      luminance no hue that still belongs beside dark's mint reads lighter than
      the mint. If hue is to answer the murk anyway it is `#00A3A3`, which reads
      cleaner rather than lighter; `#009DD2` is lighter and crisp and makes the
      app blue in light and mint in dark, which reopens item 18.

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

- [ ] **A sixth shape is rendered and waiting on the user.** Asked for after
      the session started: Log again as the Log button but smaller — a rounded
      rectangle, wider than tall. The three constraints given cannot all hold
      at once, because the pill is a capsule and its corner radius *is* half
      its height, so a 50pt-tall shape carrying that radius is a capsule by
      construction. Rendered at three radii to show the trade and photographed
      beside pairing 1 in `~/dev/boring-tracker-pairing/`:
      `pairing-5a-rounded-square.png` (62x50, r18),
      `pairing-5b-pill-radius.png` (62x50, r25 — the pill's own, and therefore
      a capsule), `pairing-5c-wide-rounded-square.png` (70x50, r14), and
      `pairing-1-vs-5-strip.png` stacking all four bars.

      The session's answer was to keep pairing 1, on the grounds that a 50pt
      circle already *is* the pill's corner radius at width = height, so it is
      the same shape family rather than a different kind of object — and that
      widening it only moves it toward the peer the standing constraint rules
      out. The user has the photographs.

## 34. Does a settings row say it can be edited? — done

The chevron stays and the footer says the tap out loud, in the idiom item 22
already uses on two screens. Items 28 and 32 were checked as the alternative
answer first and are not one: both happen after a finger has landed. `18416ce`

## 35. Two rows, two reading orders — decided, done

A History row leads with **what you called it** and puts the numbers under it
— item 14b decided that, and the Log again sheet follows it. A tracker detail
row does the opposite: `520 kcal` large and white on top, `chicken salad` grey
underneath. The two screens are one tap apart and show the same two facts in
opposite orders.

**Both orders have a real argument and this pass is not going to pick.**
Item 14b's reason was that "reading order is what makes a list scannable, and
the numbers are not the part that tells two rows apart" — which is true on
History, where every row is a different food against a different tracker. On a
tracker's own screen the tracker is fixed, so the *number* is the thing that
tells two rows apart, and leading with the name would put the same weight on
the least distinguishing part of the row.

So it is either a genuine inconsistency to fix, or a case where the same rule
correctly produces two answers. The screens to compare are `HistoryRow` — a
private view in `HistoryView.swift`, not a method on `HistoryView` — and
`TrackerDetailView.row`.

- [x] Decide, with both screens open, whether detail should lead with the name.
      It should — see "35 (decided)" below, and PRODUCT.md for the rule and the
      argument that lost.
- [x] If it should not, say so in PRODUCT.md next to item 14b's rule, so the
      next pass does not find this again and file it a third time. It should,
      and PRODUCT.md says *that* instead, in the same place and for the same
      reason.

## 36. The entry editor confirms where the log sheet used to — closed, no change

Item 5 moved the log sheet's confirm **out of the navigation bar** and put it
directly above the keypad, because the keypad is up and the top-right corner of
a modern iPhone is not in the thumb's arc. The entry and batch editors have the
same shape — a number field, the keypad up — and still carry **Save** in the
navigation bar.

The counter-argument is the app's own: `PHILOSOPHY.md` says rare actions may
live high and "the nav bar is a fine home for things you touch once a week",
and fixing a mistyped entry is rarer than logging. It is also `Save` rather
than `Log`, deliberately, so it is not literally the same button.

Not changed here, because moving it is a taste call on a screen that is not on
the common path, and item 5's measurement was about the screen that is.

- [ ] Decide whether editing is close enough to logging to want the same
      confirm placement.

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

Same corner radius as the Log pill — not a circle, not a capsule — and slightly
wider than tall, so it reads as a rounded square at a smaller size.

The two controls should look like one family at two sizes. Today the disc reads
as a different kind of object beside a pill.

- [ ] Clearly smaller than the pill; a peer beside Log competes with the most
      frequent action in the app.
- [x] **Seven bars rendered and photographed**, dark, iPhone 17 Pro, by a
      throwaway launch-argument probe in a worktree — the same technique item
      27 used, with `-la-width`, `-la-height`, `-la-corner` and `-pill-corner`
      standing in for the shapes. Outside the repo in
      `~/dev/boring-tracker-pairing/`: `33b-a-today.png` through
      `33b-g-62x50-r25-capsule.png`, `33b-strip.png` stacking all seven bars,
      and `33b-corners-zoom.png`, which is the one that decides it — a, c and d
      at the 8pt gap between the two controls, where the pill's corner and the
      small one's can be compared side by side.

      | # | Log again | pill | what it shows |
      |---|---|---|---|
      | a | 50x50 circle | capsule | today |
      | b | 62x50, r22 | capsule | the largest radius that still leaves flat edges |
      | c | 62x50, r18 | capsule | a real rounded square beside an unchanged pill |
      | d | 62x50, r18 | **r18** | both controls at one literal radius |
      | e | 56x44, r14 | capsule | smaller in both dimensions |
      | f | 56x44, r10 | capsule | the same, squarer |
      | g | 62x50, r25 | capsule | the literal ask, and it renders as a capsule |

- [ ] **The three constraints cannot hold at once while the pill is a capsule,
      and d is the way out.** The Log pill is a `Capsule` at 50pt, so its corner
      radius *is* 25 — half its height — and a rounded rectangle is a capsule
      whenever its radius reaches half its shorter side. So "the pill's radius,
      not a capsule, wider than tall" needs a shape more than 50pt tall, which
      is the one thing ruled out. g is that fact photographed.

      What item 33 did not try is the other end: **give the pill a radius
      instead of a height-derived one.** d draws both at r18 and is the only
      bar here where the two controls share a literal corner radius, which is
      what "one family at two sizes" asks for.

- [ ] **The recommendation, and nothing has been landed.** c — the literal ask
      with the pill left alone — is worse than today, and `33b-corners-zoom.png`
      is why: it puts an r18 corner 8pt from an r25 one, so the pairing goes
      from two sizes of the same fully-round corner to two different corners.
      That is the complaint sharpened rather than answered. e and f give up the
      top-and-bottom alignment with the pill that item 27 was raised to get, and
      b and g are capsules by eye.

      That leaves a and d, and **it is a coin toss** — d is the more coherent
      drawing and a is the shipped one, and the difference is taste, not an
      argument. d also re-decides the shape of the most-used control in the app
      on the strength of a change to the second-most-used one, which is a bigger
      question than this item, so it goes to the user rather than being merged.

## 37. Three fixes before release — done

**The press grows.** One line in `AccentFillPress.scale(for:reduceMotion:)`,
which is the only place either a fill or a row works one out, so every accent
fill and every row turned together and a mix of the two directions is not
reachable. The travel stayed at 2pt and `9b21d82`'s guard kept its constant
with a milder reason: below `2 * travel` a press at least doubles the control
rather than turning it inside out. Judged by tapping fast, which is item 32's
rule — three 40ms taps recorded frame by frame, and in all three the frame
after the touch has the row's wash on and the disc already grown. `f97b671`

**A settings row says what tapping it would edit**, under the name, in the
caption slot `TrackerRowName` has had since item 28 — `Daily total · kcal`,
`Measurement · kg`. The chevron stays, and item 34's footer sentence goes: a
caption, a chevron and a paragraph is three explanations of one gesture. Under
the name rather than beside the chevron because a trailing value costs the
name the width it has least of; the rows are 52.0pt before and after.
`f2d657a`

**A two-line label no longer knocks the number off centre.** `StackingRow`'s
side-by-side branch is `.center` rather than `.firstTextBaseline`: home's
number sat 5.83pt above the row's own centre and now sits 0.17pt off it, which
is where a one-line row's number already was. All four screens took it
together — a History row's time is level with the repeat disc now — rather
than one screen taking a parameter. The cost is the baseline "Water" and
"0 ml" used to share. `a9487bc`

## 38. One rule for saying a row is tappable — decided

Item 37 put the explanation **on** the settings row — `Daily total · kcal`
under the name — and removed the footer sentence. History and tracker detail
still explain the same gesture in a footer, so the app has two idioms for one
thing.

Those rows genuinely cannot take the settings answer: no chevron, and their
trailing half is already a value.

**So the rule is: the row speaks when it can, and the footer is the fallback
when it cannot.** That is one rule with a stated exception rather than two
idioms competing, and it beats forcing every screen into a footer for the sake
of symmetry.

- [ ] Write the rule into `PRODUCT.md` beside the row descriptions, so the next
      screen does not have to guess.
- [ ] Leave History and tracker detail as they are — they are the exception,
      correctly applied.

Left open by item 37, and worth knowing: **a grown fill is drawn about 2pt past
its own tap target.** Harmless today — the press was tested at the pill's edge
and held — but it is the ceiling on ever increasing the travel, and it is the
opposite failure from the one shrinking had.

## 35 (decided). Tracker detail follows History — done

**Tracker detail leads with the name, like History does.** Consistency wins.

Item 35 laid out a real argument for the other order: on a tracker's own screen
the tracker is fixed, so the *number* is what tells two rows apart, and leading
with the name gives weight to the least distinguishing part. That is true, and
it loses anyway — two screens one tap apart showing the same two facts in
opposite orders reads as an app that has not decided, and a person moving
between them has to re-learn where to look.

- [x] `TrackerDetailView.row` matches `HistoryRow`: the name leads, the numbers
      follow, same weights and colours. Shared rather than matched by hand —
      `LogRowLabel` in `StackingRow.swift` is the two lines, and History, tracker
      detail and the Log again sheet all draw it. Three copies of one shape is
      how these came apart, and the sheet is in because it was the third copy,
      not because this item asked.

      Two visible things came with the flip. The detail row's value loses
      `.monospacedDigit()`, which is History's treatment: these lines are
      leading-aligned and of different lengths, so tabular figures were not
      lining a column up. And an entry with **no name** draws its value alone,
      on one line, rather than falling back to the tracker the way History does
      — that fallback exists because History mixes trackers, and here the
      navigation title has already said which one it is. So the number leads on
      exactly the rows that have nothing else to lead with.

- [x] Say so in `PRODUCT.md` beside item 14b's reading-order rule, with the
      argument that lost — so the next pass does not find this and file it a
      third time.

**Checked xSmall through AX5** on an iPhone 17 Pro simulator, twelve sizes, a
launch-argument probe root in a throwaway worktree so no clicking was needed to
reach the screen. Nothing clips and nothing splits mid-token: the row stacks at
`.xxxLarge` like every other list row (`DynamicTypeSize.stacksRows`) and reads
name / value / time down the left, and at AX5 a 48-character name wraps to three
lines with the value under it. The frames are `StackingRow`'s, which is why
there was nothing new to scale — this item moved two `Text`s inside a `VStack`.

Still different, and deliberately left: a detail row is taller than a History
row, because History sets `.listRowInsets(.listRow)` for the 44pt disc on its
end and detail has no such control. That is a density question, not a reading
order one — see "Small things".

## 36 (closed). The editors keep Save in the navigation bar

**No change.** Item 5 moved the *log sheet's* confirm above the keypad because
logging is the common path and the top-right corner is not in a thumb's arc.
Editing is rare, and `PHILOSOPHY.md` already says rare actions may live high.

The asymmetry is the rule working, not a gap in it.

- [ ] Close the item, and record the reasoning so it is not reopened.

## 39. A "last time" kind, where the date is the data — done

**A third `Tracker.Kind`, and the other two are untouched.** Tyres, the water
filter, the boiler service, the dentist — things whose age you want and whose
number does not exist. What it is and what it must never become are in
[PRODUCT.md](PRODUCT.md); why `Entry.value` stays non-optional is in
[TECH.md](TECH.md). `dad286f` model, `a04e447` UI.

Four decisions the brief did not make, recorded because nothing else states
them:

- **The reading is the whole card, and the date is not repeated underneath
  it.** The note that scheduled this said "142 days ago, with the date
  underneath". Left out: the reading *is* the date, so the caption would be
  the same fact twice — "today" over "Today" — on a card cut to one line on
  purpose (item 11). The exact date is one tap away on the detail screen.
- **Days, months and years; not weeks.** With weeks allowed the ladder reads
  `last week` at 7 days and `2 weeks ago` at 13, which is vaguer than the day
  count it replaces. `Elapsed` pins the whole ladder by test, because the
  strings come from the system rather than from this repo.
- **A one-tap log has no undo bar**, exactly like a log through the sheet. Undo
  on home belongs to a repeat, whose bar says "Logged again" and whose slot the
  store keeps one of; a second meaning in it would need a second wording, a
  second gate on home, and a second way for the repeat's invariants to go
  wrong. The entry is one tap away on the tracker's own screen, where a swipe
  deletes it — the same route every other mistyped log takes.
- **The row word is "Logged".** History and tracker detail draw an entry as a
  name over a value, and the value line cannot be blank without leaving a row
  that is a time and nothing else. It is one word, it is true, and it comes
  from `Tracker.entryText` so no screen invents its own.

## 40. A press you cannot see coming — done

Anton, on a real device: pressing and holding *Add Tracker* in settings, the
pressed highlight arrives late, and he suspected it was general rather than that
one row. It is general, and it is the list.

**Method.** `xcrun simctl io booted recordVideo --codec h264` on an iPhone 17 Pro
simulator, iOS 26.3, dark, debug build; frames decoded with `AVAssetReader` and
`kCVPixelFormatType_32BGRA`, and one rect's mean luminance printed per frame. The
recorder emits only when the screen changes, so on a still screen the emitted
frames *are* the change timeline; inside a press they average 16.0ms apart —
mean of the 61 steps in one recording, ragged between 6.6 and 26.7 — which is a
60fps grid with the encoder's jitter on it. Every number below therefore has a
resolution of one frame, about ±17ms.

**Touch-down needs an anchor, and that is the part that makes the numbers mean
anything.** Nothing on screen changes when a finger lands — that is the thing
being measured — so a throwaway build carried a `UIGestureRecognizer` on the
app's `UIWindow` that recognises nothing and paints a strip of the left margin
white from `touchesBegan`. A recogniser on the window is handed the touch
immediately whatever the scroll view does with it, and the strip draws on the
next frame, which is the same frame budget the control has. Both ends of every
number are therefore "first frame after the state was set": the difference is
app-side only, and whatever the simulator's own injection costs cancels out. The
press itself is a `CGEvent` mouse down held 800ms, three runs each.

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
back while it decides whether the finger is scrolling — the brief's hypothesis,
and the number is that delay.

So it is not that row, it is every row on every screen. And the Log pill's zero
is not item 37's doing: item 37 changed what a press draws once it arrives, and
what makes the pill's press *arrive* at once is that it is not in a list.

**iOS's own settings list has the same delay**, and this is deliberately the
weaker measurement of the set: Preferences carries no marker, so touch-down
cannot be anchored inside it. Driven by the identical script, the *Camera* row's
highlight first appears 1990ms and 2005ms into two recordings, while the 53
marker-anchored recordings taken here put touch-down between 1786.7ms and
1846.7ms. Same delay, on an assumption rather than on an anchor.

**The fix is one line**, in `BoringTrackerApp.init`:
`UIScrollView.appearance().delaysContentTouches = false`.

**After — same method, three runs each: all six controls 0.0ms.** The pressed
state lands on the frame the touch does, for *Add Tracker*, the settings row,
the History row and both probe buttons, and the Log pill has not moved.

**What it costs, measured rather than assumed:**

- **A flick that starts on a row flashes that row.** A 30pt flick off the
  *Calories* row: with the delay on the row never washes at all; with it off the
  wash is on at the touch frame and gone from the sampled band 90ms later.
  **That 90ms is not `AccentFillPress.minimumHold` expiring, which is what this
  first said.** `RowPressState.set` cannot tell a cancellation from a release,
  so it holds the press for the rest of the floor — 100ms — and then fades it
  out over `AccentFillPress.release`, 0.12s asked for and 82ms recorded as
  visible. Nothing in that path can end a wash in 90ms. Likeliest is that the
  row scrolled out of the fixed band being sampled while it was still washed;
  that is reasoning, not a measurement, and a re-measure has to follow the row
  rather than a rect. The direction is not in doubt either way: every flick that
  starts on a row now washes it for at least the floor, where that used to be a
  narrow case.
- **And the same flick fires the press haptic**, because `pressHaptic` triggers
  on the same boolean the wash does. That cannot be measured here — a simulator
  logs "Haptics: unsupported" — so it is recorded as a consequence rather than
  as a number, and item 17's device pass now has it as its first question.
  Deleting the press haptic is the fix already on that table.
- **Scrolling itself is unchanged.** Same synthesized 120pt drag starting on a
  row, displacement read from the accent's y in a screenshot two seconds after
  release, six runs per side — three flicked straight away and three after
  resting 250ms first. With the delay on, 306–319pt; with it off, 298–316pt.
  Same spread either way and the ranges overlap.
- **Reorder, swipe-to-delete and the log path are unaffected.** The same
  synthesized handle drag moved the *Food* group below *Weight* identically
  either way; a swipe on a History row reveals the red delete action either way;
  the log sheet opens, the keypad types and *Log* writes the entry.
- **Unchecked, and reasoning rather than measurement: a flick that starts on the
  reorder handle.** Settings' handle carries a `DragGesture(minimumDistance: 4)`
  as a `highPriorityGesture`, and it is fed by the delivery this one line
  changed — it used to see nothing until the scroll view had had its ~150ms to
  claim the touch, and now it sees the touch on the first frame and can win at
  4pt. The drag measured above is the deliberate one, a finger that rests and
  then moves, which behaves the same either way. The case nobody has run is a
  fast vertical flick that begins on the 44pt handle, and `reorderGesture`'s
  `onEnded` commits from wherever the finger lets go — so if the drag wins that
  race, a scroll rewrites the stored order. Check it before the device pass: it
  needs a synthesized flick, not a thumb. If it reproduces, the cheap answer is
  a larger `minimumDistance`, since a reorder always starts from a finger that
  has already stopped.

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

**Measured 2026-08-20** on an iPhone 17 and a 375pt SE simulator, in a
throwaway worktree, because the reason had never been measured: `project.yml`
and SHIPPING.md both said home screen labels "truncate around 12 characters",
and iOS truncates on rendered *width*, not on characters.

**`Boring Tracker` fits in full on both devices, with no ellipsis.** On the SE
it fits by being condensed about 20% — 74.5pt against 89pt for the two words
measured separately — which is iOS tightening a string before it will
ellipsise it. So the 12-character rule is not the rule, and the tradeoff the
short label was chosen to avoid does not exist in the form it was written down.

The cost of the short label, on the other hand, is real, and it is Spotlight:

| Label | home screen | Spotlight `tracker` | Spotlight `boring` |
|---|---|---|---|
| `Boring` (shipping) | fits, 35.3pt | **not found** | Top Hit |
| `Boring Tracker` | fits, both devices | Top Hit | Top Hit |
| `Tracker` | fits, 42.3pt | Top Hit | **not found** |

Spotlight was exercised on the iPhone 17 only, twice, with a clean uninstall
and a 25s settle, and with `boring` run as the control in the same minute — so
the negative for `tracker` is a real negative and not an index that had not
finished building. Widths came from a white-pixel extent scan of the label row,
against ~86pt of available width read off a label that was genuinely truncated
on the same screen.

One thing that looks exactly like truncation and is not: **before the app has
been opened once**, the new-app dot takes label width, and the label renders as
`BoringTracker` with the space collapsed (iPhone 17) or `Boring T…` (SE). It
goes away on first launch. A screenshot of a fresh install shows the squeeze; a
user after their first tap does not.

- [x] **Changed to `Boring Tracker`**, in `82cf49c`. The evidence above is the
      whole argument: the full name is free on both devices, and the short one
      cost every search for the word the app is named after. `project.yml`'s
      comment and SHIPPING.md's bullet no longer cite 12 characters, and
      APPSTORE.md no longer says the label is `Boring`.

      Re-checked *after* the change rather than only before it. Both home
      screens render `Boring Tracker` with no ellipsis once the app has been
      opened once, and Spotlight on an iPhone 17 returns it as Top Hit for
      `tracker` and for `boring`. One wrinkle worth knowing for the next
      Spotlight check on this machine: a stale `boringtracker.uitests.xctrunner`
      build was installed on the iPhone 17 from some earlier session, it matches
      both queries itself, and it sat in the results beside the app until it was
      uninstalled. The screenshots behind this paragraph were taken with it
      gone.

## 42. The card `+` as an outlined ring — decided, done

**The ring ships, and the filled disc stays behind `CardPlus.outlined`.**
Anton picked the ring on 2026-08-20 and that choice is settled. `9f46446` went
further and deleted the loser, which is not what he asked for — *"dont delete
for now, i dont care, we can do later"* — and `d1c1d38` put it back. The
constant is `true`, so the ring is what draws; `false` is still the disc, one
branch of `TrackerCard.plusMark`.

**Deleting the disc waits on the device pass, item 17.** The ring has only ever
been seen in simulator screenshots, so the decision is not yet confirmed by
anyone holding a phone; while that is true, going back is one line rather than
unpicking a commit. Once the ring survives real use, what goes is that branch,
the mark it names, `plusMark` itself — a chooser between one thing is not a
chooser — and the `CardPlus` enum, leaving `logButton` naming `CardPlusRing()`
directly. Carrying both is right while the comparison can still be lost and is
dead weight the moment it cannot: [PHILOSOPHY.md](PHILOSOPHY.md)'s test for
code is performance and simplicity, and the smallest thing that works.

**What the disc knew, kept here because its comment goes when it does.** It
started as a bare blue glyph, which was a different design language from the
bottom Log button it is a smaller version of, and low enough contrast that it
did not read as a control at all. A tinted `.bordered` fill was tried next, on the grounds that
eight solid dots down one screen is loud — and rejected on the original
complaint, because a blue glyph on a pale blue disc is that same low contrast
again. The accent-filled disc is what came out of that. The ring was built to
match the new icon rather than to answer any of this, but it is the first mark
on this button that is not a solid dot.

**Two of the five screenshots had to be reshot** — `1361702`. The set was
captured at 15:04 and the ring landed at 19:08, so `home.png` was showing eight
filled mint discs the app no longer draws, and it is the first image both on the
App Store listing and in the README; `again.png` carries five more beside the
Log again sheet, plus a sixth blurred through its top edge that the dimmed
background makes easy to miss. The other three show no card `+` at all:
`log.png` is the sheet over the whole screen, `history.png`'s discs are the row
Repeat control, and `graph.png`'s toolbar `+` is a bare nav-bar glyph. Both were
re-shot from the original seeded `store.json`, still in the simulator's
container and byte-identical after the app read it — so the fixture the earlier
review settled did not move. Measured against the old files: the new `home.png`
differs in exactly eight 80x80 regions, at the eight marks and nowhere else.

The rest of this item is how the ring was built and measured, and it stands.

The app icon is a mint `+` inside a mint ring on `#1C1C1E`. This built the
card's `+` the same way — a 2pt `AccentFill` ring at the disc's own 30pt
diameter, with the plus at the icon's proportions. Filling the ring on press is
the inverse of `AccentFillPressed`, which washes a fill and does nothing to a
stroke. Photographed both ways in both appearances; the images are outside the
repo.

**The ratios are the shipped icon's**, sampled out of
`boring-tracker-1024.png`'s own IDAT bytes rather than through a colour-managed
reader:

| what | px at 1024 | ÷ ring outer Ø | at 30pt |
|---|---|---|---|
| ring outer Ø | 702 | 1.0 | 30 |
| ring stroke | 48 | 0.0684 | 2.05 → **2** |
| plus overall width | 330 | 0.470 | 14.10 |
| plus arm thickness | 50 | 0.0712 | 2.14 |

The field is a flat `#1C1C1E` and the mint a flat `#00DAC3` — single values,
no gradient. The mint read `#00E8D8` when these ratios were sampled; the
geometry they describe did not change with the recolour. The arms (50) and
the stroke (48) are within 4% of each other, and **reading as one weight is
the property being copied**.

**The icon's mint was not the app's** when this was built. The ring is drawn in
`Color.accentFill` — `#00DAC3` dark, `#009888` light — and the icon was
`#00E8D8`; what was matched here is the geometry alone. The icon has since been
recoloured to `#00DAC3`, so in dark the two are now one value. In light they
still differ: the app's ring goes `#009888` and the icon, being one file, does
not follow the appearance.

**The glyph is `.font(.system(size: 17, weight: .semibold))`.** The disc's
`size: 15, weight: .bold` was chosen against a fill, not against these ratios,
so nine weights and then a ladder of sizes were rendered in the simulator and
counted at 3× — no metric was read off a documentation page. Weight first,
because the arm-to-width ratio belongs to the weight alone: `.semibold` renders
**0.1528** against the icon's 0.1516, `.bold` 0.1769, `.medium` 0.1340. Then
size, linearly: at 17pt the plus measures **14.00pt wide with 2.15pt arms**
against the 14.10 / 2.14 wanted. For comparison the disc's `15:.bold` measured
12.54pt wide with 2.22pt arms.

**The press fills the ring** with `.accentFill` — the full accent, not
`AccentFillPressed`, which is a fill that recedes toward its surface and does
nothing visible to a 2pt stroke. The glyph flips to `Color.onAccent` with it,
because a mint plus on a mint fill is not there. Both arrive instantly and
scaled up, through the existing `\.accentFillPressed` and
`AccentFillPress.scale(for:)`; nothing new was added for the press and nothing
animates on the way in. So **a pressed ring is what the resting disc was** —
the honest inverse, not a coincidence to design around. Held down, the mark
measures 34.00pt across against 30.00 at rest, which is
`AccentFillPress.scale(for:)` on a 30pt fill exactly, and one screenshot carries
both the fill and the scale, so they are on the same frame.

The disabled state is carried too: `accentFillDisabled` for the stroke *and* the
plus. Nothing disables this button today, so that path is unexercised.

**Measured on the shipped build**, from screenshots of one fixture:

| | outer Ø | stroke | plus width | arms |
|---|---|---|---|---|
| dark, default size | 30.00pt | 2.00pt | 14.00pt | 2.146pt |
| light, default size | 30.00 | 2.00 | 14.00 | 2.146 |
| dark, AX3 | 30.00 | 2.00 | 14.00 | 2.146 |

**At AX3 the stroke does not thin — nothing about the mark moves.** Both marks
are fixed by design (`.system(size:)` and a 30pt frame), so what changes is
everything around them: the card goes from 52.0pt tall to 105.7
(140.3 on the one carrying a caption) and the ring is still 30pt of 2.00pt
stroke. It is quieter there in the sense that it is a smaller share of a much
bigger row, and a stroke shows that more than a fill does.

**Light mode measures 3.59:1** — `#009888` sampled off the rendered ring
against a card sampled as a true `#FFFFFF` — so it clears 3:1. Dark measures
9.57:1. This is reported and not decisive; Anton is judging in dark.

**The tap target is unchanged, checked twice.** The `.frame(width: 44,
height: 44)` and `.contentShape(.rect)` moved out of the disc's chain and sit
outside whichever mark is drawn, unchanged and still the last two modifiers
before `.buttonStyle` — nothing inside the 30pt footprint reaches them. And the
accessibility tree, read from the simulator for both builds against the same
fixture, returns identical rects for all six card buttons: `Log Calories` at
`1196,301 44×44` in each, and so on down the screen.

## 43. A rate link on About, now that there is an id — done

About deliberately shipped without one — `017267c` — because the URL needs the
numeric App Store id and there was no app. **There is now: `6803768789`**, and
it turned up with the *app record* on 2026-08-20 rather than with the release,
which is earlier than SHIPPING.md assumed when it filed this under "after the
first release".

```
https://apps.apple.com/app/id6803768789?action=write-review
```

**Decided: a link, not a prompt.** `SKStoreReviewController` / SwiftUI's
`requestReview` puts a rating dialog in front of somebody who did not ask for
one, which is the same category as streaks, badges and notifications — the
things rule 4 of PHILOSOPHY.md refuses. A row on About that says so and does
nothing until it is tapped is the opposite: inert until somebody goes looking
for it. That distinction is the whole item; if it ever turns into a prompt it
should be closed instead.

**Why have one at all**, given the app asks for nothing else. App Store ranking
is heavily rating-weighted, and an app with no ratings ranks badly however good
it is. This app has no marketing budget, no ads and no launch — the listing is
the entire distribution strategy. A passive link is the cheapest honest lever on
that, and it costs one row.

**Built as a `Link` row above *Support*.** `c54da7e`. Beside the Support
message rather than as a fourth button inside it: that message opens by talking
the reader out of giving money, and a review link reached only through it is two
taps behind a deflection.

**The id is right and the URL is not reachable yet — those are different
things.** The App Store Connect API returns 200 for `apps/6803768789` with name
*Boring Tracker* and bundle id `com.novoselov.boringtracker`, so the link points
at this app. The public page 404s, and `itunes.apple.com/lookup` returns
`resultCount: 0`, because the only version record is 1.0 in state
`WAITING_FOR_REVIEW` — there is no listing to serve until it goes on sale, which
happens before any **App Store** copy of this row exists. It does not cover
TestFlight or a build side-loaded onto a phone: either can carry this row while
the listing is still private, and tapping it then reaches a page for an app the
store will not admit to having. That window is testers only, and it closes on
release.

**Still unverified: that the row lands on the store page.** The simulator has no
App Store app, so the handoff fails there — Safari refuses the URL as
invalid, and it refuses a *live* app's `?action=write-review` link the same way,
which is what says the failure is the simulator and not the URL. Confirming it
needs hardware or the live listing. [Item 17](#17-one-pass-on-a-real-device) is
the device pass; check it there, or the first time the listing is public.

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

- [ ] **What the reorder footer should say when there is only one section.**
      `canReorder` (`activeTrackers.count > 1`) gates both the drag handle and
      the footer under it, and the handle's threshold is exactly right. The
      footer's middle sentence is not: "Between sections, its whole group moves
      with it" describes a drop that needs two *runs*, and two trackers sharing
      one group are one run — so a two-tracker list is told about sections it
      does not have, which is the smaller version of the complaint 22bc672 was
      fixing.

      Not fixed, deliberately, and the obvious fix is wrong: gating the whole
      footer on `runs.count > 1` would draw a handle with nothing explaining it,
      which is worse than one sentence too many. The honest fix splits the
      string, and a conditional sentence is a concept this screen does not have
      for a case no fixture reaches. Raised reviewing pass 2 and left; whoever
      picks it up should decide whether the sentence is worth a branch at all
      before writing one.

- [ ] **What the gap between two halves of a stacked row should be.**
      `StackingRow`'s stacked branch uses `spacing: 2`, which was measured for
      home's card, whose stacked form is two lines. The three list rows put a
      two-line `VStack` in the leading half, so at `.xxxLarge` and above a
      History row is three lines at three equal 2pt gaps — the boundary between
      *what it was* and *when it happened* reads exactly like the boundary
      inside the identity block.

      Not fixed: it is spacing, the rows read fine (photographed at all twelve
      content sizes), and any number here is a taste call — and a second number
      means either a parameter on `StackingRow` or the card and the lists
      disagreeing again, which is the thing that file exists to stop. Worth
      writing down because the *reason* it looks even is that one number is now
      answering for two different row shapes.

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

- [x] **A tracker detail row is taller than the History row it now matches.**
      It was 74pt against History's 52, read off the accessibility tree on the
      same five entries; both are 52 now. **Decided, not just fixed:** detail
      takes `.listRow` whole, including the trailing 12 that was sized for a
      repeat disc it does not have, because a private set of insets for the one
      screen without a trailing control is exactly the drift this note was
      about. It costs 4pt of air to the right of the time. `f2ce523`

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
