import SwiftUI

@main
struct BoringTrackerApp: App {

    /// Loaded synchronously, before the first frame. See the launch budget in
    /// docs/TECH.md — an async gate here would flash an empty home screen for
    /// longer than reading the file takes.
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                // The ordinary label colour, not the accent. A tint is what
                // every standard control *writes* with — a nav bar glyph, a
                // form picker's value, the Undo in a bar — and the accent is a
                // light teal, which on the ordinary background measured 1.95:1
                // in light mode against a 3:1 floor (docs/TODO.md item 13c).
                // Item 13b settled that pairing for the fills by moving the
                // label; there is nothing to move here, because the teal *is*
                // the label. So teal stops being the tint and stays what item
                // 13b made it: a fill, named `Color.accentFill`, applied at the
                // handful of places that genuinely fill something.
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
                // buttons name `navBarAccent()` and the prominent buttons name
                // `Color.accentFill`. What this rules out is *inheritance*, not
                // colour.
                //
                // The corollary from item 13 still holds and now covers two
                // names: nothing may paint with `Color.accentColor`, which
                // resolves from an asset catalog that does not exist yet
                // (item 18) and is still blue, and nothing may paint with the
                // `.tint` shape style expecting teal, because this is what it
                // resolves to.
                .tint(.primary)
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
