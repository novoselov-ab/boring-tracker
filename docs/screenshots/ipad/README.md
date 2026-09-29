# Boring Tracker 1.1 iPad screenshots

Five dark-mode listing frames, in first-meet order: home, the log sheet, a
value entered, History, and the Weight detail. **Ready to upload** to the
13-inch iPad display slot in App Store Connect.

Each is an opaque PNG at **2064 × 2752 pixels**, no alpha channel. That is
the first accepted portrait size for the iPad 13-inch display in Apple's
*Screenshot specifications* page (App Store Connect help), checked on
2026-09-28, which lists 2064 × 2752 and 2048 × 2732 portrait, says the size
is required for an app that runs on iPad, and refuses alpha. The 13-inch
iPad Pro (M5) simulator emits 2064 × 2752 directly, so nothing is scaled or
cropped.

## How they were made

- **Build:** `b908321`, Release, on the iPad Pro 13-inch (M5) simulator,
  iOS 26.3, dark appearance, portrait.
- **No resize handle.** iPadOS 26 draws a resize affordance in the app
  window's bottom-right corner under *Windowed Apps*, and `simctl io
  screenshot` captures it — the drafts these replace all had it. It is the OS,
  not simulator chrome, and it is not drawn under *Full Screen Apps*: switching
  Settings ▸ Multitasking & Gestures to Full Screen Apps removed it from every
  screen, Settings included. Nothing was painted out.
- **Software keyboard.** Hardware keyboard disconnected (I/O ▸ Keyboard), so
  the log sheet shows the floating keypad a person sees. With it connected,
  iPadOS parks a keyboard button in the same bottom-right corner.
- **One minute throughout.** The log sheet's When row shows the real clock and
  no override reaches it, so the status bar is overridden to that minute
  (7:09 PM) and both sheet frames were shot inside it.
- **Invented data.** Eight trackers — Calories and Protein (Food), Weight and
  Body fat (Body), Water, Pushups, Water filter, Dentist — with entries from
  April to the capture day, so the graph, the elapsed readings and History
  are all populated. No user data. It is the 13-inch fixture from the
  2026-09-16 landscape pass, with dates moved forward to the capture day,
  water logged two or three glasses at a time (daily totals unchanged) and
  Pushups counted in reps, to match the iPhone set.
- **Opaque.** `simctl` writes an alpha channel; each frame was re-rendered
  through an opaque `CGContext`, and a pixel compare against the raw capture
  read 0 differing pixels in every file.

## How the handle was shown to be gone

In the bottom-right 160 × 160 pixels of each frame, pixels differing by more
than 8 in any channel from the pixel just left of the box on the same row:
**521 or 522 in each of the five drafts, 0 in each of these five.** The
corner was also inspected at full resolution.

`landscape-check-2026-09-16/` is separate evidence from that pass and is not
part of the listing.
