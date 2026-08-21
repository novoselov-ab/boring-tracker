import SwiftUI

/// What this app is, what version you have, and where the source is.
///
/// **The outbound links are allowed, and so is *Support*.** App Review's rule is
/// about external *purchase* mechanisms, and Apple's donation rule is about
/// collecting money; linking out to a charity collects nothing, and there is
/// nothing to buy here in any case.
struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var offeringSupport = false

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: Self.version)
            } footer: {
                Text("Boring Tracker writes down numbers: calories and protein, your weight, pushups, the last time you changed a filter. Type a number, done. My goal is for it to behave like a built-in iOS app — minimum clicks, minimum wait, and no barcode to scan for a dish you cooked yourself.")
            }

            Section {
                // A `Link` draws its label in the environment tint, which is
                // `.primary` here, so without `formRowAccent()` it is the
                // ordinary label colour with no chevron — pixel-identical to the
                // static *Version* row one section up.
                Link(destination: Self.privacyPolicy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                .formRowAccent()

                Link(destination: Self.philosophy) {
                    Label("Philosophy", systemImage: "text.book.closed")
                }
                .formRowAccent()

                Link(destination: Self.repository) {
                    Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .formRowAccent()
            } footer: {
                Text("Everything you log stays on this device. No account, no server, no analytics, nothing to pay for. The whole app is open source under the MIT licence.")
            }

            Section {
                Link(destination: Self.email) {
                    Label("Email Me", systemImage: "envelope")
                }
                .formRowAccent()
            } footer: {
                Text("I would be glad to hear the app is useful.")
            }

            Section {
                Link(destination: Self.review) {
                    Label("Leave a Review", systemImage: "star")
                }
                .formRowAccent()

                Button {
                    offeringSupport = true
                } label: {
                    Label("Support", systemImage: "heart")
                }
                .formRowAccent()
            }
            // **An `.alert`, and a `.confirmationDialog` was tried first.**
            // Under iOS 26 a dialog attached to a row in a `List` anchors to
            // that row as a popover rather than rising from the bottom: it came
            // out half the screen wide, wrapped this message over nine lines,
            // and pushed *Cancel* off the bottom edge. Photographed before the
            // swap.
            .alert("Support", isPresented: $offeringSupport) {
                Button("Donate to GiveWell") { openURL(Self.giveWell) }
                Button("Email Me") { openURL(Self.email) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("I really appreciate it, but I would rather you gave the money to a charity — GiveWell is the one I recommend. Emailing me, leaving a review, or sharing the app with someone helps too.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    static let repository = URL(string: "https://github.com/novoselov-ab/boring-tracker")!
    static let privacyPolicy = URL(string: "https://novoselov-ab.github.io/boring-tracker/")!
    static let philosophy = URL(string: "https://github.com/novoselov-ab/boring-tracker/blob/main/docs/PHILOSOPHY.md")!
    static let email = URL(string: "mailto:novoselov.ab@gmail.com")!
    static let giveWell = URL(string: "https://www.givewell.org")!
    static let review = URL(string: "https://apps.apple.com/app/id6803768789?action=write-review")!

    /// Read from the bundle rather than written here, so it cannot disagree with
    /// what was actually built. The build number is shown beside it because a bug
    /// report naming only "1.0" cannot say which build.
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
