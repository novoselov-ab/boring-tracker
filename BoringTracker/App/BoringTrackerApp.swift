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
                // The app's accent, in one place. `.teal` rather than a hex:
                // a system colour is dynamic, so it desaturates itself on
                // black instead of glowing there, and dark mode is where this
                // app is used. `.mint` was the alternative and reads greener
                // than the app's own name — teal is still a quiet blue-green
                // and stays distinguishable from the green/orange the archive
                // swipe already owns.
                //
                // As an environment tint rather than an asset-catalog accent
                // because there is no asset catalog yet (docs/TODO.md item 18),
                // and one modifier that every control already reads beats a
                // catalog entry plus a build setting. The corollary is that
                // nothing may paint with `Color.accentColor`, which resolves
                // from the catalog and would have stayed blue — the places
                // that used it now use the `.tint` shape style, which resolves
                // from here.
                .tint(.teal)
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
