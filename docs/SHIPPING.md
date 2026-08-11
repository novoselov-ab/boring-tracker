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
