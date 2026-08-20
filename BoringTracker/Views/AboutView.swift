import SwiftUI

/// What this app is, what version you have, and where the source is.
///
/// **The link is allowed.** App Review's rule is about external *purchase*
/// mechanisms; linking out to a website is not one, and there is nothing to buy
/// here in any case (docs/PHILOSOPHY.md rule 1). It earns its place because for
/// the people who care about this app's promises — no accounts, no telemetry,
/// no server — the source is the only proof any of them are true, which is the
/// argument docs/SHIPPING.md's listing strategy already makes.
///
/// A pushed screen rather than a section on Settings: the version and the
/// promises are read once, and a screen nobody's day runs through should not
/// spend rows on the screen that arranges trackers.
struct AboutView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: Self.version)
            } footer: {
                Text("Boring Tracker keeps every number on this device. No account, no server, no analytics, and nothing to pay for.")
            }

            Section {
                // The sixth action row, and the one item 13e's list forgot. A
                // `Link` draws its label in the environment tint, which is
                // `.primary` here, so without this it is the ordinary label
                // colour with no chevron — pixel-identical to the static
                // *Version* row one section up, on the one row of this screen
                // that goes anywhere.
                Link(destination: Self.repository) {
                    Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .formRowAccent()
            } footer: {
                Text("The whole app is open source. If this project is ever abandoned, the copy you have keeps working, your data exports to a plain readable file, and anyone can fork it.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    static let repository = URL(string: "https://github.com/novoselov-ab/boring-tracker")!

    /// Read from the bundle rather than written here, so it cannot disagree
    /// with what was actually built. The build number is shown beside it
    /// because a bug report naming only "1.0" cannot say which build.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(marketing) (\($0))" } ?? marketing
    }
}

#Preview {
    NavigationStack { AboutView() }
}
