import SwiftUI

/// Light, dark, or whatever the system is doing.
///
/// **UI state, so it lives in `UserDefaults` and not in the document.** Nothing
/// about which colours a phone draws belongs in `store.json`: it would export,
/// it would merge, and it would arrive on the other device as an edit — so
/// choosing dark on the iPad would darken the phone the next time the two were
/// reconciled, over a setting the phone's owner had already made.
enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    static let key = "appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// `nil` means "do not override", which is exactly what following the system
    /// is.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
