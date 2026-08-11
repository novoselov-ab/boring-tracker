import SwiftUI

/// Your trackers as cards. That's the whole main screen.
struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var logging: LogSheet.Target?

    var body: some View {
        NavigationStack {
            Group {
                if store.activeTrackers.isEmpty {
                    ContentUnavailableView(
                        "No trackers",
                        systemImage: "number",
                        description: Text("Add one to start counting whatever you like.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Whatever")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Log", systemImage: "plus") {
                        logging = LogSheet.Target(tracker: store.activeTrackers.first?.id)
                    }
                    .disabled(store.activeTrackers.isEmpty)
                }
            }
            .sheet(item: $logging) { target in
                LogSheet(target: target)
            }
        }
    }

    private var list: some View {
        List {
            if let notice = LoadNotice(origin: store.origin, saveError: store.saveError) {
                Section { NoticeRow(notice: notice) }
            }
            Section {
                ForEach(store.activeTrackers) { tracker in
                    TrackerCard(tracker: tracker) {
                        logging = LogSheet.Target(tracker: tracker.id)
                    }
                }
                .onMove { offsets, destination in
                    store.move(fromOffsets: offsets, toOffset: destination)
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
    let log: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
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
