# TODO

Short by design. If it's not here, it's either done or in the "not now"
sections of [PRODUCT.md](PRODUCT.md).

## Next

- [ ] **Settings screen.** There isn't one, so trackers can't be created,
      renamed, archived or reordered — the app is stuck with the two it ships
      with. `Store` already does all of it, none of it is reachable.
- [ ] **Export and import UI.** `exportData`/`importData` exist and are tested;
      nothing calls them. Rule 6 is unfulfilled until data can leave.
- [ ] **CSV export.** Listed in v1 scope, not implemented.
- [ ] **Groups.** A named set of trackers logged together on one sheet, so +
      doesn't open a list of 15. Presets belong to a group.

## Rest of v1

- [ ] **Presets.** Pin a recent value; a pin can set several trackers at once.
      `Pin` exists in the model, nothing uses it. Design after living with the
      basics.
- [ ] **App icon** and an asset catalog. Neither exists.
- [ ] **CI.** GitHub Actions build + test on push, as specified in TECH.md.
- [ ] Use it on a real phone for a week and fix what annoys you.

## After v1

- [ ] Home screen widget, Lock Screen widget, App Shortcuts / Siri.
- [ ] Sync transport — the document already merges; this is only plumbing.
- [ ] Apple Watch.
- [ ] Rename the GitHub repo from `whatever-tracker` to `boring-tracker`.
