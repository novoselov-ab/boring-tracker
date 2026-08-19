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

/// The other half of a press: how far the fill goes down (docs/TODO.md item 27).
///
/// **The rule is worth pinning because it is a rule and not a ratio.** One
/// scale cannot serve a 292pt pill and a 30pt disc — 0.97 moves the pill's ends
/// 4.4pt and the disc's 0.45, and the disc is half of what item 27 was reported
/// for. So the constant is the travel and the scale is derived, and a later
/// edit that "simplifies" it back to a fixed ratio breaks a control nobody is
/// looking at while looking at another one.
///
/// The sizes here are the ones measured off an iPhone 17 Pro, in points.
@Suite("Accent fill press")
struct AccentFillPressTests {

    private func travel(_ w: CGFloat, _ h: CGFloat) -> CGFloat {
        let scale = AccentFillPress.scale(for: CGSize(width: w, height: h), reduceMotion: false)
        return (max(w, h) - max(w, h) * scale) / 2
    }

    @Test("Every fill's longest edge moves the same two points")
    func constantTravel() {
        // Home's Log pill, the log sheet's Log, the empty screen's Add Tracker,
        // the undo capsule, and any of the four discs.
        for size in [(292.0, 50.0), (52.67, 34.0), (81.67, 28.0), (60.0, 32.0), (30.0, 30.0)] {
            #expect(abs(travel(size.0, size.1) - AccentFillPress.travel) < 0.0001)
        }
    }

    @Test("The pill and the disc need different scales to do that")
    func scalesDiffer() {
        // 0.9863 and 0.8667. Rendered and sampled: the pill goes 876x150 to
        // 864x148 device pixels at 3x, the disc 90x90 to 78x78 — 6px, which is
        // 2pt, off each end of both.
        let pill = AccentFillPress.scale(for: CGSize(width: 292, height: 50), reduceMotion: false)
        let disc = AccentFillPress.scale(for: CGSize(width: 30, height: 30), reduceMotion: false)
        #expect(abs(pill - 0.9863) < 0.0001)
        #expect(abs(disc - 0.8667) < 0.0001)
    }

    @Test("A fill that has not been measured yet is not drawn mid-press")
    func unmeasuredSize() {
        // `visualEffect` runs before the first layout reports a size, and a
        // scale worked out from zero is a control that flashes on appearing.
        #expect(AccentFillPress.scale(for: .zero, reduceMotion: false) == 1)
    }

    @Test("Reduce Motion takes the movement and leaves the colour")
    func reduceMotionDoesNotScale() {
        // The half this cannot see is that `AccentFillBackground` still swaps
        // to `Color.accentFillPressed`, because that is a colour and not a
        // motion — the gate is deliberately on the scale alone. What it does
        // hold is that the gate exists at all: it shipped without one, and the
        // held Log pill measured the same 288x49.3pt with the setting on as
        // with it off.
        for size in [CGSize(width: 292, height: 50), CGSize(width: 30, height: 30)] {
            #expect(AccentFillPress.scale(for: size, reduceMotion: true) == 1)
            #expect(AccentFillPress.scale(for: size, reduceMotion: false) < 1)
        }
    }

    @Test("A fill too short to give up 4pt does not turn inside out")
    func fillShorterThanItsOwnTravel() {
        // `1 - 2 * travel / longest` is zero at 4pt and negative below it, and
        // a negative scale mirrors the fill. Nothing in the app is near this —
        // the smallest is a 30pt disc — but the modifier is documented as what
        // a later fill gets without having to remember it.
        for longest in [0.5, 1, 2, 3, 4] as [CGFloat] {
            let size = CGSize(width: longest, height: longest)
            #expect(AccentFillPress.scale(for: size, reduceMotion: false) == 1)
        }
        // And it starts working again immediately above the boundary rather
        // than being clamped over a range somebody chose.
        #expect(AccentFillPress.scale(for: CGSize(width: 8, height: 8), reduceMotion: false) == 0.5)
    }
}
