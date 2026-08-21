# Shipping

Everything about Apple accounts, costs and App Store submission, written for
whoever ships their own build of this — rule 8 says you can.

Apple changes these rules regularly. Treat this as a map, not a contract, and
re-check anything consequential at the time you do it. Boring Tracker 1.0 went
for review on 2026-08-21, and the checklist at the bottom records what each
answer actually was.

## What costs money, and when

- **Simulator builds need no account at all.** This covers nearly all
  development, and this repository is configured for it — no signing, no team.
- **Running on your own iPhone needs only a free Apple ID** (Xcode calls it a
  personal team). The profile expires after **7 days**, so the app stops
  launching until you rebuild from Xcode. Free accounts also cannot use App
  Groups, iCloud or push notifications.
- **The Apple Developer Program is $99/year**, and in the order these bite it
  becomes necessary for: daily use on your own phone (the 7-day expiry is what
  makes a free account impractical, and it arrives before shipping does),
  widgets, sync, TestFlight, and the App Store.

Enrol as an **individual**, not an organization: organization enrollment
requires a D-U-N-S number and takes considerably longer, for benefits this
project doesn't need. Individual enrollment publishes under **your legal name**
as the seller. No fee waiver applies — those exist for nonprofits, education and
government, not for free open-source apps by individuals.

**If the membership lapses**, Apple removes your apps from the App Store — not
hidden, unavailable. Apps already installed keep working, TestFlight builds stop
immediately, and re-downloading a removed app from purchase history is
unreliable. Renewing restores things, and Apple warns repeatedly before expiry.
The real mitigation is that this project is open source and stores data in a
plain file: if it is ever abandoned, existing installs keep working, data
exports, and anyone can fork and ship it. Paid competitors cannot say that.

## The EU trader requirement — declaring non-trader

Under the Digital Services Act, Apple requires developers distributing in the EU
to declare **trader status**. This is not optional — apps whose developers didn't
declare have been removed from EU storefronts. The answer here is "non-trader",
not silence.

- Declaring **trader** means Apple publicly displays your name, address, phone
  number and email on the listing in EU storefronts. For an individual, that can
  mean a home address.
- **Non-trader** publishes no contact details. A trader acts for purposes
  relating to their trade, business, craft or profession, and this app has no
  price, no in-app purchases, no ads, no subscription and collects no data to
  monetize. There is no commercial purpose to point at.
- **The seller name is a separate question with no choice in it.** An individual
  account publishes under the developer's legal name whichever way the trader
  question is answered. That part is accepted.
- Any monetization at all — paid app, in-app purchase, ads, even a tip jar —
  would likely make this a trade, and with it the address becomes public. One
  more thing rule 1 in PHILOSOPHY.md is quietly buying.

**This policy has shifted more than once, so verify it at enrollment rather than
trusting this page.** If you do end up classed as a trader, the usual answer is a
virtual office or mailbox address rather than your home. Checked on the day and
declared non-trader on 2026-08-20: App Store Connect raised it itself as a
blocking banner, and the definition it put in front of the choice was the DSA's
own — the same one this section argues against.

## The name, and the three names

Three different names are involved and **only one has to be unique**:

- **App Store listing name** — unique, claimed first-come, 30 characters. It is
  `Boring Tracker`.
- **`CFBundleDisplayName`** — the label under the home screen icon. Does *not*
  need to be unique. It is `Boring Tracker` too, set in `project.yml` as
  `INFOPLIST_KEY_CFBundleDisplayName`.
- **Bundle identifier** — `com.novoselov.boringtracker`, permanent. Changing it
  makes it a different app that existing users won't get updates for.

**The home screen label is the string Spotlight matches, and it does not truncate
at some character count.** iOS truncates on rendered width: all 14 characters of
`Boring Tracker` fit with no ellipsis on an iPhone 17 and on a 375pt SE, the
narrowest phone this app supports, which fits the two words by condensing them
about 20% (74.5pt against 89pt, measured separately). The short label cost every
search: with `Boring`, typing "tracker" did not find the app at all — checked
twice from a clean uninstall with a 25s settle, and "boring" as a same-minute
control that was found both times. With the full name both words return it as Top
Hit. **The trap:** before first launch the new-app dot steals label width and the
home screen renders `BoringTracker` or `Boring T…`, which looks exactly like the
truncation this used to be blamed on. Launch once, then judge.

Not checked: **trademarks**. App Store availability isn't clearance to use a
name. A USPTO search is cheap insurance before printing it anywhere, though a
phrase this generic is unlikely to be contested.

### Listing strategy

Nobody searches for "boring tracker", and that's fine — App Store discovery comes
from the subtitle and the hidden keywords field, not the name. So the name can be
distinctive while those carry the search terms. The exact text is in
[APPSTORE.md](APPSTORE.md).

Lead the description with what's *absent* — no ads, no subscription, no account,
no data collection — because that's the part that is both true and rare.
**Simplicity is not the differentiator:** the leading "simple" trackers have
millions of users and monetize anyway, one of them selling a subscription while
its own description attacks "cluttered dashboards, screen-hijacking ads". The gap
is that nobody credible is genuinely free, which is the one thing a
venture-funded competitor cannot copy without breaking its own business. The name
does useful work here too: leaning into "boring" makes the absence of streaks,
badges and nagging read as intent rather than as missing features.

## The icon

**A mint `+` inside a mint ring on a dark field.** It lives in the asset catalog
as `AppIcon.appiconset`, one 1024 square and nothing else — Xcode derives every
smaller size. `.gitignore` refuses `*.png` but makes
`**/Assets.xcassets/**/*.png` the exception, so that one copy is tracked.

Field `#1C1C1E`, mark `#00DAC3`. Both are the app's own values: the field is the
card colour, the surface the `+` buttons sit on, and the mark is `AccentFill` in
dark, the colour the app draws the card `+` in — so the icon matches the thing it
depicts in shape *and* in colour. **In dark.** One file ships for both
appearances, so in light the app's `+` goes `#009888` and the icon does not
follow; matching there was never on the table. Contrast against the field
measures **9.57:1**, sampled as the 1024's own two modal colours rather than
computed from the hex values. The mark is drawn with Core Graphics rather than
repaired by hand — ring outer radius 350.5px with a 47px stroke, plus a bar 49px
thick with round caps, centred on 512.

### What any icon here has to be

- **Full bleed and opaque.** One 1024×1024 square, sRGB, PNG colour type 2, no
  alpha and no `tRNS`. The App Store rejects an alpha channel outright.
- **No corners baked in.** iOS applies its own superellipse, so a pre-rounded
  icon gets rounded twice. Watch for this in supplied artwork: this mark arrived
  with a rounded-rect mask already applied — corners `#000000` against a `#100F10`
  field — and because that mask is anti-aliased, swapping exact black alone would
  have left a grey halo tracing the old curve. The check that catches both traps
  is a diagonal from each corner inward: it must read one value all the way in to
  the mark.
- **Designed at 40pt.** Spotlight, Settings and notifications are where most
  people will ever see it, and a detail that does not survive 120×120 pixels does
  not exist.
- **Judged installed, not in a preview.** Build it, put it on the simulator, and
  look at the home screen, the Settings app list and Spotlight in both
  appearances. iOS 26 renders the mark with a glass treatment of its own — a
  highlight, a shadow and a dimmer mint than the file contains — which no 1024
  preview shows. A wide gradient across the field suppresses that treatment; a
  flat or nearly flat field gets it.
- **A dark field costs a silhouette.** A background keeps its silhouette against
  *both* home screens only if it is mid-luminance: near-white disappears on a
  light one, near-black on a dark one. `#1C1C1E` against a black wallpaper is the
  second case, chosen with that known and accepted — the mark carries the icon,
  not the field — but the lever on it is background luminance, not the mark.

## Before submitting

- **Encryption export compliance.** The app uses no encryption, so
  `ITSAppUsesNonExemptEncryption` is `NO` — set as
  `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` in `project.yml`. That key does
  the whole job: the uploaded build reads `usesNonExemptEncryption: false`
  straight off the API and the question never appears in the web form, including
  on a first submission.
- **Privacy policy URL is required** for every app, even one that collects
  nothing. Here it is `docs/index.html`, served by GitHub Pages from `main`,
  folder `/docs`. `docs/.nojekyll` is what stops the rest of `docs/` being
  rendered as web pages; they are still served as files, and a branch-folder
  deploy gives no way not to.
- **Support URL is required.** A public GitHub repository works.
- **Privacy label: "Data Not Collected."** Genuinely true here, and one of the
  better things about this app. Keep it true.
- **Screenshots** for the currently required iPhone display sizes — read them off
  App Store Connect on the day, since they change — plus iPad sizes if the app is
  ever listed as supporting iPad.
- **Age rating** questionnaire. Nothing here is contentious; see APPSTORE.md.

### One review risk to be aware of

Guideline 4.2, *Minimum Functionality*, lets Apple reject apps it considers too
simple. This app is deliberately minimal, which is the point, but that's not a
defense the reviewer knows about. If it comes up, the answer is to show the real
functionality — multiple tracker types, history, graphs, export/import — rather
than to add features. **Do not compromise the philosophy to pass review.** The
cheap half of that answer is the app review note, which tells the reviewer where
each thing is and that there is no sign-in gating any of it.

## Licensing and the App Store

**MIT is the right choice and GPL would not be.** GPLv3 conflicts with Apple's
distribution terms, and GPL-licensed apps have been pulled from the App Store
over it. MIT has no such problem, and it lets anyone fork and ship their own
version — which is the whole safety net described above. Being open source
creates no conflict with App Store distribution, and linking the repository from
the App Store description is worth doing: for the people who care about this
app's promises, the source is the proof.

## Filling the listing without the web UI

Nearly all of the listing can be written over the **App Store Connect API**
rather than typed into forms. Established 2026-08-20 by probing the live app
record, not from documentation — every row below was either read back with a 200
or refused with a 404.

**The credential.** A `.p8` key generated in App Store Connect › Users and
Access › Integrations, role **App Manager**. It downloads exactly once and cannot
be re-fetched — losing it means revoking and generating another. It lives at
`~/.appstoreconnect/`, mode 600, **outside the repository**, and the Key ID and
Issuer ID are deliberately not written down here: this repo is public, and the
three together are the whole credential. The key can price, submit and release
the app, so it is not a config value.

Auth is a JWT signed ES256, `aud` of `appstoreconnect-v1`, twenty-minute expiry.
Two things bit on a Mac with nothing installed and would bite again on a fresh
clone: the system `python3` is a **3.6 framework build with no CA bundle**, so
`urllib` fails the TLS handshake against Apple and the transport has to be
`curl`; and neither PyJWT nor `cryptography` is installed, so the signature comes
out of `openssl dgst -sha256 -sign` as **DER** and has to be unpacked into the
raw `r||s` pair a JWS wants.

| Field | Route | Checked |
|---|---|---|
| Name, subtitle, privacy policy URL | `appInfoLocalizations` | written, read back |
| Description, keywords, promo text, what's new, marketing + support URL | `appStoreVersionLocalizations` | written, read back |
| Categories | `appInfos` relationships | written, read back |
| Content rights declaration | `appInfos` | written, read back |
| Screenshots | `appScreenshotSets` → reserve, PUT, commit | written, read back |
| Price: free | `appPriceSchedule` | written, read back |
| Age rating | `appInfos/{id}/ageRatingDeclaration` | written, read back |
| App review information | `appStoreVersions` relationship | written, read back |
| Submit for review | `reviewSubmissions` | exercised |
| Build upload | not the API — `xcrun altool --upload-app`, same key | — |
| **App Privacy — the nutrition label** | **nothing** | **404** |

**App Privacy has to be answered in the web UI.** There is no relationship for it
on the app resource — the record carries 41 relationships and not one of them is
data usage — and `/v1/appDataUsages`, `/v1/appDataUsageCategories` and
`/v1/appDataUsagesPublishState` each return `PATH_ERROR`. Saving it is also not
publishing it; that is a separate button.

**A PATCH is atomic, and one bad attribute loses the whole call.** Writing the
version localization with `whatsNew` in it returned **409 STATE_ERROR,
*Attribute 'whatsNew' cannot be edited at this time*** — and the description,
keywords, promotional text and both URLs in the same request were not written
either. Nothing partial, nothing reported per field. **A 200 is not proof the
value stuck, and neither is the read after it:** the content rights PATCH
returned 200 and then read back `null` from an unfiltered `GET /v1/apps/{id}`,
while the same field read with `?fields[apps]=contentRightsDeclaration` returned
it correctly — the unfiltered representation is served stale right after a write.
So verify with a field-filtered read, and do not re-send a write on the strength
of a null a broad GET reported. The API is not reliably one-shot either; one
write died on `curl: (56) Connection reset by peer` and the retry was clean.

Two enums that cost a probe each: the **6.9-inch screenshot set has no display
type of its own** and goes into the `APP_IPHONE_67` bucket, and each image is a
three-step **reserve, PUT, commit** where the commit carries an **MD5** Apple
verifies. Screenshots also process asynchronously, so a 200 on the upload is not
an accepted asset — `assetDeliveryState: COMPLETE` is the state that answers.

**Browser automation was considered and rejected.** Two-factor auth, session
cookies that expire, and a JavaScript app that rearranges its own DOM, against a
documented and stable REST API.

### Signing, when the API key cannot use cloud signing

`xcodebuild -exportArchive` with `signingStyle: automatic` fails with **`Cloud
signing permission error`** and **`No profiles for '<bundle id>' were found`**,
even though the same API key reads `/v1/certificates` and `/v1/bundleIds`
happily. The two are not the same permission: **cloud signing is the arrangement
where Apple generates and holds the private key**, and an App Manager key is not
allowed to ask for it. Creating a certificate from a CSR *is* allowed —
established by POSTing a deliberately malformed CSR and getting back a complaint
about the CSR rather than a 403.

So the working route generates the key locally and never asks Apple for one:

1. `openssl genrsa` a 2048-bit key, then a CSR against it.
2. `POST /v1/certificates` with `certificateType: DISTRIBUTION` and that CSR.
   `certificateContent` comes back as base64 DER.
3. `POST /v1/profiles` with `profileType: IOS_APP_STORE`, the bundle id record
   and that certificate. Write the decoded `profileContent` to
   `~/Library/MobileDevice/Provisioning Profiles/<uuid>.mobileprovision`.
4. Import the certificate and key so `codesign` can reach them, then export with
   **`signingStyle: manual`**, naming the certificate and profile explicitly.

**The private key never leaves the machine**, which is the part worth keeping: it
is also the arrangement that survives losing access to the account.

**Step 4 needs its own keychain, not `login.keychain`.** Making a key usable by
`codesign` without a GUI prompt needs `security set-key-partition-list`, which
wants the keychain's password — and for the login keychain that is the user's
macOS account password. A keychain created for the purpose has a password the
script already knows; `security list-keychains -d user -s` then prepends it to
the search list, keeping what was there. Note the archive itself is signed *Apple
Development* and `-exportArchive` re-signs it with the distribution certificate,
so that is not a problem to chase.

## The checklist

The order things have to happen in, and what 1.0 actually answered. **(human)**
marks a step no automated session can do: it needs an account, a payment, or a
judgement that cannot be walked back after release.

### 1. Before anything can be uploaded

- [x] **(human)** **Enrol in the Apple Developer Program**, as an individual.
      Submitted and **approved 2026-08-20** — one day, including the identity
      check. That is the gate everything else waits on.
- [x] **(human)** **Accept the agreements App Store Connect asks for.** Nothing
      had to be accepted by hand: the **Free Apps Agreement** was already
      *Active* on the day enrollment was approved. The **Paid Apps Agreement**
      stays at *New* — it is the only one that wants tax and banking details, and
      a free app with no purchases is never asked for them. Its banner is
      conditional on signing that agreement and is not a blocker.
- [x] **(human)** **Answer the EU trader declaration: non-trader.** Done
      2026-08-20; Business › Compliance reads *Digital Services Act — Active*.
- [x] **(human)** **Claim the name.** Claimed 2026-08-20 as `Boring Tracker`,
      accepted without a collision. The App Store search API only sees published
      apps and never a reservation, so App Store Connect accepting the name is
      the answer and a search beforehand is only a warning system.

### 2. What the app itself has to carry

- [x] **(human)** **Choose the icon**, and point the build at it.
      `ASSETCATALOG_COMPILER_APPICON_NAME` is `AppIcon`; verified flat, opaque
      and un-rounded, and seen installed in both appearances.
- [x] **Encryption declaration.** `ITSAppUsesNonExemptEncryption` is `NO`.
- [x] **Version numbers.** `MARKETING_VERSION` is `1.0`.
      `CURRENT_PROJECT_VERSION` is a bare counter: **add one for every upload App
      Store Connect accepts**, including a re-upload after a rejection.
- [x] **(human)** **iPhone app or universal?** **iPhone only**, decided
      2026-08-20. `TARGETED_DEVICE_FAMILY` is `"1"`, set explicitly rather than
      left to XcodeGen's `"1,2"` default. That buys one screenshot set, no iPad
      review pass and no Split View question — an iPad-family app that cannot do
      Split View has historically been rejected for it. Adding iPad later is an
      ordinary update; removing it after release would strand whoever installed
      it there, which is why this had to be settled before the first submission.
- [x] **Make the repository public**, under the MIT license. The support URL is
      the repository, and rule 8 is one of the promises the listing is built on.
- [x] **Green suite, and a project that matches its spec.** `xcodebuild test`
      passes and `xcodegen generate` rewrites the `.xcodeproj` to something
      byte-identical. Re-run both after any code change: this is the state the
      archive is cut from. Note `xcodegen` is not on the PATH tools get; it is
      `/opt/homebrew/bin/xcodegen`.

### 3. Two pages that have to exist on the web

- [x] **Privacy policy URL** — `https://novoselov-ab.github.io/boring-tracker/`.
      Everything it states was checked against the source rather than written
      from the philosophy: no networking API appears anywhere in `BoringTracker/`,
      there are no third-party packages, and no permission-requiring framework is
      imported. One static file, nothing fetched from anywhere — an analytics tag
      on the privacy page of an app whose claim is *collects nothing* would undo
      the claim it is there to make.
- [x] **Support URL** — `https://github.com/novoselov-ab/boring-tracker`.

### 4. The build

- [x] **(human)** **Archive with the paid team and upload.** Done 2026-08-21:
      `xcodebuild archive` then `-exportArchive` with `destination: upload`.
      **Build 1 is attached to version 1.0 and reads `VALID`**, having gone
      `PROCESSING` → `VALID` in about 90 seconds. The signing this needs is its
      own section above; the automatic path fails on this account.

### 5. The listing

- [x] **(human)** **Name, subtitle, keywords, description.** Written 2026-08-21
      over the API and read back field by field: **11 of 11 match APPSTORE.md
      exactly.** Nothing was retyped — the payload is parsed out of APPSTORE.md's
      own fenced blocks, so the listing and the page cannot drift. **Category:
      Health & Fitness primary, Utilities secondary.** `whatsNew` is the one
      field that could not be written, and 1.0 cannot have one.
- [x] **(human)** **Screenshots.** Five 1320×2868 PNGs in `docs/screenshots/`,
      shot on the iPhone 17 Pro Max simulator in dark with the app left on its
      own `System` setting, so what is photographed is the app following the
      phone. The same five files are the App Store set and the README's. Each was
      re-rendered through an opaque CoreGraphics context because **the simulator
      writes PNGs with an alpha channel and the store refuses those**; a pixel
      compare across the flatten reports 0 of 3,785,760 differing.
- [x] **(human)** **App Privacy: "Data Not Collected".** Answered and published
      2026-08-21. One question — *do you or your third-party partners collect any
      data from this app* — answered **no**, which ends the questionnaire.

      **Why no is the confident answer and not the cautious one.** Apple defines
      collection as **transmitting data off the device**; data that only ever
      sits on the phone is not collected under that definition. This app has no
      networking code at all, no third-party SDK, no analytics or crash
      reporting, and asks for no permissions. The one that gives people pause is
      **export**: it leaves through the share sheet with the *user* choosing the
      destination, which is the user moving their own data rather than the
      developer collecting it. This is the field people over-declare out of
      caution, and over-declaring here would make a false claim in the more
      damaging direction — it would say the app collects something it does not.
- [x] **(human)** **Age rating questionnaire.** Written 2026-08-21 in one PATCH
      of 26 attributes; the rating reads back **`FOUR_PLUS`**. Thirteen content
      enums at `NONE`, eleven booleans at `false`, `kidsAgeBand` null.

      **`healthOrWellnessTopics` is `false`, and it is a boolean** —
      `medicalOrTreatmentInformation` is an enum at `NONE`. They are different
      types, which is easy to get backwards because App Store Connect asks them
      as neighbouring questions. The judgement: *topics* means content the app
      presents — articles, advice, interpretation — and this app presents none.
      It stores numbers the user typed and draws them on a graph, and having no
      opinion about them is the product. That a tracker is named "Calories" is
      the user's label, not shipped content. The alternative was cheap — `true`
      buys 9+ instead of 4+ and changes nothing else — and if Apple disagrees it
      normally adjusts the rating rather than rejecting.

      The two override fields are **mutually exclusive**: setting
      `ageRatingOverride` and `ageRatingOverrideV2` in one request is refused
      with `AGE_RATING_OVERRIDE_V1_AND_V2_NOT_ALLOWED`. Write V2 only.
- [x] **(human)** **Price: free**, with no in-app purchases. Set 2026-08-21 and
      read back: base territory USA, manual price **0.0**. Rule 1, and also what
      keeps the non-trader case above intact. Free is an ordinary **price point**
      rather than a flag or the absence of a schedule, and its `customerPrice` is
      the string **`0.0`, not `0.00`** — filtering for the latter returns nothing
      and reads exactly like the app is not allowed to be free.
- [x] **Content rights declaration.** `DOES_NOT_USE_THIRD_PARTY_CONTENT` — the
      app is its own code plus Apple's frameworks and SF Symbols. It sits on
      **App Information** in the web UI, not on the version page, and it was not
      in the checklist until the live record was read rather than the form.
- [x] **App review information.** A contact name, phone and email,
      `demoAccountRequired: false`, and a note. The record did not exist at all
      until it was written. **The phone number is deliberately not written down
      here**, because this repository is public.

### 6. Submitting

- [x] **(human)** **Submit for review.** Submitted **2026-08-21 16:30:51 UTC**,
      version 1.0 with build 1, state `WAITING_FOR_REVIEW`. Over the API: open a
      `reviewSubmissions` for the app, add the version as a
      `reviewSubmissionItems`, then PATCH `submitted: true`. **Nothing reaches
      Apple until that last PATCH**, so the first two steps are safe to run and
      inspect. If it is rejected on Guideline 4.2 it arrives in Resolution Center
      against the same build; replying is the move, not rebuilding.
