import Testing
import UIKit
@testable import BoringTracker

/// The accent is two hand-picked bytes per channel in an asset catalog since
/// item 18, and nothing else in the suite would notice if either half went
/// missing.
///
/// **A colour set is the one kind of source file that fails silently.** Rename
/// the folder, mistype the name in `Color.accentFill`, drop the dark entry, or
/// let the catalog fall out of the target, and there is no compiler error and no
/// crash — `UIColor(named:)` returns `nil` and SwiftUI renders the accent as
/// nothing at all. That is exactly the "half-migrated accent" item 18 warned
/// against, and it would ship looking like a layout bug rather than a colour
/// one.
///
/// So this pins the two values that were measured, not merely that a colour
/// resolves. The numbers behind them are in `Color.accentFill`.
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
