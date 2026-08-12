# TODO

In implementation order. Short by design — if it's not here, it's either done
or in the "not now" sections of [PRODUCT.md](PRODUCT.md).

The ordering follows one rule: **settle the stored document's shape before the
app is in daily use.** Every schema change after real history exists on a phone
costs a migration; before that it costs nothing.

## 1. Settings screen and tracker editing

Nothing else can be tested without it — the app currently can't create a
tracker, so it's stuck with the two it ships with. `Store` already has `add`,
`update`, `delete`, `deleteWithHistory` and `move`, all tested and unreachable.

Includes the `section` field, since the tracker editor is where you set it.

## 2. Schema changes, all at once

One version bump, while there's no data to migrate:

- [ ] **`section` on Tracker.** A plain string, not a Group entity — sections
      are display grouping, so there's nothing to manage, no empty groups and
      no orphans. Pick from existing sections or type a new one.
- [ ] **`name` on Entry**, replacing `note`. One field, used as the label, and
      the thing search looks at.
- [ ] **`batchID` on Entry.** One logged food is two entries — 100 kcal and
      10 g protein — and this is what makes them one thing to edit or delete.
      Optional UUID, free now, a migration later.

Default sections on first launch: **Food** (Calories, Protein) and **Weight**.

## 3. The section log sheet

The core loop, and the reason for all of the above: tap +, land straight in the
last-used section's sheet with the keypad already up. Type 100 and 10,
optionally name it, save. One save, one batch.

**+ must not open a section picker.** Choosing a section is a tap on the common
path, and the common path is the product. Section switching lives inside the
sheet, for the log that isn't the usual one.

Measure the result in taps and milliseconds, not in whether it looks tidy.

## 4. Export, import, CSV

Rule 6 is unfulfilled until data can leave. `exportData`/`importData` already
exist and are tested; nothing calls them. Import needs an explicit
merge-or-replace choice, since it's the only destructive action in the app.

Deliberately before daily use: it's the escape hatch if anything eats data.

## 5. CI

GitHub Actions build + test on push. Cheap, and the test suite is already good
enough to be worth protecting.

## 6. Use it on a real phone for a week

The step that decides everything after it. Whether logging is genuinely fast,
and what search and pinning should feel like, are not answerable from a
simulator.

## 7. Search and pinning

Designed after the week, not before. Search over entry names; starring a past
entry keeps it around as a one-tap preset. **Presets are named entries you
liked** — not a separate thing you create and maintain.

Call them presets, never *recipes*. See PHILOSOPHY.md.

## 8. App icon and asset catalog

Neither exists. Needed before TestFlight, not before daily use.

## After v1

- [ ] Home screen widget, Lock Screen widget, App Shortcuts / Siri.
- [ ] Sync transport — the document already merges; this is only plumbing.
- [ ] Apple Watch.
