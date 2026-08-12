# Product

What the app actually is, in concrete terms. Read
[PHILOSOPHY.md](PHILOSOPHY.md) first — it's the constitution; this is the
statute.

## The model

There are exactly two nouns.

### Tracker

A thing you track. You create it, you name it, you pick a unit. Examples:
Calories, Protein, Water, Weight, Cat weight, Cigarettes, Pushups.

A tracker is one of two kinds, and this is the only real decision the user
makes:

| Kind | Meaning | Day boundary | Examples |
|---|---|---|---|
| **Daily total** | Entries *add up* over the day | Resets at midnight | Calories, protein, water, cigarettes, pushups |
| **Measurement** | Each entry is a standalone reading | No reset, just points in time | Weight, cat's weight, blood pressure, sleep hours |

Everything else follows from this. A daily-total tracker shows "today: 1,340"
and a big + button. A measurement tracker shows "last: 78.4 kg, 2 days ago".

A tracker has:

- name
- unit (`kcal`, `g`, `kg`, `ml`, `reps`, or blank)
- kind (daily total | measurement)
- decimal places (0 for calories, 1 for weight)
- position in the list
- archived flag (hide without deleting the history)

No goal field. See "Decided against" below — the number is the feature.

### Group

A named set of trackers that get logged **at the same time**. `Macros` holds
Calories and Protein; `Cat` holds the cat's weight.

This is not a filing system, and it exists for exactly one reason: with a dozen
trackers, tapping + would open a list of a dozen things to scroll, which breaks
rule 7. Instead + offers a handful of groups, and picking one opens a single
sheet with that group's trackers on it — which is the same "one sheet, both
numbers, one save" requirement described below, arrived at from the other
direction.

Two constraints keep it from becoming a taxonomy:

- **A tracker belongs to one group.** Multiple membership needs a management
  screen, and a management screen is how this app dies.
- **Groups stay out of the way until they earn their place.** With two or three
  trackers there is nothing to organise, so a single default group exists and
  the UI for groups doesn't appear at all.

Presets belong to a group, since a preset is a set of numbers for trackers that
are logged together.

### Entry

A number, a tracker, a timestamp, and optionally a short note. That's it.
No tags, no meal types, no photos.

## How logging gets fast

This is the whole product, so it deserves the most thought.

Without a food database you type numbers by hand — which is *already* faster
than searching a database, but it isn't fast enough on its own. The speed comes
from the fact that **you eat the same things over and over.**

So, in order of importance:

1. **Presets.** Per tracker, a handful of saved values with labels: `Coffee 5`,
   `Usual breakfast 450`, `Protein shake 160`. One tap logs it. This is the
   replacement for barcode scanning, and it is better, because it's *your*
   food and you only pay the setup cost once.

   The danger is that presets are exactly where this app grows a management UI
   and turns into the thing it replaced. So they are not something you create —
   they're something you *keep*: **recents appear on their own, and you pin the
   ones you want to stay.** Pinning is the whole feature. No setup flow, no
   manage-presets screen, nothing to maintain.

   A pin can carry several trackers at once, because "usual breakfast" is
   450 kcal and 30 g protein together, not two separate things to tap. That
   makes a pin naturally belong to a group.

   Call these **presets**, never *recipes*. A preset is a saved set of numbers
   with a label. A recipe is ingredients, and ingredients are permanently out
   of scope — see PHILOSOPHY.md. The word matters because it's the direction
   this feature would drift if allowed to.

   Details deferred on purpose until the basics are in daily use. Building it
   earlier means guessing.
2. **Recents.** The last few distinct values you logged, offered
   automatically. No setup at all, so it's the natural raw material for
   whatever presets become.
3. **Multi-tracker entry.** Calories and protein come from the same meal.
   Typing them in two separate flows is the single most annoying thing this app
   could do. One sheet, both numbers, one save.
4. **The keypad is already up.** Tapping + goes straight to a numeric field
   with focus. No intermediate screen, no picker, no "choose a category".
5. **Outside the app entirely.** Home screen widget with your top trackers →
   tap → logged. Lock Screen widget. App Shortcuts / Siri ("log 500
   calories"). Control Center control. The fastest tap is the one that never
   opened the app.

Target: **two taps** to log a preset from the home screen widget. **Three taps
and a number** to log an arbitrary value from a cold launch.

## Screens

Small enough to list completely.

- **Home** — your trackers as cards. Daily-total cards show today's number and
  a + button. Measurement cards show the latest reading and when. Reorder by
  drag. That's the whole main screen.
- **Log sheet** — number pad, presets/recents row, tracker(s), date/time
  (defaults to now, tappable to change), optional note, Save. Backdating is
  first-class: you *will* forget dinner until the next morning.
- **Tracker detail** — the graph on top, the list of entries below, grouped by
  day. Swipe to delete, tap to edit.
- **Graph** — daily totals as bars, measurements as a line with a moving
  average. Range switch: week / month / year / all. Nothing interactive beyond
  scrubbing for a value.
- **Settings** — trackers (add/edit/archive/reorder), export, import,
  appearance, about + link to the GitHub repo. One screen, no subscreens if
  avoidable.

Notably absent: no dashboard, no home feed, no onboarding carousel, no profile.

## First launch

The app is useful immediately or the promise is broken. On first launch there
are already trackers: **Calories** and **Protein**, both daily totals, no goals
set. You can log something before you've configured anything. Deleting them is
one swipe if you're here for the cat.

No tour, no signup, no permission prompts (notifications aren't used at all).

## Data, export, import

- Storage is local, on-device. That's the source of truth.
- **Export** writes one file containing everything: trackers, entries,
  presets, goals. Human-readable JSON, with the format documented in the repo
  so anyone can write a converter.
- **CSV export** as well, per tracker, because that's what people actually
  paste into a spreadsheet.
- **Import** restores from an export file. Merge or replace, stated clearly
  before it happens, because this is the one destructive action in the app.
- Backup and cross-device is the user's business: save the export to Files,
  iCloud Drive, wherever. The app doesn't run a sync service (rule 4).

## Scope

**v1 ships:** trackers (both kinds), logging by typing a number, recents,
backdating, editing and deleting, history list, graphs, JSON + CSV export,
JSON import, dark mode.

**Right after v1:** presets, once we've used the basics enough to know what
shape they should take. Then home screen widget, App Shortcuts / Siri, Lock
Screen widget — these matter a lot for the "minimum taps" promise, but the app
has to exist first.

### Decided against

Not "never" in every case, but not now, and not to be quietly reintroduced:

- **Goals and targets.** Tempting, and it's how every other macro app works.
  But a goal is a number you already know, and the app showing `1,340` next to
  a goal of `2,000` is doing subtraction you can do yourself. It also drags in
  progress rings, over/under coloring, and eventually judgment — which rule 9
  forbids. Show the number. That's the feature.
- **Sync, in v1.** Using the app on an iPhone *and* an iPad is a real goal, so
  sync is wanted eventually — but not in the first version, and not by adopting
  a database to get it. The document is built mergeable from the start (see
  TECH.md) and the transport is chosen later. Until then, export/import moves
  data between devices, and ordinary iPhone backups protect it.
- **Apple Health.** Useful and first-party, but it's a permission prompt and a
  pile of unit and edge-case handling for something most users won't turn on.
- **Apple Watch, iPad, Mac.** A Watch app is the best possible fit for this
  philosophy and still real, ongoing work. Not while there's no iPhone app.
- **Barcode scanning, food database, AI photo estimation, recipes, social,
  coaching, streaks.** Permanently out. See PHILOSOPHY.md.

## Technical direction

- Swift + SwiftUI, current iOS minus one major version.
- SwiftData (or plain Core Data / SQLite if it fights us) for local storage.
- Zero third-party packages. No package manager entries at all, ideally.
- Tests on the parts that would silently ruin data: day-boundary math,
  aggregation, export/import round-trip.
- MIT license.
