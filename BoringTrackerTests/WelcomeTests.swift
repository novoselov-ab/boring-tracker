import Foundation
import Testing
@testable import BoringTracker

/// The screen a fresh install and a cleared install both land on, and the choice
/// it makes on their behalf. See `WelcomeView`.
@MainActor
@Suite("Welcome")
struct WelcomeTests {

    private let utc = calendar("UTC")

    private func makeStore(_ document: StoreDocument = StoreDocument(),
                           file: StoreFile? = nil) -> Store {
        Store(document: document, file: file ?? temporaryStoreFile(),
              calendar: utc, saveWindow: .milliseconds(10))
    }

    // MARK: - When the screen appears

    @Test("A fresh install lands on the welcome screen")
    func freshInstallIsBlank() {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }

        #expect(makeStore(file.load().document, file: file).isBlank)
    }

    @Test("Clearing everything comes back to the welcome screen")
    func clearAllReturnsToWelcome() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let store = makeStore(StoreDocument(trackers: StarterTracker.defaultTrackers()),
                              file: file)
        _ = store.add(Entry(trackerID: store.trackers[0].id, value: 600))
        #expect(!store.isBlank)

        try await store.clearAll()

        #expect(store.isBlank)
        // And it survives the relaunch, which is the state the screen is really
        // keyed on: the file, not a flag beside it.
        #expect(file.load().document.isEmpty)
    }

    @Test("Deleting your last tracker by hand does not")
    func deletingTheLastTrackerLeavesTheOrdinaryEmptyState() {
        let store = makeStore(StoreDocument(trackers: StarterTracker.defaultTrackers()))
        for tracker in store.trackers { store.delete(tracker) }

        #expect(store.activeTrackers.isEmpty)
        // The tombstones are the difference. Without them this would be a fresh
        // install, and the welcome screen would reappear at somebody who has been
        // using the app for a year.
        #expect(!store.isBlank)
    }

    // MARK: - What it offers

    @Test("The offered set introduces the last-time kind")
    func offersALastTimeTracker() {
        #expect(StarterTracker.offered.contains { $0.kind == .lastTime })
    }

    @Test("Skipping — starting without touching anything — gives the pre-1.1 three")
    func defaultsAreTheOldStarterSet() {
        let trackers = StarterTracker.defaultTrackers()

        #expect(trackers.map(\.name) == ["Calories", "Protein", "Weight"])
        #expect(trackers.map(\.kind) == [.dailyTotal, .dailyTotal, .measurement])
        #expect(trackers.map(\.group) == ["Food", "Food", "Weight"])
        #expect(trackers.map(\.sortIndex) == [0, 1, 2])
    }

    @Test("Ticking one more keeps the list's order, not the order they were ticked in")
    func chosenTrackersKeepTheOfferedOrder() {
        let chosen: Set<StarterTracker.ID> = ["Water filter", "Calories"]
        let trackers = StarterTracker.trackers(chosen, units: .metric)

        #expect(trackers.map(\.name) == ["Calories", "Water filter"])
        #expect(trackers.map(\.sortIndex) == [0, 1])
    }

    @Test("A last-time tracker is created with no unit, in either system")
    func lastTimeHasNoUnit() {
        for system in UnitSystem.allCases {
            let filter = StarterTracker.trackers(["Water filter"], units: system)
            #expect(filter.map(\.unit) == [""])
        }
    }

    // MARK: - Units

    @Test("The chosen unit system reaches the trackers that get created")
    func unitSystemReachesTheTrackers() {
        let metric = StarterTracker.defaultTrackers(units: .metric)
        let imperial = StarterTracker.defaultTrackers(units: .imperial)

        #expect(metric.first { $0.name == "Weight" }?.unit == "kg")
        #expect(imperial.first { $0.name == "Weight" }?.unit == "lb")
        // A kcal is a kcal: only what actually differs is switched.
        #expect(metric.map(\.unit).dropLast() == imperial.map(\.unit).dropLast())
    }

    @Test("Starting writes the chosen units through the store and onto disk")
    func startedTrackersPersistTheirUnits() async {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let store = makeStore(file: file)

        for tracker in StarterTracker.defaultTrackers(units: .imperial) {
            store.add(tracker)
        }
        await store.flush()

        #expect(store.trackers.map(\.name) == ["Calories", "Protein", "Weight"])
        #expect(!store.isBlank)
        #expect(file.load().document.trackers.first { $0.name == "Weight" }?.unit == "lb")
    }

    @Test("The unit system is offered from the region, not imposed",
          arguments: [("en_US", UnitSystem.imperial), ("en_GB", .imperial),
                      ("de_DE", .metric), ("ru_RU", .metric), ("ja_JP", .metric)])
    func preferredUnitSystemFollowsTheLocale(identifier: String, expected: UnitSystem) {
        #expect(UnitSystem.preferred(Locale(identifier: identifier)) == expected)
    }
}
