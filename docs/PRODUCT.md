# Product

What the app actually is, in concrete terms. Read
[PHILOSOPHY.md](PHILOSOPHY.md) first — it's the constitution; this is the
statute.

## The model

Three nouns, and the third is only a string.

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

Trackers that get logged **at the same time** share a group. `Food` holds
Calories and Protein; `Weight` holds your weight, and later your cat's.

A group is **a string on the tracker, not an entity.** There is nothing to
create, nothing to manage, no empty groups and no orphans — you pick an
existing one or type a new one while editing a tracker. That's deliberate: the
moment groups get their own screen, this app has grown the management UI it
exists to avoid.

It earns its place for one reason. With a dozen trackers, tapping + would open
a dozen-item list to scroll, which breaks rule 7. A group collapses that to
one sheet with a handful of fields — the same "one sheet, both numbers, one
log" requirement below, reached from the other direction.

**A tracker with no group is logged on its own.** Being in no group is not
itself a group: your cigarettes and your pushups share nothing but the absence
of a name, so one sheet holding both would claim they are logged at the same
time, which is the one thing a group means. Tapping + on a loose tracker gives
you one field. Groups are for the trackers that genuinely arrive together, and
most people will have one or two of them and a pile of loose trackers.

**Critically, choosing what to log must not cost a tap.** Tapping + opens the
last-used sheet immediately, keyboard already up — a group's, or a single
tracker's. Switching happens *inside* the sheet, from its title, for the rare
log that isn't the usual one. The list behind that title is the dozen-item list
this design exists to avoid putting *in front* of you; a picker before every log
is precisely the friction this app exists to delete. If groups ever add a step
to the common path, they have failed and should be removed.

Ordering and membership are deliberately separate. Dragging in settings changes
only order; a tracker's group changes only in its editor, using **None**, an
existing group, or **New Group…**. Position never implies membership.

But settings **draws the same shape home does** — headings above runs, bare
rows for loose trackers — because a settings screen showing an order home won't
honour is simply lying. Within a run, dragging reorders that group's members;
a group moves as a unit. The two screens agree by construction, which is the
only way they can be relied on to agree at all.

First launch starts with **Food** and **Weight**.

### A tracker with no group

Most trackers don't belong with anything. You want to count sneezes per day and
that is the entire requirement — there is nothing to log it alongside.

**So no group is not a state with a name.** Such a tracker is simply a card
with no heading above it, and its + opens a sheet with one field.

There is no *Ungrouped* or *Other* heading, ever. That would be filing
bureaucracy appearing for the person who least asked for it: someone tracking
one number has no organisational problem to solve, and a heading called "Other"
tells them they failed to file something. It also frames the plain case as the
exception, which is backwards — having no group is the normal state, and a
group is what gets earned when two numbers genuinely come from one event.

The home screen therefore needs no special case: it is **one ordered list of
cards**, where a group gets a heading above its trackers and every other
tracker is a bare card where it already sits.

The blocks are the things you log in one go, so what is drawn as one block is
exactly what one + opens. A group's trackers are drawn together even if they
aren't next to each other in the list — a group appearing twice under two
identical headings would be claiming a grouping the sheet then contradicts.
Only a group's stragglers move, up to where that group already is; nothing
is gathered at the bottom.

**Arranging that list happens in settings, not here.** Settings draws the same
shape as this screen — a heading above each run of trackers sharing a group,
bare rows for loose ones — so what you arrange there is what you get here.
Dragging within a run reorders that group's members; a group moves as a unit.
Membership still changes only in the tracker editor, so no drop gesture ever
has to mean "remove from group."

Nor does the code: **the log sheet always takes a set of trackers.** A group
is a named set; a lone tracker is a set of one. Same sheet, same one-log-one-
batch, no branching — and + returning to whatever you last logged works the
same either way.

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

## Vocabulary

The words the app uses in public, and why. Checked against how the category
actually speaks: ~140 App Store descriptions of tracking apps were scanned for
which nouns they use for these concepts.

| concept | word | apps using it |
|---|---|---|
| the thing you track | **tracker** | 12 (top result excluding *habit*, which is domain-specific) |
| trackers logged together | **group** | see below |
| a thing you repeat | **favourite** | 7 (*preset* and *template*: 0) |

**Tracker.** "Metric", "variable", "measure" and "field" appear in **zero**
consumer descriptions — they are engineer words, however natural they feel
while writing the model. "Tracker" is the word people arrive already knowing.
That the app is itself called Boring Tracker is fine: Notes holds notes,
Reminders holds reminders, and an app named for what it holds is ordinary.

Use the word **rarely**. The concrete names carry it — the home screen and the
settings list just say Calories, Protein, Weight. The empty state asks *"What
do you want to track?"* rather than announcing that you have no trackers. That
leaves roughly one button and the App Store description, which is the right
amount of exposure for a word we are not certain about.

**Group.** The old term described a UI accident — a part of a list on one
screen. "Group" describes the intent: these things belong together. It is
also the verb people reach for unprompted ("I want to *group* them as Honda
wheels"). The old term scores zero in consumer descriptions.

The example that settles it: left and right tire pressure, grouped as `Honda
wheels`. That is not a *category* of tracker or merely a part of a list —
it is one event that produces two numbers. Which is what a group means, and why
it earns its place at all: **some measurements only make sense taken together.**
Logging half of a pair is nearly useless, so the app must never make you do it
in two trips.

Like "tracker", the word barely appears: the home screen shows the heading
`Honda wheels`, and the only visible use of the noun is one field label in the
tracker editor.

**Favourite**, if a label is ever needed for search-and-repeat. It is the word
people already have for "the thing I log again", and it beats "preset", which
no consumer app uses. Not needed yet — see the search-and-repeat design below,
which deliberately has no button to name.

**Never *recipe*.** Food apps do have this concept — MyFitnessPal keeps Foods,
Meals and Recipes as three separate things to manage — and it is precisely the
bloat this project exists to reject: an ingredient editor, a library, per-
serving maths. Naming an entry and finding it again gets the same benefit with
none of the machinery.

## Adding a group

There is no "create a group" screen, and there never will be. A group comes
into being because a tracker says it belongs to one.

In the tracker editor the group field offers **None**, every group that already
exists, and **New Group…**, which reveals a text field. Picking and typing are
the same field wearing two hats.

They are kept as *distinct choices* rather than one free-text box with
autocomplete for a specific reason: a plain text field lets a mistyped `Foood`
silently fork a group in two, and the two look identical in a list while
behaving nothing alike. Choosing from what exists makes the common path
typo-proof.

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
3. **One food, one sheet, one log.** Calories and protein come from the same
   meal. Typing them in two separate flows is the single most annoying thing
   this app could do — so the sheet takes the whole group at once, plus a
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
  a + button. Measurement cards show the latest reading and when. That's the
  whole main screen — arranging the list is a settings job.
- **Log sheet** — number pad, presets/recents row, tracker(s), date/time
  (defaults to now, tappable to change), optional name, Log. One group's
  trackers, or one loose tracker; its title is how you switch between them.
  Backdating is first-class: you *will* forget dinner until the next morning.
- **History** — everything you've logged, newest first, grouped by day. Today
  is simply the top of it. A batch is **one row**: "chicken rice — 100 kcal,
  10 g", deleted or edited once, not once per tracker. Without this screen,
  fixing a mistyped food means visiting each tracker's detail separately and
  deleting a row in each, which is absurd. A batch whose members straddle
  midnight is drawn once, under its newest surviving member — a row is a thing
  you logged, and one thing cannot appear on two days. Every row also has a
  **repeat button**: one tap writes the same values against the same trackers
  with today's timestamp, as a new row, leaving the old one alone. That is
  search-and-repeat's idea arriving through a different door — you don't search
  for a food, you scroll to the last time you ate it — and the undo it needs
  sits in a bar at the bottom of the screen, which also carries the undo for a
  swipe-delete.
- **Tracker detail** — the graph on top, that tracker's entries below, grouped
  by day. Swipe to delete, tap to edit.
- **Graph** — daily totals as bars, measurements as a line with a moving
  average. Range switch: week / month / year / all. Nothing interactive beyond
  scrubbing for a value.
- **Settings** — the trackers (add/edit/archive/reorder), drawn in the same
  shape as home so the two cannot disagree; export, import,
  appearance, about + link to the GitHub repo. One screen, no subscreens if
  avoidable. **A reorder drag commits wherever you let go, including outside
  the list** — it lands on the nearest row that is on screen. That is
  deliberate, not a missed cancel: the first row sits under the navigation bar,
  so reaching it means dragging to the top edge and past it, and a drag that
  cancelled when the finger left the list would make the top of the list the
  one place you cannot drop. To undo a drag you didn't mean, drag it back.

Notably absent: no dashboard, no home feed, no onboarding carousel, no profile.

## First launch

The app is useful immediately or the promise is broken. On first launch there
are already trackers: **Calories** and **Protein** in a **Food** group, both
daily totals, and **Weight** in its own, no goals set. You can log something
before you've configured anything, and the two groups mean the group log
sheet has something to be about on day one. Deleting any of them takes a few
taps in settings if you're here for the cat.

No tour, no signup, no permission prompts (notifications aren't used at all).

## Data, export, import

- Storage is local, on-device. That's the source of truth.
- **Export** writes one file containing everything: trackers, entries,
  presets, goals. Human-readable JSON, with the format documented in the repo
  so anyone can write a converter.
- **CSV export** as well: one whole-history file with one row per entry,
  including batch and tracker IDs plus the tracker's current name, unit and
  kind. Keeping a batch's rows together makes the file useful in a spreadsheet
  without throwing away the relationship between values logged at once.
- **Import** restores from an export file. Merge or replace, stated clearly
  before it happens, because this is the one destructive action in the app.
  Either way the document it replaces is kept as a one-step recoverable backup:
  merge sounds additive, but the file it takes in carries deletions, so it can
  remove entries too. The backup is silent and automatic — no second tap for
  the safe option.
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
