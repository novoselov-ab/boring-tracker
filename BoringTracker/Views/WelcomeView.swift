import SwiftUI

/// The screen an app with nothing in it shows: pick the units, tick what to
/// track, start.
///
/// **It is the empty state, not an onboarding flow.** There is no flag saying it
/// has been seen and no step after it — `HomeView` draws it whenever the document
/// is completely empty, which is a fresh install and a "Delete All Data" and
/// nothing else (`Store.isBlank`). That is what makes those two agree, and it is
/// why the screen keeps home's own navigation bar: Settings and History are still
/// there, so it gates nothing.
struct WelcomeView: View {
    @Environment(Store.self) private var store
    @State private var units = UnitSystem.preferred()
    @State private var chosen = StarterTracker.preselected

    var body: some View {
        List {
            if let notice = LoadNotice(origin: store.origin, saveError: store.saveError) {
                Section { NoticeRow(notice: notice) }
            }

            Section {
                Picker("Units", selection: $units) {
                    ForEach(UnitSystem.allCases) { system in
                        Text(system.label).tag(system)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                // The segmented style drops the picker's own label, as in Settings.
                Text("Units")
            } footer: {
                Text("Only what the trackers below start with. Every unit is a word you can change later.")
            }

            Section {
                ForEach(StarterTracker.offered) { offer in
                    row(offer)
                }
            } header: {
                Text("Start with")
            } footer: {
                Text("Nothing is set up yet. You can add, rename and delete trackers whenever you like.")
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .safeAreaInset(edge: .bottom, spacing: 0) { startBar }
    }

    private func row(_ offer: StarterTracker) -> some View {
        let isChosen = chosen.contains(offer.id)
        return Button {
            if isChosen { chosen.remove(offer.id) } else { chosen.insert(offer.id) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.name)
                        .foregroundStyle(.primary)
                    Text(describe(offer))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentFill)
                    // Drawn at zero rather than removed, so ticking a row does
                    // not change the width its name is laid out in.
                    .opacity(isChosen ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// What the tracker will be, in the words its editor uses.
    private func describe(_ offer: StarterTracker) -> String {
        let unit = offer.unit(units)
        return unit.isEmpty ? offer.kind.label : "\(offer.kind.label) · \(unit)"
    }

    /// The one way off this screen, low where a thumb is (docs/PHILOSOPHY.md).
    ///
    /// **Tapping it without reading anything is what "skip" means here**: the
    /// three trackers every install before 1.1 was given, in the region's units.
    /// A Skip that created nothing would land on a screen with no trackers,
    /// which is this screen.
    private var startBar: some View {
        Button {
            for tracker in StarterTracker.trackers(chosen, units: units) {
                store.add(tracker)
            }
        } label: {
            Text("Start")
                .frame(maxWidth: .infinity)
                .onAccentFill()
        }
        .buttonStyle(.accentPill)
        .controlSize(.large)
        .disabled(chosen.isEmpty)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
            .navigationTitle("Boring Tracker")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environment(Store(
        document: StoreDocument(),
        file: StoreFile(directory: URL.temporaryDirectory.appending(path: "preview-welcome"))
    ))
    .tint(.primary)
}
