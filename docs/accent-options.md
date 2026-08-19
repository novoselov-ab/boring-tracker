# Accent options, measured

> **This page is evidence, and its recommendation was not taken. Read it as
> history.** It was written while the accent was `Color.teal`, and every
> "today" and "ships" below means *then*. What shipped instead: item 13f moved
> the accent to the system mint, and item 18 made it a colour set — `AccentFill`,
> `#009888` light and `#00DAC3` dark — which is what the app draws now. So the
> line under Method saying nothing in `BoringTracker/` changed is still true of
> *this* work and no longer true of the app, `Color.accentFill` is a colour set
> rather than a system colour, and the Recommendation's "Blue was right" is a
> road not taken rather than a plan. The measurements themselves stand — all
> fifty-odd contrast ratios on this page were recomputed from the hex values in
> August 2026 and every one reproduces to the second decimal — and they are why
> item 18 exists: this table is what proved one hue could not serve both
> appearances. Item 31 was the open half — the same exercise for light mode,
> never rendered here — and it is now the last section on this page, written
> from its own renders rather than from this one's.

> The screenshots behind these numbers are **kept outside the repository**,
> in `~/dev/boring-tracker-accent/`. They are 1.2 MB of PNGs that would sit in
> history forever to illustrate a decision this document already states in
> words. The measurements are here; the pictures are on the machine that took
> them.

Evidence for a choice, not the choice. **Nothing in `BoringTracker/` changed by
this work** — at the time it was written the app shipped
`Color.accentFill = Color.teal`; it is now the `AccentFill` colour set, changed
by items 13f and 18 rather than here. Every screen below was rendered by a
throwaway probe build and thrown away with it.

The teal was picked from a trend article, and it has not survived contact: white
on it measures 1.86:1, as a nav-bar tint in light mode 2.13:1, and the user does
not like it. Picking the next one the same way would repeat the mistake, so
these were rendered and sampled instead.

**Dark mode is what is being judged** — it is the mode this app is used in.
Light-mode numbers are in an appendix because item 18 gives light its own value
in a colour set, so nothing here constrains it.

---

## The short version

In dark mode there is exactly one discriminating number, and it is not the one
this was expected to turn on.

- **As a nav-bar tint, every candidate clears the 3:1 floor in dark.** The worst
  is violet at 3.09; eight of the other eleven beat the system blue control's 5.44.
  Dark mode is a permissive room for a bar glyph, and that measurement does not
  separate the field.
- **What separates the field is whether a white label survives on the fill.**
  Seven of the twelve fail it, teal at 1.86 among them. The blues, indigo and
  violet pass.
- Teal fails the white label so badly that item 13b had to move the label to
  black. **That whole mechanism exists because of the colour**, not because of
  iOS: `Color.onAccent`, `onAccentFill()`, the disabled-button carve-out, and
  the paragraph explaining why the label does not flip with the appearance.
- `Color.teal` and `Color(.systemTeal)` are **the same fill**, `#00D2E0`. That
  question does not settle anything.

**Blue was right.** Details and the pick under [Recommendation](#recommendation).

---

## Method

Stated so the numbers can be re-taken or disbelieved.

**The build.** A `git worktree` at `930a013`, with three probe edits that never
touch the real tree: `Color.accentFill` reads `-accent <name>` from
`ProcessInfo.arguments`, `HomeView` opens the log sheet or pushes settings from
`-probe-log` / `-probe-settings`, and the log sheet types a number into its
first field so the Log button is *enabled* — a disabled prominent button is
drawn from a neutral fill and never touches the tint, which is what the sheet
looks like at rest.

**The device.** iPhone 17 Pro, iOS 26.3, dark appearance, status bar frozen at
9:41, seeded with the same five-tracker store file for every shot. Not the
iPhone 17: another session spent the afternoon running `xcodebuild test` against
that device, and every test run reinstalls the real app over the probe.

**The discriminator.** The probe writes the argv it actually received to
`Documents/probe-args.txt`, and the file is deleted before every launch. A shot
is only kept when that file comes back naming the candidate it was asked for, so
a stale install or a launch that never reached the foreground is a hard failure
rather than a plausible screenshot. All 63 captures behind this document passed
it. It is also what caught the wrong device: the first captures came back teal
when orange had been asked for, twice, before the other session's test runs were
found.

**The sampling.** `xcrun simctl io <device> screenshot` writes an sRGB-tagged
PNG — black reads exactly `#000000` and white exactly `#FFFFFF`, checked. A
small AppKit tool takes the *most common exact colour* in a rect rather than a
per-channel median, which would invent a colour that is not on screen. For a
glyph, it takes the most common colour among the pixels far from the rect's
background, so anti-aliasing does not drag the reading toward the bar.

**What each number is.**

| Number | Sampled from |
|---|---|
| Fill | the Log pill on the home screen, 918×52px inside it |
| White label | that fill against `#FFFFFF` |
| Near-black label | that fill against `#1C1C1E` |
| Black label | that fill against `#000000` — what the app ships today |
| Nav-bar tint | the gear glyph against the bar button's own background |

Contrast is the WCAG 2.x ratio. **3:1 is the floor for a UI element**; anything
under it is bolded in the tables.

**The nav-bar denominator is `#191919`, not black.** In iOS 26 a bar button sits
in its own circle, and that circle — not the page behind it — is what the glyph
is drawn on. Measured on every shot: `#191919` in dark, `#FBFBFF` in light.

**On "near-black is the standard dark background".** Not here, and this is worth
saying plainly because it affects every number above. The app's list background
*is* pure `#000000` — that is `systemGroupedBackground` in dark, Apple's value,
not a choice this app made. But the accent never touches it: the fill sits in a
`.bar` inset, the cards and the sheet are `#1C1C1E`, and the bar glyph is on
`#191919`. So the honest denominators are the near-blacks, and they are what the
table uses. The one place pure black appears is the *label*: `Color.onAccent` is
`.black`, so the "black label" column is what ships and the "near-black label"
column is what a softened label would measure. The difference is about 1.2× and
changes no verdict.

---

## The numbers, dark

| Candidate | Fill | Sat | White label | Near-black label | Black label | Nav-bar tint |
|---|---|---|---|---|---|---|
| **blue** `Color(.systemBlue)` — control | `#0091FF` | 1.00 | 3.23 | 5.26 | 6.49 | 5.44 |
| blue `Color.blue` | `#0091FF` | 1.00 | 3.23 | 5.26 | 6.49 | 6.16 |
| **teal** `Color.teal` — today | `#00D2E0` | 1.00 | **1.86** | 9.15 | 11.30 | 10.71 |
| teal `Color(.systemTeal)` | `#00D2E0` | 1.00 | **1.86** | 9.15 | 11.30 | 9.46 |
| mint | `#00DAC3` | 1.00 | **1.78** | 9.57 | 11.82 | 9.89 |
| cyan | `#3CD3FE` | 0.76 | **1.76** | 9.67 | 11.94 | 10.00 |
| indigo | `#6D7CFF` | 0.57 | 3.51 | 4.84 | 5.98 | 5.00 |
| green | `#30D158` | 0.77 | **2.02** | 8.42 | 10.39 | 8.70 |
| orange | `#FF9230` | 0.81 | **2.23** | 7.62 | 9.41 | 7.88 |
| `#3B82F6` blue | `#3B82F6` | 0.76 | 3.68 | 4.63 | 5.71 | 4.78 |
| `#10B981` emerald | `#10B981` | 0.91 | **2.54** | 6.71 | 8.28 | 6.93 |
| `#7C3AED` violet | `#7C3AED` | 0.76 | 5.70 | **2.99** | 3.69 | 3.09 |

Unlabelled rows are the UIKit values (`Color(.systemMint)` and so on) — see
[teal against systemTeal](#teal-against-systemteal) for why that matters and
how little.

**Brown**, the other warm outlier the brief allowed, was measured on the home
screen only: `#B78A66`, white **3.07**, near-black 5.54, nav bar 5.73. It scrapes
over the white-label floor with the thinnest margin in the set, and orange was
carried through the full three screens instead because it is the warm colour
anyone would actually reach for.

**The control is 5.44.** That is system blue as a nav-bar glyph in dark, the
number Apple ships and tuned the bar for. It is not a hard floor — 3:1 is — but
it is the honest reference, and everything except indigo, `#3B82F6` and violet
beats it.

### What the two columns are fighting over

Lightness. A colour light enough to glow as a thin glyph on a near-black bar is
too light to sit behind a white label, and the two columns are almost perfect
mirrors: teal wins the bar (10.71) and loses the label (1.86); violet wins the
label (5.70) and comes last on the bar (3.09). No candidate maximises both, and
none has to — both floors are 3:1, and the question is only which colours clear
both. Four fills do: system blue `#0091FF`, `#3B82F6`, indigo `#6D7CFF`, and
violet `#7C3AED` — the last only against a pure-black label, not a near-black
one. Brown makes it a fifth by 0.07.

---

## Each candidate

Home, log sheet, settings — every one dark, same fixture, same build.

**One thing to read past in these images.** They all draw the label on the Log
button *black*, because that is what the app does today (`Color.onAccent`). On a
blue that is a legal but odd-looking choice; see
[the white label](#the-label-the-app-could-stop-forcing) for what those three
actually look like with iOS's own white label back.

Settings is drawn with the candidate applied to its `Form` action rows —
`Add Tracker` here — which is item 13e's "chrome" option, not the shipping
build, where those rows are the ordinary label colour and read as static text.
It is the only way this screen shows the accent at all.

### blue — `Color(.systemBlue)`, the control

*(screenshot: `blue-system.png`)*

`#0091FF` · white 3.23 · near-black 5.26 · nav bar 5.44 — the only family that
clears 3:1 with *either* label, so the app could stop forcing a label colour at all.

### blue — `Color.blue`

*(screenshot: `blue-swiftui.png`)*

`#0091FF` · white 3.23 · near-black 5.26 · nav bar 6.16 — the same fill as the
UIKit one; only the bar glyph differs, and in this direction it is brighter.

### teal — `Color.teal`, what ships today

*(screenshot: `teal-swiftui.png`)*

`#00D2E0` · white **1.86** · near-black 9.15 · nav bar 10.71 — the best bar
glyph in the set and the second-worst label; the black label is not a preference,
it is the only thing that makes this colour legal.

### teal — `Color(.systemTeal)`

*(screenshot: `teal-system.png`)*

`#00D2E0` · white **1.86** · near-black 9.15 · nav bar 9.46 — identical fill to
`Color.teal`, so switching to the UIKit value fixes nothing.

### mint

*(screenshot: `mint.png`)*

`#00DAC3` · white **1.78** · near-black 9.57 · nav bar 9.89 — teal's problem
with a green cast; it was the runner-up when teal was chosen and measures the same.

### cyan

*(screenshot: `cyan.png`)*

`#3CD3FE` · white **1.76** · near-black 9.67 · nav bar 10.00 — the worst white
label in the set, and close enough to teal to be the same decision again.

### indigo

*(screenshot: `indigo.png`)*

`#6D7CFF` · white 3.51 · near-black 4.84 · nav bar 5.00 — clears every floor
with either label, and the one system colour Apple genuinely desaturates for
dark (0.65 → 0.57).

### green

*(screenshot: `green.png`)*

`#30D158` · white **2.02** · near-black 8.42 · nav bar 8.70 — reads as a status
colour before it reads as a brand, and fails the white label like the rest of
the light hues.

### orange

*(screenshot: `orange.png`)*

`#FF9230` · white **2.23** · near-black 7.62 · nav bar 7.88 — the warm outlier,
and it behaves exactly like the cool light ones: strong glyph, illegal white label.

### `#3B82F6` — the common dark-mode blue

*(screenshot: `blue-3b82f6.png`)*

`#3B82F6` · white 3.68 · near-black 4.63 · nav bar 4.78 — the best white-label
margin of anything that also clears the bar, and 24% less saturated than system blue.

### `#10B981` — emerald

*(screenshot: `emerald-10b981.png`)*

`#10B981` · white **2.54** · near-black 6.71 · nav bar 6.93 — the closest miss
among the light hues, and still a fail; it is green's problem slightly softened.

### `#7C3AED` — violet

*(screenshot: `violet-7c3aed.png`)*

`#7C3AED` · white 5.70 · near-black **2.99** · nav bar 3.09 — the only candidate
that *wants* a white label, bought with the weakest bar glyph in the set and a
near-black label that fails.

---

## The label the app could stop forcing

Teal, system blue, `#3B82F6`, indigo — same build, same screen, with
`Color.onAccent` set to white instead of black:

*(screenshot: `white-label.png`)*

This is the 1.86:1 the app worked around, next to the three colours that do not
need the workaround. If the accent moves to a blue, `Color.onAccent`,
`onAccentFill()` and the disabled-button carve-out inside it all stop earning
their keep — the button goes back to being a plain `.borderedProminent` with
whatever label iOS draws.

---

## Two things the numbers corrected

### Teal against systemTeal

They are the same fill. `Color.teal` and `Color(.systemTeal)` both render
`#00D2E0` in dark and `#00C3D0` in light, to the byte, and every other pair
matches too — mint, cyan, indigo, green, orange and brown.

The two differ in exactly one place, and only in one direction:

| Hue | SwiftUI glyph | UIKit glyph | SwiftUI bar | UIKit bar |
|---|---|---|---|---|
| teal | `#0DDFED` | `#00D2E0` | 10.71 | 9.46 |
| mint | `#0DE7D0` | `#00DAC3` | 11.18 | 9.89 |
| cyan | `#48E0FF` | `#3CD3FE` | 11.20 | 10.00 |
| indigo | `#7A89FF` | `#6D7CFF` | 5.73 | 5.00 |
| green | `#3CDE64` | `#30D158` | 9.90 | 8.70 |
| orange | `#FF9F3C` | `#FF9230` | 8.60 | 7.88 |
| brown | `#C49772` | `#B78A66` | 6.71 | 5.73 |

A nav-bar glyph tinted with a **SwiftUI** system colour comes out exactly
`+13/255` on every channel — a flat additive lighten, not an alpha blend, and
the same 13 for all seven hues. The UIKit colour renders the fill value
unchanged. The mechanism was not chased; the fact is reproducible and it moves
no verdict, since both sides clear 3:1 everywhere they clear it at all.

Two earlier sessions recorded teal as `#00CDD9`/`#00D9E6`. This session
reproduces the later `#00C3D0`/`#00D2E0` pair exactly, on a different device,
which is now three independent measurements against two. Treat the older ones as
wrong.

### "Desaturate 20–30% for dark mode"

That is the common advice, and the claim that Apple already does it in the dark
variants of its system colours is **not what the pixels say.**

| Hue | Light | Sat | Dark | Sat |
|---|---|---|---|---|
| blue | `#0088FF` | 1.00 | `#0091FF` | 1.00 |
| teal | `#00C3D0` | 1.00 | `#00D2E0` | 1.00 |
| mint | `#00C8B3` | 1.00 | `#00DAC3` | 1.00 |
| cyan | `#00C0E8` | 1.00 | `#3CD3FE` | 0.76 |
| green | `#34C759` | 0.74 | `#30D158` | 0.77 |
| orange | `#FF8D28` | 0.84 | `#FF9230` | 0.81 |
| indigo | `#6155F5` | 0.65 | `#6D7CFF` | 0.57 |

Apple's dark variants are mostly the *same saturation, higher brightness* —
blue, teal and mint are fully saturated in both appearances, and green goes up.
Only cyan and indigo desaturate. So "use the UIKit values because Apple already
desaturated them" is not an argument that survives measurement.

The advice may still be good design advice, and it points somewhere useful: the
current teal is `S = 1.00, V = 0.88`, which is exactly the fully-saturated,
bright colour the guidance warns about, and `#3B82F6` at `S = 0.76` is the
candidate here that most nearly follows it. But that is a taste argument with a
number attached, not a contrast result, and it is worth keeping the two apart.

---

## Appendix: light mode

Not part of this choice — item 18 gives light its own value in the colour set,
so a colour that fails here is not disqualified. It is here because it is the
number that started item 18, and because one candidate family passes both
appearances on a single value, which is worth knowing before hand-tuning two.

| Candidate | Fill (light) | White label | Black label | Nav-bar tint |
|---|---|---|---|---|
| **blue** `Color(.systemBlue)` — control | `#0088FF` | 3.52 | 5.97 | 3.41 |
| blue `Color.blue` | `#0088FF` | 3.52 | 5.97 | 3.48 |
| **teal** `Color.teal` — today | `#00C3D0` | **2.16** | 9.72 | **2.13** |
| teal `Color(.systemTeal)` | `#00C3D0` | **2.16** | 9.72 | **2.09** |
| mint | `#00C8B3` | **2.12** | 9.91 | **2.05** |
| cyan | `#00C0E8` | **2.16** | 9.71 | **2.10** |
| indigo | `#6155F5` | 5.09 | 4.13 | 4.93 |
| green | `#34C759` | **2.22** | 9.46 | **2.15** |
| orange | `#FF8D28` | **2.31** | 9.09 | **2.24** |
| `#3B82F6` blue | `#3B82F6` | 3.68 | 5.71 | 3.56 |
| `#10B981` emerald | `#10B981` | **2.54** | 8.28 | **2.46** |
| `#7C3AED` violet | `#7C3AED` | 5.70 | 3.69 | 5.52 |

The 2.13:1 in item 18 reproduces exactly. Blue measures 3.41 here rather than
the 3.89 recorded earlier; both clear the floor, and the earlier number was
probably taken against a different bar surface.

Light mode is the strict room: every light hue fails there, and the only
candidates that clear 3:1 as a light-mode bar glyph are the blues, indigo and
violet — the same four that clear the dark white label. A colour set with two
hand-picked values can rescue a light hue in light mode, but nothing in that
column needs rescuing if the accent is a blue.

**Since taken up, and the mint's row here reproduces.** The accent went to mint
(item 13f) rather than to a blue, so the rescue in that sentence is what item 18
built: `#009888` for light and the mint's own `#00DAC3` for dark. This table's
mint row was re-measured first, on a different build and a different probe, and
came back `#00C8B3` with the bar glyph at 2.05 and the white label at 2.12 —
identical to what is written above. The system blue control reproduces at 3.41
and 3.52 too. See item 18 in `docs/TODO.md` for the light value's own numbers
and for the two neighbouring candidates that were rendered and rejected.

---

## Recommendation

*(Not taken. The accent went to the system mint in item 13f, on the user's
call, and then to item 18's two-value colour set. Kept because the reasoning is
the evidence item 18 was built on, and because these three colours are still
where a future accent question starts.)*

**Blue was right.** It was the control for a reason and it wins on the merits,
not by default: it is the only family that clears 3:1 with a white label *and*
a dark one, in *both* appearances, which means the accent stops dictating what
can be written on it.

Three colours clear every floor measured here — system blue, `#3B82F6`, and
indigo. Ranked:

1. **`#3B82F6`, as the dark value.** Best white-label margin of anything that
   also clears the bar (3.68 dark, 3.68 light, against system blue's 3.23 and
   3.52), and at `S = 0.76` it is the one candidate that follows the
   desaturation guidance rather than contradicting it. Item 18 writes explicit
   per-appearance values into a colour set anyway, so "it is a hex and not a
   dynamic system colour" costs nothing here — the colour set *is* the two
   values.
2. **`Color(.systemBlue)`**, if the accent should stay a system colour. Every
   floor cleared, the bar background is the one Apple tuned for this exact hue,
   and it is zero decisions to maintain. Its white label at 3.23 is the
   thinnest passing margin in the recommendation, which is the only reason it
   is second.
3. **Indigo**, if "not the default iOS blue" matters. Clears everything in both
   appearances with either label, and is genuinely distinct on screen. It is
   the one to pick on taste; nothing in the numbers is against it.

Whichever of the three: **drop the forced label colour with it.** `Color.onAccent`,
`onAccentFill()` and the disabled-button carve-out inside it exist because teal
could not carry a white label. On a blue the button goes back to standard, and
item 13b's whole apparatus can be deleted rather than re-tuned.

Teal, mint, cyan, green, orange and emerald are all the same result in different
hues: a strong bar glyph, an illegal white label, and — in light mode, before
item 18 rescues them by hand — a bar glyph at half the floor. Violet is the only
interesting failure: it is the one colour that would put a white label back with
real margin, and it pays for it with the weakest bar glyph measured and a
near-black label that misses at 2.99.

---

## Light mode, rendered

The exercise above, done for the other appearance, which is what item 31 asked
for. **Nothing here has been merged**: the app still ships `#009888` in light,
and the photographs are outside the repo in `~/dev/boring-tracker-pairing/` as
`31-light-*.png` — six candidates on home and on settings, four strips, and
three of the deep ones drawn with a white label.

### The surfaces, sampled rather than assumed

Every ratio below is arithmetic from the hex values, against backgrounds read
out of the PNGs by decoding the IDAT bytes:

| where | light |
|---|---|
| the circle behind a nav-bar glyph | `#FBFBFF` |
| a `Form` row | `#FFFFFF` |
| the bottom bar's material | `#FAFAFD` |
| the grouped list background | `#F2F2F7` |

Item 18's two published numbers for `#009888` fall out of those exactly — 3.48
as a bar glyph and 3.59 as a `Form` row foreground — which is the check that
this table is measuring the same thing item 18 was.

### The candidates

| # | hex | what it is | bar glyph | Form row | black label |
|---|---|---|---|---|---|
| 1 | `#009888` | today: the system mint, darkened | 3.48 | 3.59 | 5.85 |
| 2 | `#00857A` | the same hue, deeper still | 4.39 | 4.53 | 4.64 |
| 3 | `#0F766E` | a cooler, greyer teal | 5.30 | 5.47 | **3.84** |
| 4 | `#00796B` | a saturated deep teal | 5.15 | 5.32 | **3.95** |
| 5 | `#0E7490` | deep blue-teal | 5.19 | 5.36 | **3.92** |
| 6 | `#047857` | deep green | 5.31 | 5.48 | **3.83** |

### The constraint is not the one item 31 names

Item 31 says the colour still has to clear 3:1 as a tint and as a form-row
foreground. **Every candidate here clears that with room, including today's**,
so it does not choose between them. What does is the last column: `Log` is
drawn in `Color.onAccent`, which is black, and a deeper fill takes that down.
Today's 5.85 is comfortable; a genuinely deep light accent lands near 3.9,
which clears the 3:1 floor a UI element needs and misses the 4.5 ordinary text
wants at that size.

So light mode has a window rather than a floor, and today's colour is inside it
near the top. **That is why it looks dimmed**: it is as deep as it can be while
carrying a black word, and the murk item 31 reports is that ceiling, not a
mistake in the arithmetic.

### The way out is the label, and it was rendered too

A deep light accent wants a *white* label, which is what iOS would draw
unasked. On these three it measures 5.47 (`#0F766E`), 5.32 (`#00796B`) and 5.48
(`#047857`) — better than black on today's fill. Photographed as
`31-light-strip-black-vs-white-label.png`, and the difference on screen is
larger than the numbers suggest: black on a deep teal reads as muddy where
white reads as a control.

The cost is real and it is item 13b's: `Color.onAccent` would become a colour
set, black in dark and white in light, and the app would have one control whose
word changes colour with the appearance. `Color.onAccent`'s own doc argues
against exactly that — "what sits on the accent is decided by the accent, not
by the mode" — written when the light fill was `#009888`, where black works.
A deeper light fill is the case that argument was not made against.

### Recommendation

**4, `#00796B`, with a white label in light.** It is a colour chosen for light
mode rather than the mint with its brightness taken away, it stays in the dark
value's own green-teal family so the app does not read as two apps, and it
clears every floor with margin. 6 (`#047857`) is the same answer in a greener
hue and is the one to pick on taste; 5 (`#0E7490`) is the furthest from the
mint and the one most likely to read as a different app between appearances.

**If `Color.onAccent` must stay black**, it is 2, `#00857A` — deeper than
today, clears everything, still carries a black `Log` at 4.64. But it is the
same hue with less light in it, which is the thing item 31 asked not to do
again, so it is the compromise rather than the answer.

The user picks. Dark is untouched either way.
