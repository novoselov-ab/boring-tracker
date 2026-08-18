import SwiftUI

/// Light, dark, or whatever the system is doing.
///
/// **UI state, so it lives in `UserDefaults` and not in the document**
/// (docs/TODO.md). Nothing about which colours a phone draws belongs in
/// `store.json`: it would export, it would merge, and it would arrive on the
/// other device as an edit — so choosing dark on the iPad would darken the
/// phone the next time the two were reconciled, over a setting the phone's
/// owner had already made. It is also not data anyone would want back after a
/// restore.
///
/// iOS has a per-app appearance setting of its own, three taps into Settings.
/// This is the same switch where the app already is, which is where somebody
/// deciding they want it dark actually is.
enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    /// The `UserDefaults` key, named here so the app and the picker cannot
    /// disagree about it — the same thing `LogSheet.lastGroupKey` does.
    static let key = "appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// What `preferredColorScheme` wants: `nil` means "do not override", which
    /// is exactly what following the system is.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
