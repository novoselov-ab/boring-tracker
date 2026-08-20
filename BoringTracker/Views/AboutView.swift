import SwiftUI

/// What this app is, what version you have, and where the source is.
///
/// **The outbound links are allowed.** App Review's rule is about external
/// *purchase* mechanisms; linking out to a website is not one, and there is
/// nothing to buy here in any case.
struct AboutView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: Self.version)
            } footer: {
                Text("I wanted to write down 600 calories, 40 protein without scanning a barcode for every ingredient, so I made this. My goal is for it to behave like a built-in iOS app: type a number, done.")
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
                Text("I do not take donations and there is no button for one. Give the money to a charity of your choice instead.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    static let repository = URL(string: "https://github.com/novoselov-ab/boring-tracker")!
    static let privacyPolicy = URL(string: "https://novoselov-ab.github.io/boring-tracker/")!
    static let philosophy = URL(string: "https://github.com/novoselov-ab/boring-tracker/blob/main/docs/PHILOSOPHY.md")!
    static let email = URL(string: "mailto:novoselov.ab@gmail.com")!

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
