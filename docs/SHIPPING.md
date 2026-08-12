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

## The EU trader requirement

Under the Digital Services Act, Apple requires developers distributing in the
EU to declare **trader status**. This is not optional — apps whose developers
didn't declare have been removed from EU storefronts.

- Declaring **trader** means Apple publicly displays your name, address, phone
  number, and email on the listing in EU storefronts. For an individual, that
  can mean a home address.
- A genuinely free, non-commercial app with no ads and no purchases is a
  reasonable **non-trader** case, which avoids publishing contact details.
- Any monetization at all — paid app, in-app purchase, ads — makes you a
  trader.

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
  need to be unique; currently `Whatever`, which is fine even though an
  unrelated app owns that App Store name.
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

## Before submitting

Things that are easier handled early than discovered at submission:

- **Encryption export compliance.** The app uses no encryption, so set
  `ITSAppUsesNonExemptEncryption` to `NO` in Info.plist and App Store Connect
  stops asking on every build.
- **Privacy label: "Data Not Collected."** Genuinely true here, and one of the
  better things about this app. Keep it true.
- **Privacy policy URL is required** for every app, even one that collects
  nothing. A short page stating that the app collects no data, has no servers,
  and stores everything on the device. GitHub Pages is fine.
- **Support URL is required.** The GitHub repository works.
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
