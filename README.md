# Boring Tracker

[![Build and test](https://github.com/novoselov-ab/boring-tracker/actions/workflows/ci.yml/badge.svg)](https://github.com/novoselov-ab/boring-tracker/actions/workflows/ci.yml)

iPhone app for tracking whatever you want — macros, habits, or any other data.

Free, open source, no ads, no accounts, no subscription, no server, no feature bloat. Type a
number, done.

Most other macro trackers want you to scan a barcode for every ingredient of a dish
you cooked yourself. It takes a lot of time for no benefit. This one just lets you write down `600 calories, 40
protein` and done, as fast as possible, minimum clicks, minimum wait/lag.

You can also use it to track anything you want: your cat weight, pushups, blood glucose, last time you changed a filter.

App is open source and stores everything on your own device, you can always export all your data as json/csv or import it. Is absolutely free, no ads and will never have any. My goal with it to behave like a builtin ios app (e.g. calculator). It is boring, but does its job, hence the name.

## [[Screenshots]]

[[We should add them, here or before or after, not sure what is the best way]]

## [[Features]]

[[here i want to have a list of all the features we have and explaining that it is a minimum required set, contibuitions/issues are accepted, but will be tested against our philosopy here]]

## [[Support/Donations]]

[[I want here to basically say that if you like an app and want to support/donate to developer best way is to donate to a charity of your choice and/or write me an email (is it on github? I can add it here otherwise, whatever is better), leave a review. I would be happy to know it is useful.]]

## Docs

- [Philosophy](docs/PHILOSOPHY.md) — the spirit, and the rules that must not be
  broken.
- [Product](docs/PRODUCT.md) — what the app actually is: the model, the
  screens, the scope.
- [Tech](docs/TECH.md) — how it's built, and why, with the benchmarks behind
  the storage decision.
- [Scale](docs/scale.md) — what five years of use (29,756 entries) does to the
  app, measured screen by screen.
- [Shipping](docs/SHIPPING.md) — Apple accounts, costs, and App Store
  submission.
- [TODO](docs/TODO.md) — the short list of what's left, on the front of a much
  longer record of what was decided and why, including the things that were
  built, measured and reverted.

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

## License

MIT — see [LICENSE](LICENSE). Fork it, build it, ship your own; rule 8 of the
philosophy is that you can.
