import SwiftUI

/// Everything logged, newest first. Today is one day section like every other;
/// it merely happens to sort to the top.
struct HistoryView: View {
    @Environment(Store.self) private var store
    @State private var editing: HistoryItem?

    var body: some View {
        let days = days
        Group {
            if days.isEmpty, store.lastDeletion == nil {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "clock",
                    description: Text("Your entries will appear here after you log them.")
                )
            } else {
                List {
                    if store.lastDeletion != nil {
                        Section {
                            HStack {
                                Text(store.lastDeletionCount == 1 ? "Deleted entry" : "Deleted batch")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Undo", action: store.undoLastDeletion)
                            }
                        }
                    }
                    ForEach(days, id: \.day) { group in
                        Section(title(for: group.day)) {
                            ForEach(group.items) { item in
                                HistoryRow(item: item) { editing = item }
                                    .swipeActions(edge: .trailing) {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            if let entry = item.entries.first {
                                                store.deleteBatch(containing: entry)
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { item in
            BatchEditor(item: item)
        }
    }

    private struct DayGroup {
        var day: DayKey
        var items: [HistoryItem]
    }

    private var days: [DayGroup] {
        var groups: [DayKey: [HistoryItem]] = [:]
        for item in store.historyItems {
            groups[DayKey(item.date, calendar: store.calendar), default: []].append(item)
        }
        return groups.sorted { $0.key > $1.key }.map { DayGroup(day: $0.key, items: $0.value) }
    }

    private func title(for day: DayKey) -> String {
        if day == store.today { return "Today" }
        if day == store.today.adding(days: -1, calendar: store.calendar) { return "Yesterday" }
        let start = day.startOfDay(calendar: store.calendar)
        return if day.year == store.today.year {
            start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        } else {
            start.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }
}

private struct HistoryRow: View {
    @Environment(Store.self) private var store
    let item: HistoryItem
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    if let name {
                        Text(name)
                        Text(values)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(values)
                    }
                }
                Spacer(minLength: 8)
                Text(item.date.formatted(date: .omitted, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(item.entries.count == 1 ? "Edits this entry" : "Edits this batch")
    }

    private var name: String? {
        let names = Set(item.entries.compactMap { entry in
            entry.name.flatMap { $0.isEmpty ? nil : $0 }
        })
        if names.count > 1 { return "Mixed names" }
        return names.first
    }

    private var values: String {
        let trackers = Dictionary(store.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let units = item.entries.compactMap { trackers[$0.trackerID]?.unit }
        return item.entries
            .sorted { lhs, rhs in
                let left = trackers[lhs.trackerID]?.sortIndex ?? .max
                let right = trackers[rhs.trackerID]?.sortIndex ?? .max
                return (left, lhs.trackerID, lhs.id) < (right, rhs.trackerID, rhs.id)
            }
            .map { entry in
                guard let tracker = trackers[entry.trackerID] else {
                    return "Deleted tracker: \(entry.value.formatted())"
                }
                let needsName = tracker.unit.isEmpty || units.count(where: { $0 == tracker.unit }) > 1
                return needsName
                    ? "\(tracker.name): \(tracker.format(entry.value))"
                    : tracker.format(entry.value)
            }
            .joined(separator: ", ")
    }
}

#Preview {
    let trackers = Tracker.starterSet
    let batch = UUID()
    let store = Store(
        document: StoreDocument(
            trackers: trackers,
            entries: [
                Entry(trackerID: trackers[0].id, value: 100, name: "chicken rice", batchID: batch),
                Entry(trackerID: trackers[1].id, value: 10, name: "chicken rice", batchID: batch),
            ]
        ),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-history"))
    )
    return NavigationStack { HistoryView().environment(store) }
}
