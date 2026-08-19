import Testing
import UIKit
@testable import BoringTracker

/// The accent is two colour sets of two hand-picked bytes per channel — the
/// fill since item 18, its pressed value since item 26 — and nothing else in
/// the suite would notice if any half went missing.
///
/// **A colour set is the one kind of source file that fails silently.** Rename
/// the folder, mistype the name in `Color.accentFill`, drop the dark entry, or
/// let the catalog fall out of the target, and there is no compiler error and no
/// crash — `UIColor(named:)` returns `nil` and SwiftUI renders the accent as
/// nothing at all. That is exactly the "half-migrated accent" item 18 warned
/// against, and it would ship looking like a layout bug rather than a colour
/// one.
///
/// So this pins the four values that were measured, not merely that a colour
/// resolves. The numbers behind them are in `Color.accentFill` and
/// `Color.accentFillPressed`.
///
/// The disabled fill has no test beside these on purpose: it is
/// `Color(.systemGray2)`, a system colour that cannot go missing by a rename
/// or a target membership, which is the failure this suite exists for.
@Suite("Accent colour set")
struct AccentTests {

    /// Resolved through `UIColor`, because that is the layer that reads the
    /// catalog. A `Color` cannot be asked what it resolves to without a
    /// rendering environment.
    private func component(_ name: String, _ style: UIUserInterfaceStyle) -> (Int, Int, Int)? {
        guard let colour = UIColor(named: name) else { return nil }
        let resolved = colour.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        let byte = { (value: CGFloat) in Int((value * 255).rounded()) }
        return (byte(red), byte(green), byte(blue))
    }

    @Test("The light value is the darkened mint, not the system one")
    func lightValue() {
        // #009888. The system mint is #00C8B3 in light and measures 2.05:1 as a
        // bar glyph and 2.12:1 as a form row foreground, both under the 3:1
        // floor; this measures 3.48 and 3.59.
        #expect(component("AccentFill", .light).map { $0 == (0x00, 0x98, 0x88) } == true)
    }

    @Test("The dark value is the system mint's own byte, unchanged")
    func darkValue() {
        // #00DAC3, which is what `Color(.systemMint)` rendered before the colour
        // set existed. Dark mode is the appearance this app is used in and it
        // was settled by measurement in item 13f; item 18 was not allowed to
        // move it.
        #expect(component("AccentFill", .dark).map { $0 == (0x00, 0xDA, 0xC3) } == true)
    }

    @Test("The pressed light value is the fill at 75% over white")
    func lightPressedValue() {
        // #40B2A6, which is what a `.plain` press already composited on this
        // screen: #009888 at 75% over #FFFFFF, to the byte. Named so the
        // prominent button can be given the same value, since iOS lightened
        // that one instead (docs/TODO.md item 26).
        #expect(component("AccentFillPressed", .light).map { $0 == (0x40, 0xB2, 0xA6) } == true)
    }

    @Test("The pressed dark value is the fill at 75% over the card")
    func darkPressedValue() {
        // #07AA9A: #00DAC3 at 75% over the card's #1C1C1E. Dark is the half
        // that was broken — iOS drew the prominent Log button #33E1CF pressed,
        // 1.08:1 against rest and *lighter*, while every other accent fill on
        // the screen darkened.
        #expect(component("AccentFillPressed", .dark).map { $0 == (0x07, 0xAA, 0x9A) } == true)
    }

    /// The one name that must *not* be in the catalog.
    ///
    /// A colour set called `AccentColor` is picked up by the build as the app's
    /// global accent, which restores the inherited tint item 13c removed and
    /// `BoringTrackerApp` pins to `.primary` — by filename, with nothing in any
    /// Swift file changing. See the note on `Color.accentFill`.
    @Test("Nothing claims the magic AccentColor name")
    func noGlobalAccent() {
        #expect(UIColor(named: "AccentColor") == nil)
    }
}
