import SwiftUI

@main
struct BoringTrackerApp: App {

    /// Loaded synchronously, before the first frame: an async gate here would
    /// flash an empty home screen for longer than reading the file takes.
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    /// Read here rather than in a view, because it has to be applied above every
    /// screen the app has — including the sheets, which are presented outside
    /// the navigation stack.
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                // **The root tint is the ordinary label colour, and nothing may
                // paint expecting it to be the accent** — not `Color.accentColor`
                // and not the `.tint` shape style. A root tint applies itself to
                // controls nobody looked at: every alert button, every picker
                // value, and whatever standard control arrives next. It did so
                // twice here by accident.
                //
                // So the accent is a fill named `Color.accentFill`, plus exactly
                // two foreground carve-outs that name themselves —
                // `navBarAccent()` and `formRowAccent()`. The asset catalog's
                // colour set is called `AccentFill` and not `AccentColor`
                // precisely so that `Color.accentColor` stays the system blue
                // nothing here draws: a colour set under the magic name would
                // restore the inheritance by its filename.
                //
                // `.primary`, not "no tint at all": the default is that system
                // blue. The cost is that a tint carries meaning for some standard
                // controls — measured in review, a `Toggle` under this tint is a
                // solid white capsule in dark mode, on and off
                // indistinguishable. There is no `Toggle` in the app, and the
                // first one to arrive needs its own `.tint`. What this rules out
                // is *inheritance*, not colour.
                .tint(.primary)
                // `nil` for `.system`, which is the absence of an override rather
                // than a third colour scheme — so the app follows the phone,
                // including the phone's own per-app setting.
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
