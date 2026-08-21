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

**Checked on the day and declared: non-trader, 2026-08-20.** App Store Connect
raised it itself, as a blocking banner — *to make content available in the EU
you need to let us know if you are a trader* — and the definition it put in
front of the choice was the DSA's own, linking to Apple's *Managing European
Union Digital Services Act requirements*. That is the definition this section
argues against, unchanged, so the reasoning above held on the day.

## Naming and the competitive landscape

Researched August 2026 against the App Store search API. App Store listings
change constantly — re-check before committing to anything here.

### The name is Boring Tracker

Settled. It was already the design principle — PHILOSOPHY.md says "boring and
native" — and it promises no gamification, no streaks and no dopamine before
anyone opens the app. It also avoids "simple", a word every competitor has
already burned while shipping the opposite.

- **App Store listing name:** Boring Tracker
- **Home screen label** (`CFBundleDisplayName`): `Boring Tracker` — the full
  name, since 2026-08-20. It used to be `Boring`, because this line used to say
  "labels truncate around 12 characters". **That was never the rule: iOS
  truncates on rendered width, not on character count, and all 14 characters fit
  with no ellipsis on an iPhone 17 and on a 375pt SE**, the narrowest phone this
  app supports. The SE fits the two words by condensing them about 20% (74.5pt
  against 89pt measured separately), which is iOS tightening a string before it
  will ellipsise it.
  The label is also the string Spotlight matches, and that is what the short one
  cost: with `Boring`, typing "tracker" did not find the app at all, checked
  twice from a clean uninstall with a 25s settle and "boring" as a same-minute
  control that was found both times. With `Boring Tracker` both words return it
  as Top Hit. (`Tracker` alone was found by "tracker" and not by "boring", which
  is why the full name and not the other short one.)
  **The trap:** before first launch the new-app dot steals label width and the
  home screen renders `BoringTracker` or `Boring T…`, which looks exactly like
  the truncation this bullet used to claim and is not it. Launch once, then
  judge.
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
  need to be unique. It is `Boring Tracker`, set in `project.yml` as
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

**A mint `+` inside a mint ring on a dark field.** It lives in the asset
catalog as `AppIcon.appiconset`, one 1024 square and nothing else — Xcode
derives every smaller size. `.gitignore` refuses `*.png` but makes
`**/Assets.xcassets/**/*.png` the exception, so that one copy is tracked.

Field `#1C1C1E`, mark `#00DAC3`. Both are the app's own values: the field is
the card colour, the surface the `+` buttons sit on, and the mark is
`AccentFill` in dark, the colour the app draws the card `+` in — so the icon
matches the thing it depicts in shape *and* in colour. **In dark.** One file
ships for both appearances, so in light the app's `+` goes `#009888` and the
icon does not follow; matching there was never on the table.

The mark shipped as `#00E8D8` until 2026-08-20, a second mint close enough to
the accent to read as a mistake. Contrast against the field measures
**9.57:1**, sampled as the 1024's own two modal colours rather than computed
from these hex values.

The mark was measured off the chosen artwork and redrawn with Core Graphics
rather than repaired — ring outer radius 350.5px with a 47px stroke, plus bar
49px thick with round caps, centred on 512 — because the artwork arrived
pre-masked and slightly lopsided.

It replaced `ledger`, rows of label and number on a deep teal, which shipped
first and was chosen from six rendered candidates. That reasoning is in the
history rather than here; `git log` the appiconset for it.

### What any icon here has to be

- **Full bleed and opaque.** One 1024×1024 square, sRGB, PNG colour type 2,
  no alpha and no `tRNS`. The App Store rejects an alpha channel outright.
- **No corners baked in.** iOS applies its own superellipse, so a pre-rounded
  icon gets rounded twice. Watch for this in supplied artwork: the current
  mark arrived with a rounded-rect mask already applied — corners `#000000`
  against a `#100F10` field — and because that mask is anti-aliased, swapping
  exact black alone would have left a grey halo tracing the old curve. The
  check that catches both traps is a diagonal from each corner inward: it
  must read one value all the way in to the mark.
- **Designed at 40pt.** Spotlight, Settings and notifications are where most
  people will ever see it, and a detail that does not survive 120×120 pixels
  does not exist.
- **Judged installed, not in a preview.** Build it, put it on the simulator,
  and look at the home screen, the Settings app list and Spotlight in both
  appearances. iOS 26 renders the mark with a glass treatment of its own —
  a highlight, a shadow and a dimmer mint than the file contains — which no
  1024 preview shows. A wide gradient across the field suppresses that
  treatment; a flat or nearly flat field gets it.

### The silhouette cost of a dark icon

A background keeps its silhouette against **both** home screens only if it is
mid-luminance: near-white disappears on a light one, near-black on a dark one.
`#1C1C1E` against a black wallpaper is the second case. It was chosen with
that known and accepted — the mark carries the icon, not the field — but the
constraint is real, and the lever on it is background luminance, not the mark.

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

## Filling the listing without the web UI

Nearly all of the listing can be written over the **App Store Connect API**
rather than typed into forms. Established 2026-08-20 by probing the live app
record, not from documentation — every row below was either read back with a
200 or refused with a 404.

**The credential.** A `.p8` key generated in App Store Connect › Users and
Access › Integrations, role **App Manager**. It downloads exactly once and
cannot be re-fetched — losing it means revoking and generating another. It
lives at `~/.appstoreconnect/`, mode 600, **outside the repository**, and the
Key ID and Issuer ID are deliberately not written down here: this repo is
public, and the three together are the whole credential. The key can price,
submit and release the app, so it is not a config value.

Auth is a JWT signed ES256, `aud` of `appstoreconnect-v1`, twenty-minute
expiry. Two things bit on this machine and would bite again on a fresh clone:
the system `python3` is a **3.6 framework build with no CA bundle**, so
`urllib` fails the TLS handshake against Apple and the transport has to be
`curl`; and neither PyJWT nor `cryptography` is installed, so the signature
comes out of `openssl dgst -sha256 -sign` as **DER** and has to be unpacked
into the raw `r||s` pair a JWS wants. Neither is exotic, both cost a round trip
to discover.

**The identifiers**, read back from the API on 2026-08-20:

| what | value |
|---|---|
| app id | `6803768789` |
| bundle id | `com.novoselov.boringtracker` |
| SKU | `boring-tracker` |
| version record | `1.0`, created with the app, state `PREPARE_FOR_SUBMISSION` |

**What the API covers**, and what it does not:

| Field | Route | Checked |
|---|---|---|
| Name, subtitle, privacy policy URL | `appInfoLocalizations` | resource reachable |
| Description, keywords, promo text, what's new, marketing + support URL | `appStoreVersionLocalizations` | resource reachable |
| Categories | `appInfos` relationships | present on the record |
| Screenshots | `appScreenshotSets` → reserve, upload, commit | not yet exercised |
| Price: free | `appPriceSchedule` | present on the record |
| Age rating | `appInfos/{id}/ageRatingDeclaration` | **read back, 200** |
| Submit for review | `reviewSubmissions` | present on the record |
| Build upload | not the API — `xcrun altool --upload-app`, same key | — |
| **App Privacy — the nutrition label** | **nothing** | **404** |

**App Privacy has to be answered in the web UI.** There is no relationship for
it on the app resource — the record carries 41 relationships and not one of
them is data usage — and `/v1/appDataUsages`, `/v1/appDataUsageCategories` and
`/v1/appDataUsagesPublishState` each return `PATH_ERROR`, *the resource does
not exist*. This was expected to work and does not. It is also the one answer
that is a public claim about the app rather than a form field, so answering it
by hand is no great loss.

**The age rating questionnaire is a single PATCH** of one object whose fields
are all `null` until set. The live attribute list confirms the July 2025
overhaul landed: alongside `healthOrWellnessTopics` and
`medicalOrTreatmentInformation` — the two APPSTORE.md flags as the judgement
call for an app that records calories — it now carries `ageAssurance`,
`parentalControls`, `lootBox`, `socialMediaAgeRestricted`,
`ageRatingOverrideV2` and `developerAgeRatingInfoUrl`.

**A PATCH is atomic, and one bad attribute loses the whole call.** Writing the
version localization with `whatsNew` in it returned **409 STATE_ERROR,
*Attribute 'whatsNew' cannot be edited at this time*** — and the description,
keywords, promotional text and both URLs in the same request were not written
either. Nothing partial, nothing reported per field. Send a field the state
machine will not take and everything beside it is lost, so the useful habit is
to read every attribute back rather than trusting a 200. One of the four writes
also died mid-flight on a `curl: (56) Connection reset by peer`; the API is not
reliably one-shot, and the retry was clean.

**Browser automation was considered and rejected.** Two-factor auth, session
cookies that expire, and a JavaScript app that rearranges its own DOM, against
a documented and stable REST API.

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
- [x] **(human)** **Accept the agreements App Store Connect asks for.** Done —
      nothing had to be accepted by hand. **Verified 2026-08-20** in App Store
      Connect › Business: the **Free Apps Agreement** was already *Active*, dated
      Aug 20 2026 – Aug 20 2027, on the day enrollment was approved. The
      **Paid Apps Agreement** sits at *New* and stays there: it is the only one
      that wants tax and banking details, and none were asked for. So the
      earlier guess was right — a free app with no purchases needs no financial
      forms — and the agreement it does need arrives already signed.

      **The two banners on that page are not blockers.** *"To offer apps or
      other in-app purchases, you must update your legal entity information
      prior to signing the Paid Apps Agreement"* is conditional on signing that
      agreement, which this app never will. The other was the trader
      declaration, handled in the item below; Business › Compliance now reads
      **Digital Services Act — Active**, which is where that answer lands.
- [x] **(human)** **Answer the EU trader declaration: non-trader.** Done
      2026-08-20 — declared non-trader in App Store Connect. See *The EU trader
      requirement*, which says why a free app with no ads and no purchases
      isn't a trade, and why the seller name is public regardless.
- [x] **(human)** **Claim the name.** **Claimed 2026-08-20**: the app record
      exists as `Boring Tracker`, bundle id `com.novoselov.boringtracker`, and
      the name was accepted without a collision. Re-checked against the App
      Store search API the same day before claiming — 17 results for the phrase
      and none of them this name, the nearest being *Boring Expenses: Spend
      Tracker* and *Boring Order Tracker*. That check only sees published apps,
      never a reservation, so App Store Connect accepting it is the answer and
      the search was only a warning system. Both runners-up were clear too.
      Trademarks were never searched — *Naming and the competitive landscape*
      says so.

### 2. What the app itself has to carry

- [x] **(human)** **Choose the icon.** A mint `+` inside a mint ring on the
      `#1C1C1E` card colour; see *The icon*.
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
- [x] **Green suite, and a project that matches its spec.** Both re-checked
      2026-08-20 after the item 42 changes landed: `xcodebuild test` on the
      iPhone 17 Pro Max simulator reports **313 tests, 313 passed, 0 failed, 0
      skipped**, and `xcodegen generate` rewrites `BoringTracker.xcodeproj` to
      something byte-identical — `git status` sees nothing. Re-run both after
      any further code change, since this is the state the archive is cut from.
      Note `xcodegen` is not on the PATH the tools get; it is
      `/opt/homebrew/bin/xcodegen`.

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

- [x] **(human)** **Name, subtitle, keywords, description.** **Written
      2026-08-21 over the API** and read back field by field: **11 of 11 match
      `docs/APPSTORE.md` exactly** — name, subtitle, privacy policy URL,
      description, keywords, promotional text, support URL, marketing URL,
      copyright, and both categories. Nothing was retyped: the payload is
      parsed out of APPSTORE.md's own fenced blocks, so the listing and the
      page cannot drift. Every length came out at the number that page states —
      14, 26, 94, 123, 1,950. **Category is settled: Health & Fitness primary,
      Utilities secondary**, the recommendation APPSTORE.md made and left open.
      `whatsNew` is the one field that could not be written; see below.
- [x] **(human)** **Screenshots.** Captured 2026-08-20: five 1320x2868 PNGs in
      `docs/screenshots/` — home, log, again, history, graph — which are the
      6.9-inch App Store set and the set the README shows, the same five files
      for both. Shot on the iPhone 17 Pro Max simulator, which emits 1320x2868
      directly, in dark with the app left on its own `System` setting so what is
      photographed is the app following the phone. Each was re-rendered through
      an opaque CoreGraphics context because the simulator writes PNGs *with* an
      alpha channel and the store refuses those; `sips` reads back 1320x2868 and
      `hasAlpha: no` on all five, and a pixel compare across the flatten reports
      0 of 3,785,760 differing. iPad sizes are not needed — the decision above
      is iPhone-only. **What the required set is remains Apple's to state:** the
      sizes change, so read them off App Store Connect on the day rather than
      trusting this line.

      **Uploaded 2026-08-21** over the API, in the order APPSTORE.md fixes, and
      all five read back **`assetDeliveryState: COMPLETE` at 1320x2868 with no
      errors** — Apple processes them asynchronously, so a 200 on the upload is
      not the same as an accepted asset, and this state is the one that answers.
      Two things the API forced: the 6.9-inch set has **no display type of its
      own** and goes into the **`APP_IPHONE_67`** bucket, established by posting
      a deliberately invalid value and reading the accepted enum out of the
      error; and each image is a **three-step reserve, PUT, commit**, where the
      commit carries an **MD5 of the file** that Apple verifies, so a mangled
      upload is refused rather than quietly kept.

      **`home.png` and `again.png` are the item 42 re-shoots**, taken after the
      card `+` became the outlined ring. The other three were checked rather
      than assumed: the log sheet covers the cards entirely, History shows the
      repeat disc, and the graph screen shows a bare nav-bar `+` — all three are
      different controls that item 42 did not touch.
- [x] **(human)** **App Privacy: "Data Not Collected".** **Answered and
      published 2026-08-21.** One question — *do you or your third-party
      partners collect any data from this app* — answered **no**, which ends the
      questionnaire with no data types to categorise. Truthful here, which
      *Before submitting* calls one of the better things about this app. It is
      a claim about the whole app, so it stays true only while rule 5 does.

      **Why no is the confident answer and not the cautious one.** Apple defines
      collection as **transmitting data off the device**; data that only ever
      sits on the phone is not collected under that definition. This app has no
      networking code at all, no third-party SDK, no analytics or crash
      reporting, and asks for no permissions — all of it checked against the
      source and written up in `docs/index.html`. The one that gives people
      pause is **export**: it leaves through the share sheet with the *user*
      choosing the destination, which is the user moving their own data rather
      than the developer collecting it. This is the field people over-declare
      out of caution, and over-declaring here would make a false claim in the
      more damaging direction — it would say the app collects something it does
      not. **Not writable over the API** — see *Filling the listing without the
      web UI*; it has to be answered in the browser and then **published**,
      which is a separate button from saving.
- [x] **(human)** **Age rating questionnaire.** **Written 2026-08-21** over the
      API in one PATCH of 26 attributes, and the resulting rating reads back
      **`FOUR_PLUS`** — the 4+ APPSTORE.md predicted. Thirteen content enums at
      `NONE`, eleven booleans at `false`, `kidsAgeBand` left null. Nothing here
      was contentious except one field.

      **`healthOrWellnessTopics` is `false`, and it is a boolean.** APPSTORE.md
      treated it and `medicalOrTreatmentInformation` as one concern; they are
      different types, which is easy to get backwards because App Store Connect
      asks them as neighbouring questions. The judgement: *topics* means content
      the app presents — articles, advice, interpretation — and this app
      presents none. It stores numbers the user typed and draws them on a graph,
      and having no opinion about them is the product. That a tracker is named
      "Calories" is the user's label, not shipped content. The alternative was
      cheap — `true` buys 9+ instead of 4+ and changes nothing else — and if
      Apple disagrees it normally adjusts the rating rather than rejecting.
      `medicalOrTreatmentInformation` is `NONE` on the same reasoning.

      **The two override fields are mutually exclusive.** Setting
      `ageRatingOverride` and `ageRatingOverrideV2` in one request is refused
      with `STATE_ERROR.AGE_RATING_OVERRIDE_V1_AND_V2_NOT_ALLOWED`. They are the
      pre- and post-overhaul versions of one field: V1 still offers
      `SEVENTEEN_PLUS`, V2 offers `EIGHTEEN_PLUS` instead, which is the July 2025
      change visible in the data. Write V2 only.
- [x] **(human)** **Price: free**, with no in-app purchases. **Set 2026-08-21**
      over the API and read back: a price schedule with base territory USA and a
      manual price of **0.0**. Rule 1, and also what keeps the non-trader case
      above intact. Two things worth knowing if this is ever redone: free is an
      ordinary **price point** rather than a flag or the absence of a schedule,
      and its `customerPrice` is the string **`0.0`, not `0.00`** — filtering
      for the latter returns nothing and reads exactly like the app is not
      allowed to be free.
- [ ] **Encryption, again.** The Info.plist key is what stops the question
      being asked per upload. Whether the first submission still asks it once
      in the web form is **unverified**.

### 5b. Two the checklist missed

Neither was in the list assembled 2026-08-19, and both are required before the
submit button does anything. Found 2026-08-21 by reading the live record rather
than the form.

- [x] **Content rights declaration.** `contentRightsDeclaration` was `null` and
      is now **`DOES_NOT_USE_THIRD_PARTY_CONTENT`** — the app is its own code
      plus Apple's own frameworks and SF Symbols. It sits on **App Information**
      in the web UI, not on the version page. The only other accepted value is
      `USES_THIRD_PARTY_CONTENT`.
- [x] **App review information.** The record did not exist at all — the
      relationship returned `data: null` — and now carries a contact name, phone
      and email, `demoAccountRequired: false` (there is no login to demo), and a
      note. **The phone number is deliberately not written down here**, for the
      same reason as the legal-entity address: this repository is public.

      The note is the cheap half of the *Guideline 4.2* answer that
      *One review risk to be aware of* argues for. It does not plead the
      philosophy; it tells the reviewer where the functionality is — log with
      the `+`, History behind the clock icon, a graph behind a tracker row, add
      and export from Settings — and states that there is no sign-in, so nothing
      is gated. Showing what exists is the whole strategy that section settles
      on.

**A 200 is not proof the value stuck, and neither is the read after it.** The
content rights PATCH returned 200 and then read back `null` from an unfiltered
`GET /v1/apps/{id}`, which looks exactly like a silent failure. It was not: the
same field read with `?fields[apps]=contentRightsDeclaration` returned the value
correctly. The unfiltered representation is served stale right after a write.
So verify with a field-filtered read, and do not re-send a write on the strength
of a null that a broad GET reported.

### 6. Submitting

- [ ] **(human)** **Submit for review**, and expect *Guideline 4.2, Minimum
      Functionality* to be the one real risk — see *One review risk to be
      aware of*. The answer is to show the functionality that exists, not to
      add features.

### 7. After the first release

Things that cannot be done before there is an App Store id, recorded here so
they are not lost the moment there is one.

- [ ] **The "leave a review" link on the About screen.** It deliberately ships
      without one: the URL needs the numeric App Store id — see `017267c`.
      **The id exists: `6803768789`**, read off the API on 2026-08-20, and it
      arrived with the app record rather than with the release. So this is no
      longer blocked and no longer belongs in "after the first release"; it can
      go into 1.0 if it is wanted there. What was never checked is whether the
      review sheet does anything useful before the app is actually on sale.
