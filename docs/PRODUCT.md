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
| **Daily total** | Entries *add up* over the day | Resets at the day start — midnight unless you move it | Calories, protein, water, cigarettes, pushups |
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

**Favourite**, if a label is ever needed for the things you log again. It is
the word people already have for it, and it beats "preset", which no consumer
app uses. Still not needed: the sheet those things live on is called **Log
again**, which names the *action* rather than a category of thing, so there is
no noun on screen to get wrong and nothing for the user to curate. It was
called **Repeat** first — also an action, but a concept you have to interpret,
where "Log again" is the app's own verb and says what the tap does.

**Log, and Save.** The button that records something happening says **Log** —
you are not saving a document, and *log* is the verb the whole product already
uses. The entry editor keeps **Save**, because there you genuinely are saving
an edit to something that already exists. Different action, different word.

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

   - **The list with nothing typed is the feature.** Before any query it
     already shows your most-used foods, ranked. You eat the same five things
     most days, and typing four letters for those would be slower than a
     button — so the common case needs no typing at all, and search is only
     for reaching past it. One screen replaces recents, favourites and search,
     and none of them need to exist as concepts.
   - **Tapping a row logs it immediately**, as a new entry with today's
     timestamp, leaving the original alone. Not a prefilled sheet you then
     confirm — that's three taps to do a one-tap thing. Mistaps become
     possible, which is precisely why undo has to be trivial (see
     PHILOSOPHY.md). A brief undo after logging is the right trade; a
     confirmation on every repeat is not.

   **It is its own presentation, not a field inside the log sheet.** That was
   the original design and it was replaced before it was built: the sheet is
   where you type a number that is *new*, and logging something again is a
   different job that never needs a keypad at all. So it gets a quiet door of
   its own beside home's Log button — see **Log again** under Screens — and the
   log sheet keeps none of it.

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
  whole main screen — arranging the list is a settings job. **Six to ten cards
  fit without scrolling** on a current iPhone, which is the density to hold a
  change to: four trackers must never fill a screen.

  **The card's number is the one thing in this app that animates**, counting up
  to its new value over 0.8s when it changes. It is the single deliberate
  exception to "nothing animates that you have to wait for" (PHILOSOPHY.md),
  and it earns it by delaying nothing: the log sheet still closes in the same
  breath, in the same measured time as a build without any of this, and the
  number is still counting behind it half a second after the sheet has gone. An
  ease, not a spring — a number that bounces is congratulating you. It counts
  rather than swapping because the swap showed you a *different* number and
  left you to work out what had been added. It also counts down to zero when
  you open the app the morning after, which is left alone: the number really
  did change, and the alternative is putting the animation back in the hands of
  everything that writes.
- **Log sheet** — number pad, tracker(s), date/time (defaults to now, tappable
  to change), optional name, Log. One group's trackers, or one loose tracker;
  its title is how you switch between them, and the keypad never goes down to
  do it. Backdating is first-class: you *will* forget dinner until the next
  morning. There is no row of recent *values* — people do not log the same
  number twice, they log the same food, which is what the Log again sheet is
  for.
- **History** — everything you've logged, newest first, grouped by day, and
  searchable by name through the same matcher the Log again sheet uses. Today
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
  swipe-delete. **The row it writes arrives marked**, washed in the accent, and
  the mark fades out by itself after a couple of seconds: a new row dated now
  lands among rows dated a few minutes ago, and without it you are comparing
  timestamps to find the one your tap made. It fades because a mark that stays
  is a second state to reason about.

  **A row leads with what identifies it** — your name for it, or the tracker or
  group when you typed none — and the numbers follow. Reading order is what
  makes a list scannable, and the numbers are not the part that tells two rows
  apart. An entry with no name disappears under a non-empty query, because this
  searches names and the field says so.
- **Log again** — the things you have logged to a daily total, most recently
  logged first, one tap each to log again. (Named or not: a name has decided
  nothing here since item 21, and the order stopped being a frequency count in
  item 29.) Reached by a small disc beside home's
  Log button, deliberately quieter than it: the bottom of home holds the most
  frequent action in the app, and a second equal button there reads as a choice
  to make on arrival, which is a decision in front of logging. What makes it
  quieter is its size and the absence of a word, not its colour — it is the
  same disc, in the same accent, that a History row and a Log again row carry,
  because it is the same action, drawn at 50pt here against their 30 so that it
  agrees with the pill on height and corner (TODO item 33). Searchable by name, like History. The whole
  row is the button — there is nothing else a tap here could mean, so the
  target is the full width rather than a disc on the end of it.

  **It comes up over home at half height and leaves as soon as you have
  logged.** It was a pushed screen first, and a pushed screen with a title, a
  list and a search field is what History already is — so it read as a second
  History rather than as a fast way to log. A presentation that stops short of
  the top, with home still visible behind it, is the difference between a thing
  that came up and somewhere you went. The cost is that nothing here can be a
  destination: no editing a row, no deleting one, no second tap. That is the
  point, and History is still there for all of it.

  The undo lives on home, where the sheet leaves you — a bar that appears only
  after a repeat and goes when there is nothing left to take back.

  **A row is what a tap writes, not everything the batch held.** A weigh-in
  breakfast is listed as its calories, and a lunch logged beside a tracker you
  have since archived is listed as the half still live — because a row here is
  an offer to do that again, and an offer showing a number the tap will drop is
  not one. History is the screen that still holds both, and still says so.

  **One row per thing you ate, not per time you ate it.** Rows sharing both a
  name and their values collapse into the newest of them, so forty logs of
  "chicken rice — 620 kcal, 45 g" are one row while the same food at a bigger
  portion stays its own: a bigger portion is a different thing to log again.
  Someone who weighs every meal to the gram repeats no number exactly, so
  nothing collapses for them and they get the plain list back — a known limit,
  and rounding to paper over it would be the app deciding what counts as the
  same meal.

  **Most recently logged first**, and nothing else — a row is dated by the last
  time you logged it, and that is the order. It is what the screen looks like it
  should do, and the point is that you can reason about where a row will be next
  time from what you can see on it.

  It replaced an order that counted: how often in the last 60 days, then how
  often ever, then recency. That order was measured and it worked — the portion
  you usually eat floated to the top — but the counts are invisible, so the list
  moved on a rule the screen never states. Chronological approximates frequency
  for the staples anyway, because something you eat often you also ate recently.
  The counting rule is written up in TODO.md item 29, and it is the first thing
  to try if this ever feels wrong.

  **Nothing ever leaves this list.** A food you gave up months ago sinks to the
  bottom on its date; it does not disappear. Neither does one that can no
  longer be written at all because every tracker it named has been archived —
  it sorts below every row that can, with the whole row greyed and disabled,
  and **the row says why** rather than leaving a grey control to be
  interpreted. A screen that drops food when you archive a tracker is editing
  your history.

  Two honest edges of that promise. A row whose every tracker was *deleted* is
  not here at all — there is nothing left of it to log again, and History is
  where a record with no tracker belongs. And a row can stop being its own row
  by *merging*: since a row is what a tap writes, two rows that write the same
  thing are one, even where the batches behind them differed in a part that is
  not written. Neither is a row going missing; both follow from what this
  screen is for.

  History says the same thing the same way. A row whose repeat disc is off
  carries the reason on its quiet identity line — *Archived*, *Measurement*, or
  the *Deleted tracker* it has always printed — and a row whose disc works
  carries nothing extra.

- **Tracker detail** — the graph on top, that tracker's entries below, grouped
  by day. Swipe to delete, tap to edit.
- **Graph** — daily totals as bars, measurements as a line with a moving
  average. Range switch: week / month / year / all. Nothing interactive beyond
  scrubbing for a value.
- **Settings** — the trackers (add/edit/archive/reorder), drawn in the same
  shape as home so the two cannot disagree — a heading above each run of
  trackers sharing a group, bare rows for loose ones, and **membership changed
  only in the tracker editor**, never by where a row sits. Same density too,
  since item 28: a tracker row is 52pt here exactly as it is on home, where it
  used to be 74. Also export, import, **delete all
  data** — one confirmation naming what goes, undone from *Restore Previous
  Data* — appearance, **the hour the day starts at**, about + link to the
  GitHub repo. It is called *Delete
  All Data* and not *Delete Everything* because the tracker editor already has
  a *Delete Everything*, which takes one tracker with its history and genuinely
  cannot be undone. One screen, no subscreens if
  avoidable. **A reorder drag commits wherever you let go, including outside
  the list** — it lands on the nearest row that is on screen. That is
  deliberate, not a missed cancel: the nearest row is defined from any
  position, so there is nothing to resolve by refusing, and cancelling when the
  finger strayed a few points past an edge it cannot see would throw away a
  drag heading for the end of the list. To undo a drag you didn't mean, drag it
  back.

**A row that does something behaves like the button it is**, on every screen
that has one — settings, History, the Log again sheet, tracker detail, home's
cards. The whole row is the target, not the words drawn in it: a row you can hit
on its text and on its chevron and nowhere in between is worse than one that is
plainly not tappable, because a miss teaches you the tap failed rather than that
you aimed wrong. And it responds to the press — the whole row fills with the
same grey iOS presses its own rows to, edge to edge and clipped to the card the
way the platform does it, and goes down by the same 2pt the app's buttons have
gone down by since item 27. Under Reduce Motion it takes the colour and not the
movement, which is the rule every press in this app follows.

**A press applies on the frame the touch lands.** Nothing about a pressed state
fades in, anywhere: only the release is drawn. Two earlier attempts at "a press
you can see" changed what was drawn and not when, and a tap is shorter than a
fade (TODO item 32).

Three of those rows are really *two* controls side by side — a History row, a
home card and an active settings row each pair something that opens with a disc,
a `+` or a drag handle — and there the wash covers the part you actually pressed
rather than the whole row. That is the row saying which of its two buttons you
got. The ones that fill are a settings row with nothing beside it and a Log
again row, where the whole row really is one button.

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
- **Export** writes one file containing everything: the schema version, the
  trackers, the entries and the tombstones. Human-readable JSON, with the
  format documented in the repo so anyone can write a converter. There is no
  preset record and no goal field to export — presets became "a past entry you
  liked" and goals were decided against, both below.
- **CSV export** as well: one whole-history file with one row per entry,
  including batch and tracker IDs plus the tracker's current name, unit and
  kind. Keeping a batch's rows together makes the file useful in a spreadsheet
  without throwing away the relationship between values logged at once.
- **Either file leaves through the share sheet** — AirDrop, Messages, Mail,
  anything that takes a file, with Files among them. It carries a dated name,
  `boring-tracker-2026-08-17.json`.

  There was a second door for a while: a *Save to Files* row apiece, going
  straight to the document picker, on the reasoning that repeating an export to
  the same folder should not cost the tap the share sheet charges to get there.
  Both rows and the whole `.fileExporter` path were **removed** once the share
  sheet worked (TODO item 18c) — two doors to the same bytes is two things to
  keep in step, and Files is one tap inside the sheet.
- **Import** restores from an export file. Merge or replace, stated clearly
  before it happens, because this is the one destructive action in the app.
  Either way the document it replaces is kept as a one-step recoverable backup:
  merge sounds additive, but the file it takes in carries deletions, so it can
  remove entries too. The backup is silent and automatic — no second tap for
  the safe option.
- Backup and cross-device is the user's business: save the export to Files,
  iCloud Drive, wherever. The app doesn't run a sync service (rule 4).

## Scope

**v1 ships:** trackers (both kinds), logging by typing a number, backdating,
editing and deleting, history list, graphs, the Log again sheet, JSON + CSV
export, JSON import, dark mode.

This line used to say *recents* and to put *presets* in the paragraph below,
"once we've used the basics enough to know what shape they should take". Both
have since been answered and neither arrived in the shape the words expected.
The log sheet's row of recent **values** was built and then removed (TODO item
11): people do not log the same number twice, they log the same food. And
presets are not a v1.1 feature to design — they are the **Log again** sheet,
which shipped inside v1 and delivered them by *removing* a model type rather
than adding one. What is left for "right after v1" is the home screen widget,
App Shortcuts / Siri and the Lock Screen widget — these matter a lot for the
"minimum taps" promise, but the app has to exist first.

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

- Swift + SwiftUI, current iOS minus one major version — iOS 18, built with
  Xcode 26.
- **One JSON file, decoded into plain structs at launch**, as both the store
  and the export format. This line used to read "SwiftData (or plain Core Data
  / SQLite if it fights us)"; that was written before the storage question was
  benchmarked, and the benchmark went the other way. There is no SwiftData, no
  Core Data and no SQLite in this app — see "Storage: a JSON file" in
  [TECH.md](TECH.md) for the numbers and for why the export format being the
  storage format is what decided it.
- Zero third-party packages. No package manager entries at all, ideally.
- Tests on the parts that would silently ruin data: day-boundary math,
  aggregation, export/import round-trip.
- MIT license.
