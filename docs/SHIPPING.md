# Shipping

Everything about Apple accounts, costs, and App Store submission — written
down now so it doesn't have to be reconstructed six months from now while
staring at App Store Connect.

Apple changes these rules regularly. Treat this as a map, not a contract, and
re-check anything consequential at the time you do it.

## While building: pay nothing

- **Simulator builds need no account at all.** This covers nearly all
  development.
- **Running on your own iPhone needs only a free Apple ID** (Xcode calls it a
  personal team). The profile expires after **7 days**, so the app stops
  launching until you rebuild from Xcode.
- Free accounts cannot use App Groups, iCloud, or push notifications.

## When the $99 actually becomes necessary

In the order these will bite:

1. **Daily use on your own phone.** The 7-day expiry is what makes a free
   account impractical once the app is good enough to rely on. This is likely
   the real trigger, and it arrives before shipping does.
2. **Widgets**, which need an App Group to share the store file.
3. **Sync**, which needs an iCloud entitlement.
4. **TestFlight**, to let anyone else try it.
5. **The App Store.**

## Enrolling

- **Apple Developer Program, $99/year**, renewed annually.
- Enroll as an **individual**, not an organization. Organization enrollment
  requires a D-U-N-S number and takes considerably longer, for benefits this
  project doesn't need.
- Individual enrollment publishes under **your legal name** as the seller.
- No fee waiver applies — those exist for nonprofits, education, and
  government, not for free open-source apps by individuals.

### If the membership lapses

Worth understanding before depending on it:

- Apple **removes your apps from the App Store**. Not hidden — unavailable.
- Apps already installed keep working. They aren't deleted or disabled.
- Re-downloading a removed app from purchase history is unreliable; don't
  count on it.
- TestFlight builds stop immediately.
- Renewing restores things, and Apple warns repeatedly before expiry.

The real mitigation is that this project is open source and stores data in a
plain file: if it's ever abandoned, existing installs keep working, data
exports, and anyone can fork and ship it. That's worth stating in the README,
because paid competitors can't say it.

## The EU trader requirement — declaring non-trader

Under the Digital Services Act, Apple requires developers distributing in the
EU to declare **trader status**. This is not optional — apps whose developers
didn't declare have been removed from EU storefronts. The answer here is
"non-trader", not silence.

**Decided: non-trader.** The name being public is fine; the address is not, and
that distinction is exactly what the rule turns on.

- Declaring **trader** means Apple publicly displays your name, address, phone
  number and email on the listing in EU storefronts. For an individual, that
  can mean a home address.
- **Non-trader** publishes no contact details. A trader acts for purposes
  relating to their trade, business, craft or profession, and this app has no
  price, no in-app purchases, no ads, no subscription and collects no data to
  monetize. There is no commercial purpose to point at.
- **The seller name is a separate question with no choice in it.** An
  individual account publishes under the developer's legal name whichever way
  the trader question is answered. That part is accepted.
- Any monetization at all — paid app, in-app purchase, ads, even a tip jar —
  would likely make this a trade, and with it the address becomes public. One
  more thing rule 1 in PHILOSOPHY.md is quietly buying.

**This policy has shifted more than once since it landed, so verify it at
enrollment rather than trusting this page.** If you do end up classed as a
trader, the usual answer is a virtual office or mailbox address rather than
your home.

## Naming and the competitive landscape

Researched August 2026 against the App Store search API. App Store listings
change constantly — re-check before committing to anything here.

### The name is Boring Tracker

Settled. It was already the design principle — PHILOSOPHY.md says "boring and
native" — and it promises no gamification, no streaks and no dopamine before
anyone opens the app. It also avoids "simple", a word every competitor has
already burned while shipping the opposite.

- **App Store listing name:** Boring Tracker
- **Home screen label** (`CFBundleDisplayName`): `Boring`, because home screen
  labels truncate around 12 characters
- **Bundle id:** `com.novoselov.boringtracker` — permanent

Runners-up, both available if it ever has to change: **Napkin Tracker** (more
charming, evokes jotting a number on the back of something) and **Quiet
Tracker**. The internal Xcode target, source folder and store directory are
named to match: `BoringTracker` and `boring-tracker`.

### Availability

**"Boring Tracker" is unclaimed**, as is *Whatever Tracker*. Of ~56
"Something Tracker" names checked, 45 were free — including *Napkin*, *Quiet*,
*Plain*, *Blunt*, *Honest*, *Calm*, *Lean*, *Minimal*, *Featherweight* and
*Spartan*. Also unclaimed: *Track Whatever*, *Just Track*, *Trackr*,
*Tickmark*, *Tap Log*, *Nought*, *Scribble*.

Available but worth avoiding regardless: **Zero Tracker** (collides with
*Zero: Fasting & Food Tracker*, ~445k ratings, same category), **Snap
Tracker** ("snap" now means AI photo calorie estimation — it would attract
exactly the users this app refuses to serve), **Free Tracker** (reads spammy;
Apple is particular about promotional words in names), and **Naked Tracker**
(bad search neighbours).

Taken: *Tally*, *Counted*, *Jot*, *Tick*, *Plainly*, *Log It*, *Quick Log*,
*Loggit*, *Kept*, *Numo*, *Blank*, *Simply Track*, *Daily Numbers*, and
*Whatever* on its own (a decision-making app).

The tally-shaped names are especially crowded — several counter apps compete
there alongside *Tally: The Anything Tracker*, so *Track Anything* and *Tally
Anything* are worth avoiding even though they're technically free. Being
mistaken for a tally counter is the wrong association anyway.

Note that three different names are involved and only one must be unique:

- **App Store listing name** — must be unique, claimed first-come, 30 chars.
- **`CFBundleDisplayName`** — the label under the home screen icon. Does *not*
  need to be unique. It is `Boring`, set in `project.yml` as
  `INFOPLIST_KEY_CFBundleDisplayName`, which is what the bullet at the top of
  this section already says. This line used to read `Whatever` — the name the
  project carried before the 2026-08-11 rename — and it contradicted its own
  page.
- **Bundle identifier** — permanent, and changing it makes it a different app.

### Who is already here

| App | Rating | Ratings | Monetization |
|---|---|---|---|
| Stupid Simple Macro Tracker | 4.6 | ~7,800 (claims 2.7M users) | premium subscription, ads |
| Tally: The Anything Tracker | 4.4 | ~4,100 | premium subscription |

Stupid Simple Macro Tracker's own description sells it as the app people
switch to when they're "done fighting with the other guys" and their
"cluttered dashboards, screen-hijacking ads" — which is this project's pitch
almost word for word, from an app that runs ads and sells a subscription.

**The useful conclusion: simplicity is not the differentiator.** Millions of
people already chose a simple tracker, and the leading ones monetize anyway.
The gap is that nobody credible is genuinely free — no ads, no subscription,
no account, no telemetry, source published. That is the one thing a
venture-funded competitor cannot copy without breaking its own business, and
it's why the rules in PHILOSOPHY.md are the product rather than a constraint
on it.

### Listing strategy

Nobody searches for "boring tracker", and that's fine — App Store discovery
comes from the subtitle and the hidden keywords field, not the name. So the
name can be distinctive while those carry the search terms:

- **Name:** `Boring Tracker`
- **Subtitle** (30 chars): along the lines of `Calories, weight, anything`
- **Keywords** (100 chars): calorie, macro, protein, weight, habit, log,
  counter, free, no ads, open source

Lead the description with what's *absent* — no ads, no subscription, no
account, no data collection — because that's the part that is both true and
rare. The name does useful work here too: leaning into "boring" makes the
absence of streaks, badges and nagging read as intent rather than as missing
features.

**Not checked: trademarks.** App Store availability isn't clearance to use a
name. A USPTO search is cheap insurance before printing it anywhere, though a
phrase this generic is unlikely to be contested.

## The icon

**Chosen and installed: `ledger`**, the recommendation below. It lives in the
asset catalog as `AppIcon.appiconset`, one 1024 square and nothing else — Xcode
derives the smaller sizes. That copy is the only one in the repo and is
byte-identical to the source, so nothing extra needed keeping: `.gitignore`
refuses `*.png` but makes `**/Assets.xcassets/**/*.png` the exception.

The six candidates were rendered so there was something to choose between, and
they are not in the repo — they and the standalone Core Graphics script that
drew them stayed on the machine that made them, outside the working copy. The
script re-renders all six in about a second with no project and no simulator,
so the way to see them again is to write it again from the descriptions below,
not to go looking for a directory that was never published.

### What it has to be

The name is the brief. *Boring Tracker* promises no streaks, no badges and no
opinion about your body, so the icon cannot promise energy or transformation —
an icon that oversells is the first broken promise a user sees. It should read
as a utility that shipped inside iOS, which rules out the whole fitness
vocabulary: flames, bolts, hearts, rings, gauges, arrows trending up.

The size that decides it is **40pt** — Spotlight, Settings, notifications —
so everything was designed there and scaled up, and every candidate was also
rendered at 20pt, which is where a mark actually dies.

### The candidates

`bars` (four bars, no trend), `grid` (one day marked on a grid of days),
`ledger` (rows of label and number), `tally` (four and a crossbar), `point`
(one value written down), `keypad` (the number pad is the interface).

Judged from renders at device pixel sizes, not on a device — no simulator was
involved. At 20pt, `grid` collapses into grey texture and `tally` into a
scribble; `keypad` survives but reads as Calculator, which is a bad neighbour
to be mistaken for. `bars`, `ledger` and `point` all hold.

**The recommendation is `ledger`**: three rows, a label rule on the left and a
shorter block right-aligned like a column of numbers. It says *things get
written down here in rows*, which is what the app is, and unlike `bars` it
promises no trend. `bars` is the safe runner-up and the most immediately
readable as "tracker", at the cost of looking like every competitor.

### Background colour, and why it is not the accent

Three treatments were rendered: teal fill with a white mark, near-black with a
teal mark, and near-white with a teal mark. An icon's background has to keep
its silhouette against **both** home screens, and only the mid-luminance fill
does. WCAG contrast of the icon background against the home screen behind it,
computed in sRGB by the render script:

| treatment | vs light `#EFEFF4` | vs dark `#0B0B0C` |
|---|---|---|
| teal `#00786C` | 4.69:1 | 3.66:1 |
| ink `#1F2426` | 13.69:1 | 1.25:1 |
| paper `#F2F2F7` | 1.03:1 | 17.63:1 |

The near-white icon is invisible on a light home screen and the near-black one
is invisible on a dark one, which the renders show plainly.

The teal is `#00786C`, **darker than the shipped accent** `AccentFill`
(`#009888`). White on the accent measures 3.59:1; darkening it to `#00786C`
gets the mark to 5.38:1 while keeping the silhouette numbers above. The icon
does not have to be the accent colour, and here it should not be.

### The prompt

For trying another tool's take on it. It is deliberately full of negatives: a
prompt that would produce any fitness app's icon is a failed prompt.

```
Design an iOS app icon for Boring Tracker.

What the app is. You open it, type a number, and it is gone. Calories, weight,
water, cigarettes, pushups, hours of sleep — any number that repeats. It is
free, has no account, no server, no ads and collects nothing. It is one
person's utility, not a product with a brand.

What the name promises. "Boring" is a commitment the app can be held to: no
streaks, no badges, no confetti, no rings, no grades, no notification asking
where you have been. The app has no opinion about your body. The icon must not
promise energy, transformation or progress, because the app deliberately
refuses to deliver any of it. It should look like a utility that shipped inside
iOS — closer to Calculator, Clock or Files than to any fitness app.

Design it at 40pt and scale up, not the reverse. 40pt is Spotlight, Settings
and notifications, and that is where most people will ever see it. If a detail
does not survive at 120x120 pixels, it does not exist.

The composition. One flat, solid, mid-luminance background colour filling the
whole square, and exactly one white mark on it. The mark is a plain geometric
shape or a small group of them — bars, rules, dots — not an illustration.
Generous margins: the mark occupies roughly the middle 65% of the square,
because iOS crops the square to a rounded superellipse.

The background colour must survive both home screens. Near-white disappears
against a light home screen and near-black disappears against a dark one; a
mid-luminance saturated colour is the only kind that keeps its silhouette on
both. Use a deep teal around #00786C, which measures 4.7:1 against a light home
screen and 3.7:1 against a dark one, with the white mark at 5.4:1 against the
teal. Any substitute must clear roughly the same three numbers.

Hard constraints.
- No text, no letters, no digits. The app's name is already printed under the
  icon, and a word at 40pt is a smudge.
- No gradients, no glow, no drop shadows, no bevel, no 3D, no glass, no
  texture, no outer border. Flat fills only.
- One idea. Not a mark plus a badge plus a background pattern.
- Nothing from the fitness-app vocabulary: no flame, no lightning bolt, no
  heart, no dumbbell, no apple, no leaf, no droplet, no ring, no gauge, no
  progress arc, no arrow trending up, no checkmark, no star, no trophy.
- No mascot, no face, no hand, no character of any kind.
- No tally marks. They read as a counter app, and that is the wrong shelf.
- Nothing that resembles an existing Apple icon: not a keypad grid
  (Calculator), not a bulleted list with round bullets (Reminders), not a
  folder, not a lined yellow page (Notes).

What good looks like. Somebody glancing at it at 40pt should read "something is
written down here, in rows, with numbers" — a record, a ledger, a plotted
value. Not "this app will improve you". Boring on purpose, and confident about
it.

Deliver a flat vector-style 1024x1024 square with no transparency and no
pre-applied rounded corners — iOS applies the mask itself.
```

### Two things to remember when one is installed

The App Store rejects an icon with an alpha channel, so the 1024 must be a flat
opaque square — and it must not have rounded corners baked in, because iOS
applies the mask itself and a pre-rounded icon gets rounded twice.

Both were checked on the installed one rather than assumed. The PNG's IHDR
gives colour type 2 — truecolour, no alpha — with no `tRNS` chunk, and all four
corner pixels read `#00786C`, the background, so there is nothing pre-rounded
for iOS to round again.

## Before submitting

Things that are easier handled early than discovered at submission:

- **Encryption export compliance.** The app uses no encryption, so
  `ITSAppUsesNonExemptEncryption` is `NO` and App Store Connect stops asking on
  every build. **Done** — it is `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption`
  on the app target in `project.yml`, and it reads back out of the built
  Release bundle as a boolean false.
- **Privacy label: "Data Not Collected."** Genuinely true here, and one of the
  better things about this app. Keep it true.
- **Privacy policy URL is required** for every app, even one that collects
  nothing. A short page stating that the app collects no data, has no servers,
  and stores everything on the device. **Done** — `docs/index.html`, served by
  GitHub Pages at `https://novoselov-ab.github.io/boring-tracker/`.
- **Support URL is required.** The GitHub repository works, and it is public.
- **App name availability.** Names are claimed globally and first-come. Check
  before getting attached to one. Display name and bundle id are separate: the
  display name can change any time, the **bundle id is permanent** — changing
  it makes it a different app that existing users won't get updates for.
- **Screenshots** for the currently required iPhone display sizes, plus iPad
  sizes if the app is ever listed as supporting iPad.
- **Age rating** questionnaire. Nothing here is contentious.

### One review risk to be aware of

Guideline 4.2, *Minimum Functionality*, lets Apple reject apps it considers too
simple. This app is deliberately minimal, which is the point, but that's not a
defense the reviewer knows about. If it comes up, the answer is to show the
real functionality — multiple tracker types, history, graphs, export/import —
rather than to add features. Do not compromise the philosophy to pass review.

## Licensing and the App Store

**MIT is the right choice and GPL would not be.** GPLv3 conflicts with Apple's
distribution terms, and GPL-licensed apps have been pulled from the App Store
over it. MIT has no such problem, and it lets anyone fork and ship their own
version — which is the whole safety net described above.

Being open source creates no conflict with App Store distribution. Linking the
repository from the App Store description is worth doing; for the people who
care about this app's promises, the source is the proof.

## The checklist

Everything above is the reasoning. This is the order.

Assembled 2026-08-19 from the sections above and from the state of this
repository. **No requirement here was invented**: each item either points at
the section of this page that records it, or at something checkable in the
repo. Anything that could not be confirmed from one of those two places is
marked **unverified** rather than stated — Apple moves these rules, and a
confident sentence is worse than an honest gap when the cost of being wrong is
a rejected submission.

**(human)** marks a step no session can do: it needs an Apple account, a
payment, a judgement about the product, or a decision that cannot be walked
back after release. Everything unmarked is ordinary work in this repository.

### 1. Before anything can be uploaded at all

- [ ] **(human)** **Enrol in the Apple Developer Program.** $99/year, as an
      **individual** — see *Enrolling*, which also covers why not an
      organization and what a lapsed membership does. **Submitted 2026-08-20**
      from the Apple Developer app on the phone, with the identity check; it
      reads *Enrollment Pending*. Nothing below that needs an account can start
      until Apple approves it.
- [ ] **(human)** **Accept the agreements App Store Connect asks for.** A free
      app with no purchases should need no tax or banking details, but which
      agreements a free app must accept is **unverified** here.
- [ ] **(human)** **Answer the EU trader declaration: non-trader.** Decided —
      see *The EU trader requirement*, which says why a free app with no ads
      and no purchases isn't a trade, and why the seller name is public
      regardless. Still needs your hand at enrollment, and the policy has
      shifted more than once, so read what Apple actually asks on the day.
- [ ] **(human)** **Claim the name.** `Boring Tracker`, unclaimed as of the
      August 2026 check in *Naming and the competitive landscape*, and claimed
      first-come. Re-check before getting attached to it. Trademarks were
      never searched — the same section says so.

### 2. What the app itself has to carry

- [x] **(human)** **Choose the icon.** `ledger`, the recommendation in *The
      icon*, on the deep teal `#00786C` whose contrast numbers are there too.
- [x] **Point the build at it.** `AppIcon.appiconset` holds the 1024 and
      `ASSETCATALOG_COMPILER_APPICON_NAME` is `AppIcon`. Verified flat, opaque
      and un-rounded, and seen on the simulator home screen, in Spotlight and
      in Settings › Apps, in both appearances.
- [x] **Encryption declaration.** `ITSAppUsesNonExemptEncryption` is `NO` on
      the app target — see *Before submitting*.
- [x] **Version numbers.** `MARKETING_VERSION` is `1.0`.
      `CURRENT_PROJECT_VERSION` is a bare counter: **add one for every upload
      App Store Connect accepts**, including a re-upload of the same version
      after a rejection.
- [x] **(human)** **Decide whether this is an iPhone app or a universal one.**
      **iPhone only**, decided 2026-08-20. `TARGETED_DEVICE_FAMILY` is now
      `"1"` on the app target in `project.yml`, set explicitly rather than left
      to XcodeGen's `"1,2"` default, and it reads back as `1` in both the Debug
      and Release configurations of the generated project. The test bundle
      keeps the default and does not matter — it is never uploaded.

      What that buys: one screenshot set instead of two, no iPad review pass,
      and no need to answer the Split View question. The build is portrait-only
      with no `UIRequiresFullScreen`, and an iPad-family app that cannot do
      Split View has historically been rejected for it; whether that still
      holds under the iOS 26 SDK stayed **unverified**, and dropping iPad is
      what makes it moot rather than a risk to carry. PRODUCT.md put iPad under
      "not while there's no iPhone app" anyway. Adding iPad later is an
      ordinary update; removing it after release would have stranded whoever
      installed it there, which is why this had to be settled before the first
      submission and not after.
- [x] **Make the repository public.** Done — it is public as of 2026-08-19,
      under the MIT license `LICENSE` carries. The support URL below is the
      repository, and rule 8 of PHILOSOPHY.md — open source, anyone can fork
      and ship it — is one of the promises the listing is built on.
- [ ] **Green suite, and a project that matches its spec.** `xcodebuild test`
      passes and `xcodegen generate` leaves `BoringTracker.xcodeproj`
      unchanged.

### 3. Two pages that have to exist on the web

Both are **mandatory for every app**, including one that collects nothing —
see *Before submitting*.

Both are covered. What is left in each case is pasting the URL into App
Store Connect, which needs the account.

- [x] **Privacy policy URL** — **`https://novoselov-ab.github.io/boring-tracker/`**.
      The page is `docs/index.html`, served by GitHub Pages from `main`, folder
      `/docs`. One static file, no generator and nothing fetched from anywhere:
      an analytics tag on the privacy page of an app whose claim is *collects
      nothing* would undo the claim it is there to make. Everything it states
      was checked against the source rather than written from the philosophy —
      no networking API appears anywhere in `BoringTracker/`, there are no
      third-party packages, and no permission-requiring framework is imported.
      `docs/.nojekyll` is what stops GitHub rendering `TODO.md` and the rest
      of `docs/` as web pages — the alternative, with Pages serving from
      `/docs`, is a 138KB decision log published as a site. They are still
      copied to the site as files, and a branch-folder deploy gives no way not
      to: checked after the deploy, `…/TODO.md` returns 200 as
      `text/markdown`, plain text rather than a page.
- [x] **Support URL** — **`https://github.com/novoselov-ab/boring-tracker`**.
      The repository, public since 2026-08-19, with issues as the contact
      route the privacy page points people at.

### 4. The build

- [ ] **(human)** **Archive with the paid team and upload.** Verified in this
      repository on 2026-08-19: a Release build for `generic/platform=iOS`
      succeeds both unsigned and signed, the latter on a free personal team's
      provisioning profile. A **distribution** archive and the upload itself
      are **unverified** — both need the paid account.

### 5. The listing

- [ ] **(human)** **Name, subtitle, keywords, description.** Drafts are in
      *Listing strategy*, including why the subtitle and keywords carry the
      search terms rather than the name. Lead the description with what is
      absent, and link the repository.
- [ ] **(human)** **Screenshots**, at the iPhone display sizes App Store
      Connect currently requires. **The exact set is unverified here** —
      *Before submitting* records only that they are required, and the sizes
      change; read them off App Store Connect at the time. iPad sizes are
      needed only if the app is listed as supporting iPad, which is the
      decision above.
- [ ] **(human)** **App Privacy: "Data Not Collected".** Truthful here, which
      *Before submitting* calls one of the better things about this app. It is
      a claim about the whole app, so it stays true only while rule 5 does.
- [ ] **(human)** **Age rating questionnaire.** Nothing here is contentious.
- [ ] **(human)** **Price: free**, with no in-app purchases. Rule 1, and it is
      also what keeps the non-trader case above intact.
- [ ] **Encryption, again.** The Info.plist key is what stops the question
      being asked per upload. Whether the first submission still asks it once
      in the web form is **unverified**.

### 6. Submitting

- [ ] **(human)** **Submit for review**, and expect *Guideline 4.2, Minimum
      Functionality* to be the one real risk — see *One review risk to be
      aware of*. The answer is to show the functionality that exists, not to
      add features.
