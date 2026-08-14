# TODO

In implementation order. Short by design — if it's not here, it's either done
or in the "not now" parts of [PRODUCT.md](PRODUCT.md).

The ordering follows one rule: **settle the stored document's shape before the
first App Store release.** That is the freeze point, not daily use on our own
phone. Until then a schema change costs nothing real — delete the app and start
over, or export the JSON and hand-edit it. After it, every change is a migration
over history that belongs to somebody else, and a fresh chance to be wrong about
their data.

## 1. Settings screen and tracker editing — done

Nothing else can be tested without it — the app currently can't create a
tracker, so it's stuck with the two it ships with. `Store` already has `add`,
`update`, `delete`, `deleteWithHistory` and `move`, all tested and unreachable.

Includes the `group` field, since the tracker editor is where you set it.

- [x] Settings, reached from the home screen. One list; the tracker editor is
      the only subscreen, because five fields don't fit in a row.
- [x] Create, edit, archive, and reorder by drag in one flat list. Group
      membership is edited only in the tracker editor.
- [x] Both deletions, labelled apart and explained, in the editor where there
      is room to say which is which.

## 2. Schema changes, all at once — done

One version bump, while there's no data to migrate:

- [x] **`group` on Tracker.** A plain string, not a Group entity — groups
      are display grouping, so there's nothing to manage, no empty groups and
      no orphans. Pick from existing groups or type a new one.
- [x] **`name` on Entry**, replacing `note`. One field, used as the label, and
      the thing search looks at.
- [x] **`batchID` on Entry.** One logged food is two entries — 100 kcal and
      10 g protein — and this is what makes them one thing to edit or delete.
      Optional UUID, free now, a migration later.
- [x] **Delete `Pin`.** Superseded by search-and-repeat (item 9), which needs
      no stored preset at all. Not merely an unused struct — it sits in the
      serialized document with merge and tombstone handling, so removing it is
      a schema change and belongs in this window.

Default groups on first launch: **Food** (Calories, Protein) and **Weight**.

- [x] **`orderModified` on Tracker**, added after review. `sortIndex` is
      rewritten for every row a drag passes, so under one timestamp a reorder on
      one device silently discarded an edit made on another. The field that
      moves without being edited needs its own stamp.

No version bump for that one, and none for the next either: the number is for
recognising a file some *other* build wrote, and while this is a prototype there
is no other build. An older file on a simulator is caught by the decoder on the
first field it is missing, and quarantined. The number starts being maintained
at the first release, which is the same moment the shape freezes.

Schema version 2, and **no migration system, on purpose.** Nothing has been
released, so no v1 file exists outside a development simulator; one left there
is quarantined and started over, exactly as any unreadable file already is.
What stays is the three-line guard that accepts the current version and nothing
else — a *newer* file because it comes from a build that knows more, an *older*
one because no step reads it — rather than misreading either and saving the loss
back over the original. That one matters from the first release, and it is not a
migration system. A step from N to N+1 gets written the day there is a released
version to migrate from, and it takes the older versions with it.

## 3. The group log sheet — done

The core loop, and the reason for all of the above: tap +, land straight in the
last-used group's sheet with the keypad already up. Type 100 and 10,
optionally name it, save. One save, one batch.

**+ must not open a group picker.** Choosing a group is a tap on the common
path, and the common path is the product. Group switching lives inside the
sheet, for the log that isn't the usual one.

Measure the result in taps and milliseconds, not in whether it looks tidy.

- [x] The sheet shows one log group — a group's trackers, or one loose
      tracker on its own — and writes what was typed as a single batch.
- [x] + opens the last-used group straight away, keypad up and the first field
      focused; a card's + opens that card's group, focused on it.
- [x] Switching is the sheet's title — one tap to open, one to switch, and the
      keypad never goes down. Nothing stands in front of the sheet.
- [x] The last-used group lives in `UserDefaults`, not the document: it is UI
      state, so it must not sync, export, or appear in the store file.
- [x] Home is one ordered list of cards, since that is where the sheet is
      launched from: a run of trackers sharing a group gets that heading,
      everything else is a bare card, and nothing is gathered under "Other".

**Two taps and a number** on the common path: + , type, Save. Three from a cold
launch, counting the icon — the target in PRODUCT.md.

## 4. Terminology pass — done

Renamed the old grouping term to **group** everywhere — model, `Store`, views,
tests, docs — and checked `tracker` and `favourite` while in there. The
reasoning is in the Vocabulary part of PRODUCT.md; this item is just the
execution.

Its own session, with a test run: `group` reaches the model, the store, the
tracker editor, the log sheet and the tests, so it is mechanical but wide.

**The rename must not smuggle in an entity.** "Group" sounds more like a noun
than the old term did, and the next reasonable-seeming step is a `Group` type with
an id and an ordering — which is the management screen this app has twice
decided against. It stays a plain string on the tracker. See "Why a group is a
string, not an entity" in TECH.md.

Cheap now, pre-release. Worth doing before step 5 writes the word into a
history screen too.

### And: stop using position to mean membership

The step-3 review found that the two leftovers it was told to skip share one
root, and it is a design problem rather than a code one. **Position on a screen
is currently doing two jobs: order, and which group you belong to.** Because
there is no "drop outside" gesture, membership cannot be read back from
position on a screen that has no *Ungrouped* heading — so settings still needs
the very heading PRODUCT.md forbids, home cannot offer regrouping drags at all,
a settings drag silently reshuffles home, and a loose tracker can never be
placed above the first group.

So separate the two jobs:

- [x] **Settings becomes one flat, reorderable list** of every tracker — a
      single `ForEach`, no headings — with each row showing its group as a
      subtitle. Ordering only.
- [x] **Membership changes only in the editor's group field**, where it already
      works and is typo-proof (None / existing / New…).
- [x] The *No group* heading disappears with nothing to replace it, and no
      drop-target semantics are needed anywhere.
- [x] **Home is unchanged**: still one ordered list drawing a heading above each
      run of trackers that share a group.

This kills the forbidden heading, the drop-target ambiguity, the two
conflicting loose-tracker orderings, and the whole broken-drag class of bug at
once — and costs nothing on the common path, because settings is not on it.

Two loose ends it resolves in passing: `Store.move` gets a production caller
again (the flat list), so it stops being dead code; and `Store.add`'s comment
arguing against slotting a new tracker beside its group is stale — renumbering
restamps `orderModified`, which exists precisely so a reorder cannot outrank an
edit.

## 5. History screen

Everything logged, newest first, grouped by day — today is just the top of it.
A batch is **one row** ("chicken rice — 100 kcal, 10 g"), deleted or edited
once rather than once per tracker.

Without it, fixing a mistyped food means opening each tracker's detail
separately and deleting a row in each. It's the natural consumer of `batchID`,
and it comes right after the log sheet that starts writing them.

## 6. Export, import, CSV

Rule 6 is unfulfilled until data can leave. `exportData`/`importData` already
exist and are tested; nothing calls them. Import needs an explicit
merge-or-replace choice, since it's the only destructive action in the app.

Deliberately before daily use: it's the escape hatch if anything eats data.

## 7. CI

GitHub Actions build + test on push. Cheap, and the test suite is already good
enough to be worth protecting.

## 8. Use it on a real phone for a week

The step that decides everything after it. Whether logging is genuinely fast,
and what search and pinning should feel like, are not answerable from a
simulator.

## 9. Search and repeat

A search field at the **bottom** of the log sheet, in thumb reach. Empty query
lists your most-used foods by frequency and recency — the common case, with no
typing. Typing filters past entry names. Tapping a result logs it immediately
from that name's latest values, with a brief undo.

This replaces pins, favourites and recents with one control, and it is why
`Pin` was deleted rather than built.

**Treat this whole item as an experiment.** It is settled enough to build, not
settled enough to defend. Every part of it — the ranking, the prefill, what the
empty state lists, whether a tap logs or opens a sheet — is a *displayed*
decision computed from an append-only history (see "Two classes of decision" in
TECH.md), so it can be reworked or thrown away after real use at no cost and
with no migration.

The one thing to watch for during the week: an experiment that needs a fact the
document doesn't record. That's a stored decision, and it's the expensive kind —
flag it early rather than working around it.

## 10. App icon and asset catalog

Neither exists. Needed before TestFlight, not before daily use.

## After v1

- [ ] Home screen widget, Lock Screen widget, App Shortcuts / Siri.
- [ ] Sync transport — the document already merges; this is only plumbing.
- [ ] Apple Watch.
