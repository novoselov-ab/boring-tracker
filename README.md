# Boring Tracker

iPhone app for tracking whatever you want — macros, habits, or any other data.

Free, open source, no ads, no accounts, no subscription, no server. Type a
number, done.

It's called Boring Tracker because that's the promise: no streaks, no badges,
no confetti, no notifications guilting you back in. It has no opinion about
your body. It just remembers the numbers you give it.

Other macro trackers want you to scan a barcode for every ingredient of a dish
you cooked yourself. This one just lets you write down `600 calories, 40
protein` and get on with your day. And once it does that, it may as well track
your weight, your water, or your cat's weight too.

Because it's open source and stores everything on your own device, it can't be
taken away from you. If this project is ever abandoned, the app you have keeps
working, your data exports to a plain readable file, and anyone can fork the
source and ship it themselves.

## Docs

- [Philosophy](docs/PHILOSOPHY.md) — the spirit, and the rules that must not be
  broken.
- [Product](docs/PRODUCT.md) — what the app actually is: the model, the
  screens, the scope.
- [Tech](docs/TECH.md) — how it's built, and why, with the benchmarks behind
  the storage decision.
- [Shipping](docs/SHIPPING.md) — Apple accounts, costs, and App Store
  submission.

## Building it

You need Xcode 26. Nothing else — no package manager, no dependencies to
fetch, no Apple developer account:

```sh
open BoringTracker.xcodeproj
```

Pick an iPhone simulator and press ⌘R to run, or ⌘U to run the tests. The
`.xcodeproj` is committed so this works on a fresh clone, and the app target
is configured without code signing so the simulator needs no account. Running
on a real iPhone does need one — set your team in Signing & Capabilities.

From a terminal instead:

```sh
xcodebuild test -project BoringTracker.xcodeproj -scheme BoringTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

[`project.yml`](project.yml) is the source of truth for the project, so if you
change it — or add a source file, since it lists them — regenerate with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and commit the result:

```sh
brew install xcodegen && xcodegen generate
```

Your data lives in one JSON file inside the app container. With a simulator
booted and the app installed on it:

```sh
open "$(xcrun simctl get_app_container booted com.novoselov.boringtracker data)/Library/Application Support/boring-tracker"
```

## Status

Early — the design is settled and written down, the app is being built.
