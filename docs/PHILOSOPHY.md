# Philosophy

## The problem

Every macro tracker is bloated. They want you to scan a barcode for every
ingredient in a dish you cooked yourself. They want an account. They want a
subscription. They show ads. They gamify. They send notifications.

All I ever wanted was to write down "600 calories, 40 protein" and get on with
my day.

## The essence

**A number, a tracker, done.** Open the app, tap, type, dismiss. If logging a
meal takes longer than remembering it did, the app has failed.

And once you build that, you notice it isn't about food at all. It's a fast way
to write down *any* number that repeats: your weight, your cat's weight, water,
cigarettes, pushups, hours of sleep, migraines. So the app tracks whatever you
want, and it does it without ever making a thing of it. Hence the name:
*boring* is a promise you can hold the app to. One called Boring Tracker
cannot grow streaks, badges and a nagging notification later without admitting
it broke its own name.

## Rules that must not be broken

These are not preferences. Breaking one of these means the app has become the
thing it was built to replace.

1. **Free. Forever. All of it.** No subscription, no "pro" tier, no paid
   unlock, no tip jar that nags. Every feature ships to everyone.
2. **No ads.** Ever, in any form, including "recommended products" and
   affiliate links.
3. **No accounts, no sign-up, no login.** The app is useful three seconds after
   install, before it knows anything about you.
4. **No backend.** No server to run means no server to pay for, no server to
   leak, and no server that can shut the app down in 2029. Data lives on the
   device.
5. **No telemetry.** No analytics, no crash reporting SDK, no "anonymous usage
   data". The privacy label reads *Data Not Collected*, truthfully.
6. **Your data is yours and it leaves in one tap.** Full export to a plain,
   readable, documented format. Full import back. No lock-in, no proprietary
   blob, no "export available on Premium".
7. **Logging is never more than a few taps.** Any feature that adds a tap to
   the common path is rejected, no matter how good it is otherwise.
8. **Open source, permissive license.** Anyone can read it, fork it, build it,
   ship their own.
9. **No nagging.** No streaks, no badges, no confetti, no guilt, no "you
   haven't logged in 3 days!" push notification. Missing a day is fine. The app
   has no opinion about your body.
10. **No dependencies unless there is no alternative.** Platform frameworks
    only. Third-party SDKs are how ads, telemetry, and rot get in.

## What this app is not

Saying no is most of the design. Explicitly out of scope, permanently:

- **Barcode scanning** — the thing we're reacting against.
- **A food database** — 2 million entries of "Chicken, breast, raw, USDA 05062"
  that you still have to search through. Slower than typing `250`.
- **Photo/AI calorie estimation** — needs a server, needs money, guesses wrong.
- **Recipes, ingredients, nested foods** — this is the insanity, verbatim.
- **Social features** — friends, feeds, sharing, leaderboards.
- **Coaching** — meal plans, advice, "your metabolism", TDEE calculators.
- **Health scores, rings, grades** — the app does not judge.
- **Cloud sync as a service** — see rule 4. Export/import is the sync story.

If you need those, other apps do them, and they'd love your subscription.

## Design taste

- **Boring and native.** Standard SwiftUI, standard controls, system font,
  system colors, Dark Mode for free. It should feel like an Apple app that
  shipped in the OS, not a brand.
- **Fast to launch.** Cold start to usable in well under a second. No splash
  screen, no animation you have to sit through.
- **Nothing animates that you have to wait for.** Transitions are there to
  explain where things went, not to be admired. If a screen can appear
  instantly, it appears instantly. An animation that delays the keyboard by
  300ms has cost you more than every clever feature has saved.
- **The number pad is the interface.** For the common case the keyboard should
  already be up and it should be numeric.
- **Where a tap lands matters as much as how many.** A phone is held in one
  hand and driven by one thumb. The bottom third of the screen is in that
  thumb's arc; the top of a modern iPhone is not, and reaching it means
  shuffling your grip or invoking Reachability — which costs more than the
  extra tap you saved by putting the button up there. So **frequent actions
  live low.** Rare ones may live high, and the nav bar is a fine home for
  things you touch once a week. Minimal is not the same as optimal: count the
  taps, then look at where they land.
- **Count the taps, out loud.** The common path — open, log a food, done — has
  a tap budget and every feature is measured against it. A feature that is
  merely *good* does not get to spend a tap. Anything that adds a step in front
  of logging (a picker, a confirmation, a "choose a category") is wrong by
  default, however tidy it looks.
- **Legible over clever.** Big numbers, high contrast, readable at a glance
  with one hand at the fridge.
- **Forgiving.** Fast input means mistakes. Undo and edit must be trivial —
  including logging something for yesterday.
- **Quiet.** No sounds, no haptic celebrations, no color psychology. The app
  does not want your attention; it wants to give it back.

## The test

Before adding anything, ask:

> Does this make logging a number faster, or does it make the app bigger?

If it's the second one, the answer is no. It is *always* okay for this app to
do less than the competition. That's the product.

## And the same test for the code

Every technical decision goes through performance and simplicity, in that
order, with no third criterion. Not "what's the standard architecture", not
"what does Apple's sample project do", not "what scales to a million users" —
this app has one user per install and a few thousand numbers.

Reach for the smallest thing that works. A framework you don't need is startup
time you can't get back, failure modes you don't control, and a manual someone
has to read before they can fix a bug. If plain structs in an array do the job,
that is not a prototype to be replaced later. That is the finished design.
