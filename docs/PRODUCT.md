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

### Section

Trackers that get logged **at the same time** share a section. `Food` holds
Calories and Protein; `Weight` holds your weight, and later your cat's.

A section is **a string on the tracker, not an entity.** There is nothing to
create, nothing to manage, no empty sections and no orphans — you pick an
existing one or type a new one while editing a tracker. That's deliberate: the
moment sections get their own screen, this app has grown the management UI it
exists to avoid.

It earns its place for one reason. With a dozen trackers, tapping + would open
a dozen-item list to scroll, which breaks rule 7. A section collapses that to
one sheet with a handful of fields — the same "one sheet, both numbers, one
save" requirement below, reached from the other direction.

**Critically, choosing a section must not cost a tap.** Tapping + opens the
last-used section's sheet immediately, keyboard already up. Switching sections
happens *inside* the sheet, for the rare log that isn't the usual one. If
sections ever add a step to the common path, they have failed and should be
removed — a picker in front of every log is precisely the friction this app
exists to delete.

Ordering works two ways, both by dragging: **within** a section to choose which
tracker comes first, and **between** sections, where dropping a tracker under a
different heading is what changes its section. Editing the string in the
tracker editor does the same thing, but dragging is the obvious gesture and
should exist. Sort order is therefore per section, not global.

First launch starts with **Food** and **Weight**.

### Entry

A number, a tracker, a timestamp, an optional **name**, and a **batch id**.
No tags, no meal types, no photos.

The name is the point of the whole design: you don't log "protein", you log a
*food*. Naming it is what lets you find it again, and what makes presets fall
out for free — a preset is simply a past entry you liked (see below).

One logged food is two entries — 100 kcal and 10 g protein — so they share a
`batchID`. That's what makes them a single thing to edit or delete later,
rather than two rows that happen to have the same timestamp. The name is
stored on **each** entry in the batch, duplicated on purpose: a Batch entity
to hold one string would add orphan cleanup and a merge case to save twenty
bytes.

**A name is a label, never a key.** Nothing is ever overwritten. Log "chicken
rice" ten times with ten different values and you keep ten entries — that is
what makes the graph true. The only place "the latest one wins" applies is
which values get *prefilled* when you type that name again, and that is a
ranking decision, not a data one: it can become most-frequent, or a short list
of recent variants, at any time, with no migration and nothing stored
differently.

It also means names never cause sync conflicts. Entries are identified by
UUID, so two devices logging "chicken rice" merge as a plain union.

## How logging gets fast

This is the whole product, so it deserves the most thought.

Without a food database you type numbers by hand — which is *already* faster
than searching a database, but it isn't fast enough on its own. The speed comes
from the fact that **you eat the same things over and over.**

So, in order of importance:

1. **Naming is saving. Search is how you get it back.** There are no presets to
   create, no star button, no favourites list. You log a food and name it —
   that name makes it findable forever. Type "chicken", see "chicken rice",
   tap it, logged again.

   This is the design that finally answers the preset question, and it answers
   it by **removing a model type** rather than adding one. Nothing to curate,
   nothing to keep in sync with reality, nothing that can rot. Your history is
   the library.

   Two details carry the whole thing:

   - **The empty search field is the feature.** With no query typed, the list
     shows your most-used foods, ranked by frequency and recency. You eat the
     same five things most days, and typing four letters for those would be
     slower than a button — so the common case needs no typing at all, and
     search is only for reaching past it. One control replaces recents,
     favourites and search, and none of them need to exist as concepts.
   - **Tapping a result logs it immediately**, prefilled from that name's most
     recent values. Not a prefilled sheet you then confirm — that's three taps
     to do a one-tap thing. Mistaps become possible, which is precisely why
     undo has to be trivial (see PHILOSOPHY.md). A brief undo after logging is
     the right trade; a confirmation on every repeat is not.

   It lives at the **bottom** of the log sheet, in thumb reach, results rising
   above it.

   Call these **presets** if they need a name at all, and never *recipes*. A
   recipe is ingredients, and ingredients are permanently out of scope — see
   PHILOSOPHY.md. The word matters because it's the direction this would drift
   if allowed to.
3. **One food, one sheet, one save.** Calories and protein come from the same
   meal. Typing them in two separate flows is the single most annoying thing
   this app could do — so the sheet takes the whole section at once, plus a
   name, and writes it as one batch.
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
  (defaults to now, tappable to change), optional name, Save. Backdating is
  first-class: you *will* forget dinner until the next morning.
- **History** — everything you've logged, newest first, grouped by day. Today
  is simply the top of it. A batch is **one row**: "chicken rice — 100 kcal,
  10 g", deleted or edited once, not once per tracker. Without this screen,
  fixing a mistyped food means visiting each tracker's detail separately and
  deleting a row in each, which is absurd.
- **Tracker detail** — the graph on top, that tracker's entries below, grouped
  by day. Swipe to delete, tap to edit.
- **Graph** — daily totals as bars, measurements as a line with a moving
  average. Range switch: week / month / year / all. Nothing interactive beyond
  scrubbing for a value.
- **Settings** — trackers (add/edit/archive/reorder), export, import,
  appearance, about + link to the GitHub repo. One screen, no subscreens if
  avoidable.

Notably absent: no dashboard, no home feed, no onboarding carousel, no profile.

## First launch

The app is useful immediately or the promise is broken. On first launch there
are already trackers: **Calories** and **Protein** in a **Food** section, both
daily totals, and **Weight** in its own, no goals set. You can log something
before you've configured anything, and the two sections mean the section log
sheet has something to be about on day one. Deleting any of them takes a few
taps in settings if you're here for the cat.

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
