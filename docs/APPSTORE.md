# App Store submission

Everything the listing needs, in the fields App Store Connect asks for, so it
can be copied straight out of here. The reasoning behind the name, the icon,
the account and the review risk is in [SHIPPING.md](SHIPPING.md); this page is
the text.

**Verified and unverified are marked throughout.** Apple moves these rules, and
a confident wrong number here costs a rejected submission. Anything checked
against Apple's own documentation on 2026-08-20 says so; anything taken from
common knowledge says *unverified* instead.

## Before you paste any of this

- [x] **Screenshots exist** at the size in *Assets* below — five of them, in
      `docs/screenshots/`, captured 2026-08-20.
- [x] **Re-check the name is still unclaimed.** Re-checked 2026-08-20 against
      the App Store search API, then **claimed** — the app record exists and
      App Store Connect accepted the name.
- [x] **The text fields are written.** Done 2026-08-21 over the API, read back
      and matching this page exactly. What is left by hand is App Privacy, the
      age rating, the price and the build.

## The fields

### Name

```
Boring Tracker
```

30 characters maximum, **verified** against Apple's App Store Connect help
(*App information*, which gives the name as 2–30 characters). Used: 14. This
is the listing name and must be unique; the home screen label is the same
string, set separately in `project.yml`, and does not have to be unique.

### Subtitle

```
Calories, weight, anything
```

30 characters maximum, **verified** in the same place. Used: 26.

The subtitle carries search terms because the name does not — nobody searches
for "boring tracker". That is the strategy in SHIPPING.md, *Listing strategy*.

### Keywords

```
macro,protein,carbs,food,diary,habit,water,log,counter,free,no ads,open source,offline,private
```

100 characters, **unverified** — Apple's public help pages do not state the
limit and it was not confirmed. Used: 94, counted, leaving headroom against a
number that is itself unverified. Check it in App Store Connect, which rejects
an over-length field rather than truncating it.

*tally* was in this list and came out. The tally-shaped names are crowded with
counter apps, and being mistaken for a tally counter is the wrong association —
no point buying it with a keyword.

Comma-separated with no spaces after the commas, because spaces count. Nothing
here repeats the name or the subtitle — *calorie*, *weight* and *tracker* are
already indexed from those two fields, so spending keyword characters on them
again buys nothing.

### Promotional text

```
Free, no ads, no account, no subscription, no server. Type a number, done.
Open source, and everything stays on your phone.
```

170 characters, **unverified** — same as keywords, not confirmed from Apple.
Used: 123, counted.

This is the field that can be changed without submitting a new build, so it is
the one to edit if something needs saying between releases.

### Description

4,000 characters, **unverified** limit. The text below is 1,950 characters,
counted.

```
Boring Tracker is an iPhone app for writing down numbers.

Free, open source, no ads, no accounts, no subscription, no server, no feature bloat. Type a number, done.

Most other macro trackers want you to scan a barcode for every ingredient of a dish you cooked yourself. It takes a lot of time for no benefit. This one just lets you write down "600 calories, 40 protein" and done, as fast as possible, minimum clicks, minimum wait/lag.

You can also use it to track anything you want: your cat's weight, pushups, blood glucose, the last time you changed a filter.

A tracker is either a daily total, which adds entries up over the day and starts again at the day boundary, or a measurement, which is a standalone reading. Trackers you log at the same time share a group, so one sheet takes both numbers at once.

The + opens whatever you logged last, with the number pad already up. You can name what you logged — the food, not the tracker — and then log it again later with one tap. The time defaults to now and is tappable, so you can log dinner the next morning.

History holds everything you have logged, grouped by day and searchable by name. Graphs draw daily totals as bars and measurements as a line with a moving average, over a week, a month, a year, or all of it. Export the lot as JSON or CSV, and import it back.

What it does not do: no ads, no subscription, no pro tier, no account, no server, no analytics, no streaks, no badges, no notifications.

The app collects no data. It contains no networking code at all, so nothing you type into it can leave your phone by itself, and it asks for no permissions — not the camera, not your health data, not notifications.

The whole app is open source under the MIT licence. You can read it, build it, or ship your own:
https://github.com/novoselov-ab/boring-tracker

My goal with it is to behave like a built-in iOS app (e.g. the calculator). It is boring, but does its job, hence the name.
```

The paragraph about what it does not do is one compact line rather than a
screen of bullets on purpose. It is the part that is both true and rare — see
*Listing strategy* in SHIPPING.md — and a list of nine absences set as nine
bullets reads as a feature grid, which is the thing this app is not.

### What's new in 1.0

```
First release.
```

**Settled 2026-08-21, and the answer is that 1.0 cannot have one.** A PATCH
carrying `whatsNew` is refused with **409 STATE_ERROR — *Attribute 'whatsNew'
cannot be edited at this time***, and the field reads back `null` on the live
1.0 record. So the question was not whether the field is required but whether
it is writable: there is no previous release to describe, and App Store Connect
will not take one. The line above is kept for the first update that does need
it. Note the refusal takes the whole request with it — the same PATCH's
description and keywords were not written either; see *Filling the listing
without the web UI* in SHIPPING.md.

### URLs

| Field | Value | Status |
|---|---|---|
| Support URL | `https://github.com/novoselov-ab/boring-tracker` | live, public since 2026-08-19 |
| Marketing URL | `https://novoselov-ab.github.io/boring-tracker/` | live |
| Privacy policy URL | `https://novoselov-ab.github.io/boring-tracker/` | live |

Marketing and privacy policy are the same page: `docs/index.html` is both the
website and the policy, and the policy is the second half of it. The heading
carries `id="privacy"`, so
`https://novoselov-ab.github.io/boring-tracker/#privacy` lands on it directly
if App Store Connect ever wants a URL that does.

Support URL is the repository, with issues as the contact route — which is
what the privacy page already tells people to use.

### Category

**Primary: Health & Fitness. Secondary: Utilities.** **Decided 2026-08-21**,
and written to the app record — this was the recommendation and Anton took it.

The reasoning it was chosen on, kept because the 4.2 risk below turns on it.
Health &
Fitness is where the apps this one is a reaction to live, and where somebody
looking for a macro tracker searches. Utilities is the honest description of an
app that writes down numbers and has no opinion about them, but almost nobody
browses it for this.

One thing to weigh: Health & Fitness is the category that draws the wellness
questions in the age-rating questionnaire below, and a reviewer in that
category is more likely to expect health features the app deliberately does not
have. That is the *Guideline 4.2* risk SHIPPING.md already records, and the
answer there is the same — show what exists, do not add features.

### Age rating

**Expect 4+, but answer the questionnaire rather than assuming it.**

**Verified** on 2026-08-20 against Apple's age-ratings reference: the tiers are
now **4+, 9+, 13+, 16+ and 18+**. 12+ and 17+ were removed in the July 2025
overhaul, and the questionnaire gained mandatory questions covering in-app
controls, app capabilities, medical or wellness content, and violent themes.

The one to read carefully is **medical or wellness content**: Apple's own
definition puts "health/wellness topics" at **9+**, and this app records
calories and weight. Whether writing a number down counts as wellness content
is a judgement the questionnaire will ask you to make. Nothing else in the app
is contentious — no ads, no user content, no messaging, no web view, no
purchases.

### Copyright

```
2026 Anton Novoselov
```

The App Store copyright field takes the year and the holder, without a `©` —
App Store Connect adds the symbol. **Unverified** that it still does; if the
field shows a bare year and name in the preview, it worked.

### Price and availability

Free, with no in-app purchases. Rule 1 of
[PHILOSOPHY.md](PHILOSOPHY.md), and it is also what keeps the EU non-trader
declaration in SHIPPING.md intact.

## App Privacy — the nutrition label

**Answer: Data Not Collected.** Truthfully, and this is the whole answer — the
questionnaire ends there, with no data types to categorise and no third-party
partners to declare.

**This one has to be typed into the web UI.** It is the only part of the
listing the App Store Connect API does not expose — see *Filling the listing
without the web UI* in SHIPPING.md, which records the three 404s that establish
it.

What it rests on, all of it checked against the source and written up in
`docs/index.html`:

- No networking code anywhere in `BoringTracker/`. The app makes no request to
  anyone.
- No third-party SDKs, packages or dependencies. Apple's frameworks only.
- No analytics and no crash reporting.
- No system permissions requested — no camera, photo library, contacts,
  location, HealthKit or notifications.
- Everything is stored in the app's own container: `store.json` plus a backup,
  and three interface preferences.
- Export leaves only through the share sheet, where the user picks the
  destination.

**This stays true only while rule 5 does.** Adding any SDK that phones home
changes this answer, and the answer is a public claim.

## Assets

### Icon

`BoringTracker/Resources/Assets.xcassets/AppIcon.appiconset/boring-tracker-1024.png`

One 1024×1024 square and nothing else — Xcode derives every smaller size. It
is flat, opaque and un-rounded, which is what the App Store requires: an alpha
channel is rejected, and iOS applies the rounded mask itself. App Store Connect
takes the icon from the uploaded build, so there is nothing to attach by hand.

### Screenshots

Five, in `docs/screenshots/`: `home.png`, `log.png`, `again.png`,
`history.png`, `graph.png`. Upload them in that order — it is the order a
stranger should meet the app in, and the first one is the one most people see.

Required set, **verified** on 2026-08-20 against Apple's *Screenshot
specifications* page in the App Store Connect help:

- **6.9-inch iPhone display, portrait.** Accepted pixel sizes are
  **1320 × 2868**, **1290 × 2796**, or **1260 × 2736**. This is the only size
  that has to be provided: Apple scales it down for the smaller display
  classes, and 6.5-inch is required only as a substitute if no 6.9-inch set is
  given.
- **1 to 10 per display size**, `.png`, `.jpg` or `.jpeg`, and **no alpha
  channel or transparency**.
- **No iPad sizes.** The app is iPhone-only — `TARGETED_DEVICE_FAMILY` is `1`
  in `project.yml` — so the iPad set is not asked for.

Apple changes these. Read them off App Store Connect on the day rather than
trusting this list, and note that the parser is exact: a screenshot one pixel
off the accepted size is refused rather than scaled.

The **iPhone 17 Pro Max** simulator produces the 6.9-inch size directly, so a
set can be captured without a device. Measured on 2026-08-20: a screenshot off
that simulator is **1320 × 2868**, which is the first accepted size above, with
no scaling or cropping needed.

```sh
xcrun simctl boot 'iPhone 17 Pro Max'
xcrun simctl io booted screenshot home.png
sips -g pixelWidth -g pixelHeight home.png   # expect 1320 x 2868
```

What they show, and it is also what answers *Guideline 4.2* by showing the
functionality that exists: **home** with eight trackers covering all three
kinds, **the log sheet** with the number pad up, **log again**, **history**,
and **a weight graph** over a year. The README shows the same five files, so
there is one set to keep current rather than two.

Captured 2026-08-20 on the iPhone 17 Pro Max simulator, dark appearance set on
the device with the app left on its own System setting. All five measured at
**1320 × 2868 with no alpha channel** — `simctl io screenshot` writes an alpha
channel, so each was re-rendered through an opaque context and checked with
`sips` per file. The data in them is invented: eight trackers and 1,967 entries
over 151 days, written straight into `store.json` in the simulator's container.
