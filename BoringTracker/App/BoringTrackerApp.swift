import SwiftUI

@main
struct BoringTrackerApp: App {

    /// Loaded synchronously, before the first frame. See the launch budget in
    /// docs/TECH.md — an async gate here would flash an empty home screen for
    /// longer than reading the file takes.
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    /// Light, dark or system. `UserDefaults` rather than the document, and read
    /// here rather than in a view, because it has to be applied above every
    /// screen the app has — including the sheets, which are presented outside
    /// the navigation stack. See `Appearance`.
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                // The ordinary label colour, not the accent. A tint is what
                // every standard control *writes* with — a nav bar glyph, a
                // form picker's value, the Undo in a bar — and inheriting the
                // accent there is what item 13c removed.
                //
                // It stays `.primary` even though item 18 fixed the number that
                // first justified it. The accent used to be a single
                // light mint that measured 2.05:1 as a light-mode bar glyph, and
                // the colour set has since given light its own darker value at
                // 3.48:1, so "the accent is illegal as a foreground" is no
                // longer true. What is still true is that a root tint applies
                // itself to controls nobody looked at: it reaches every alert
                // button, every picker value, and whatever standard control
                // arrives next, and it did so twice before by accident. So the
                // accent is a fill named `Color.accentFill`, plus exactly two
                // foreground carve-outs that name themselves — `navBarAccent()`
                // and `formRowAccent()`, both for system chrome that has no
                // other way to say it is tappable.
                //
                // `.primary`, not "no tint at all": the default is the system
                // blue this app deliberately stopped using.
                //
                // The cost is that a tint carries meaning for some standard
                // controls, and `.primary` is a poor answer for those. Measured
                // in review: a `Toggle` under this tint is a solid white capsule
                // in dark mode — white track, white knob, on and off
                // indistinguishable. There is no `Toggle` in the app, and the
                // first one to arrive needs its own `.tint`, the way the nav bar
                // buttons name `navBarAccent()`, the form action rows name
                // `formRowAccent()` and the prominent buttons name
                // `Color.accentFill`. What this rules out is *inheritance*, not
                // colour.
                //
                // The corollary from item 13 still holds and now covers two
                // names: nothing may paint with `Color.accentColor`, and nothing
                // may paint with the `.tint` shape style expecting the accent,
                // because this is what it resolves to. There is an asset catalog
                // since item 18, but the colour set in it is called `AccentFill`
                // and not `AccentColor` precisely so that `Color.accentColor`
                // stays the system blue nothing here draws — a colour set under
                // the magic name would restore the inheritance by its filename.
                .tint(.primary)
                // `nil` for `.system`, which is the absence of an override
                // rather than a third colour scheme — so the app follows the
                // phone, including the phone's own per-app setting, until
                // somebody says otherwise here.
                .preferredColorScheme(appearance.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else {
                store.refreshToday()
                return
            }
            // Leaving the foreground is the one moment worth blocking on: after
            // this the process can be killed without warning.
            Task { await store.flush() }
        }
    }
}
