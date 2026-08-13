import SwiftUI

/// Your trackers as cards. That's the whole main screen.
struct HomeView: View {
    @Environment(Store.self) private var store
    @AppStorage(LogSheet.lastGroupKey) private var lastGroup = ""
    @State private var logging: LogSheet.Target?
    @State private var path: [Route] = []

    /// Everything reachable from here. An enum rather than a bare `UUID` so
    /// settings can be pushed onto the same stack instead of arriving as a
    /// second sheet over the top of the log sheet.
    enum Route: Hashable {
        case tracker(UUID)
        case settings
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.activeTrackers.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("Boring Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .primaryAction) {
                    // Straight into whatever you logged last, with the keypad
                    // up. No picker in between — that would be a tap on the
                    // common path, every time, forever.
                    Button("Log", systemImage: "plus") {
                        guard let group = store.groupToLog(preferring: lastGroup) else { return }
                        logging = LogSheet.Target(group: group)
                    }
                    .disabled(store.activeTrackers.isEmpty)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .tracker(let id): TrackerDetailView(trackerID: id)
                case .settings: SettingsView()
                }
            }
            .sheet(item: $logging) { target in
                LogSheet(target: target)
            }
        }
    }

    /// A dead end otherwise: with every tracker deleted or archived there is
    /// nothing to log against and nothing on screen that says how to fix that.
    private var empty: some View {
        ContentUnavailableView {
            Label("No trackers", systemImage: "number")
        } description: {
            Text("Add one to start counting whatever you like.")
        } actions: {
            NavigationLink("Add Tracker", value: Route.settings)
                .buttonStyle(.borderedProminent)
        }
    }

    private var list: some View {
        List {
            if let notice = LoadNotice(origin: store.origin, saveError: store.saveError) {
                Section { NoticeRow(notice: notice) }
            }
            // Grouped by section, because a section is the set of trackers
            // logged together and the log sheet is now one of these groups.
            // Real sections rather than the heading rows settings uses: this
            // screen doesn't need a drag between them — that is an
            // organisational move, and settings is where it lives.
            ForEach(store.activeSections, id: \.self) { section in
                let trackers = store.trackers(inSection: section)
                Section {
                    ForEach(trackers) { tracker in
                        TrackerCard(
                            tracker: tracker,
                            open: { path.append(.tracker(tracker.id)) },
                            log: {
                                logging = LogSheet.Target(group: LogGroup(of: tracker),
                                                          tracker: tracker.id)
                            }
                        )
                    }
                    .onMove { offsets, destination in
                        store.move(trackers, fromOffsets: offsets, toOffset: destination)
                    }
                } header: {
                    // The ungrouped trackers get no heading. "No section" is a
                    // true statement nobody needs read back to them, and
                    // without it a home screen with no sections at all looks
                    // exactly as it did before there were any.
                    if !section.isEmpty { Text(section) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

/// A daily total, or the latest reading. The two kinds of tracker are the only
/// real decision in the product, so they are the only real difference here.
private struct TrackerCard: View {
    @Environment(Store.self) private var store
    let tracker: Tracker
    let open: () -> Void
    let log: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // Two plain buttons with disjoint frames rather than a
            // NavigationLink wrapping a button: a link would either swallow the
            // + or leave its chevron stranded in the middle of the card.
            Button(action: open) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(headline)
                        .font(.largeTitle.weight(.medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if let caption {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the history")
            Spacer(minLength: 12)
            Button(action: log) {
                Image(systemName: "plus")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Log \(tracker.name)")
        }
        .padding(.vertical, 6)
    }

    private var headline: String {
        switch tracker.kind {
        case .dailyTotal:
            tracker.format(store.total(for: tracker.id, on: store.today))
        case .measurement:
            store.latestEntry(for: tracker.id).map { tracker.format($0.value) } ?? "—"
        }
    }

    private var caption: String? {
        switch tracker.kind {
        case .dailyTotal:
            nil
        case .measurement:
            store.latestEntry(for: tracker.id).map {
                $0.date.formatted(.relative(presentation: .named))
            }
        }
    }
}

// MARK: - Telling the user when something was wrong with their data

private struct LoadNotice {
    var title: String
    var detail: String

    init?(origin: StoreOrigin, saveError: String?) {
        if let saveError {
            self.title = "Couldn't save"
            self.detail = saveError
            return
        }
        switch origin {
        case .backup:
            title = "Recovered from backup"
            detail = "The store file couldn't be read, so the previous copy was used. "
                + "Anything logged in the last moments before that may be missing."
        case .unreadable(let quarantine):
            title = "Couldn't read your data"
            detail = "The files that wouldn't open were kept at \(quarantine.lastPathComponent) "
                + "and the app started fresh. Nothing was deleted."
        case .file, .fresh:
            return nil
        }
    }
}

private struct NoticeRow: View {
    let notice: LoadNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(notice.title, systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(notice.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let calories = Tracker(name: "Calories", unit: "kcal")
    let weight = Tracker(name: "Weight", unit: "kg", kind: .measurement, decimals: 1, sortIndex: 1)
    let store = Store(
        document: StoreDocument(
            trackers: [calories, weight],
            entries: [
                Entry(trackerID: calories.id, value: 620, date: .now.addingTimeInterval(-7_200)),
                Entry(trackerID: calories.id, value: 415, date: .now.addingTimeInterval(-3_600)),
                Entry(trackerID: weight.id, value: 78.4, date: .now.addingTimeInterval(-86_400)),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview"))
    )
    return HomeView().environment(store)
}
