import SwiftUI

@main
struct WhateverTrackerApp: App {

    /// Loaded synchronously, before the first frame. See the launch budget in
    /// docs/TECH.md — an async gate here would flash an empty home screen for
    /// longer than reading the file takes.
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
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
