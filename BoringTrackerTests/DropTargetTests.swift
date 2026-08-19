import CoreGraphics
import Foundation
import Testing
@testable import BoringTracker

/// Where settings' drag decides a tracker landed.
///
/// This is geometry, not storage, so it would normally be checked by hand in
/// the simulator — except that it has been wrong twice and passed a hand-run
/// check both times, because a list at rest looks identical whether the drop
/// resolved to the right row or not.
///
/// What these tests pin is the row-picking rule. The band itself is one
/// expression in `SettingsView`, and it is the part that was wrong the second
/// time; `theBandIsNotShrunkByInsetsItAlreadyHad` records what that wrong band
/// did rather than preventing it from coming back.
@Suite("Drop target")
struct DropTargetTests {

    /// Logged out of the running app rather than read off a screenshot: the
    /// `List`'s proxy reports this frame with `safeAreaInsets` of 116 top and 34
    /// bottom, so the frame is already the safe area and 116...840 is the whole
    /// of the visible list. Re-read on an iPhone 17 Pro for item 28 and
    /// unchanged — the rows inside it got shorter, the list did not move.
    let visible = CGRect(x: 0, y: 116, width: 402, height: 724)

    /// The row frames the app actually records — the reordering `HStack`, which
    /// is 44pt tall because the drag handle is, *not* the `List` cell around it.
    ///
    /// **Re-measured for item 28**, which cut a settings row from 74pt to 52 and
    /// left this fixture describing a layout the app can no longer produce.
    /// Printed straight out of `onGeometryChange` by a temporary `NSLog`, on an
    /// iPhone 17 Pro, from two grouped trackers followed by three loose ones:
    /// tops at **160.33, 212.33, 299.33, 386.33, 473.33**, every one 44 tall, so
    /// the middles are 182.33, 234.33, 321.33, 408.33, 495.33. The spacing is
    /// uneven on purpose — **52 between two members of one group, 87 across a
    /// section boundary** — where it used to read 74 and 109/132 on the taller
    /// row.
    func deviceRows() -> [(id: UUID, frame: CGRect)] {
        [160.33, 212.33, 299.33, 386.33, 473.33].map { top in
            (UUID(), CGRect(x: 32, y: top, width: 338, height: 44))
        }
    }

    @Test("A finger on the first row drops on the first row")
    func theFirstRowIsDroppable() {
        let rows = deviceRows()

        // The first row spans 160.33...204.33; 188.3 is 6pt below its middle,
        // about where a finger on the handle sits.
        #expect(dropTarget(at: 188.3, rows: rows, visible: visible) == rows[0].id)
        #expect(dropTarget(at: 182.33, rows: rows, visible: visible) == rows[0].id)
    }

    @Test("The band is the list's frame, not that frame minus insets it already had")
    func theBandIsNotShrunkByInsetsItAlreadyHad() {
        let rows = deviceRows()

        // Adding `insets.top` back to a frame that had already had it taken off
        // turned 116...840 into 232...806. The first row is 160.33...204.33,
        // entirely above that, so it stopped being a candidate and a finger
        // squarely on it resolved to the second row instead. (It was 166...210
        // when the bug was found; item 28's shorter row puts it further above
        // the wrong band, not less.)
        let doubleCounted = CGRect(x: 0, y: 232, width: 402, height: 574)
        #expect(dropTarget(at: 188.3, rows: rows, visible: doubleCounted) == rows[1].id)
        #expect(dropTarget(at: 188.3, rows: rows, visible: visible) == rows[0].id)
    }

    @Test("Dragging past the top edge still means the first row")
    func aboveTheListIsTheFirstRow() {
        let rows = deviceRows()
        #expect(dropTarget(at: 120, rows: rows, visible: visible) == rows[0].id)
        #expect(dropTarget(at: 0, rows: rows, visible: visible) == rows[0].id)
    }

    @Test("A finger on the last row drops on it, and so does one past the end")
    func theLastRowIsDroppable() {
        let rows = deviceRows()
        #expect(dropTarget(at: 495.33, rows: rows, visible: visible) == rows[4].id)
        #expect(dropTarget(at: 800, rows: rows, visible: visible) == rows[4].id)
    }

    @Test("The nearest middle wins, and the boundary sits between two rows")
    func nearestMiddleWins() {
        let rows = deviceRows()
        // The two members of one group, 52 apart — the tightest pair on the
        // screen, and so the one the rule has least room to get right.
        let first = rows[0].frame.midY   // 182.33
        let second = rows[1].frame.midY  // 234.33, the member below it
        let boundary = (first + second) / 2

        #expect(dropTarget(at: boundary - 1, rows: rows, visible: visible) == rows[0].id)
        #expect(dropTarget(at: boundary + 1, rows: rows, visible: visible) == rows[1].id)
        // Exactly halfway resolves upward, because the rows arrive in the order
        // they are drawn and the first one to tie keeps it.
        #expect(dropTarget(at: boundary, rows: rows, visible: visible) == rows[0].id)
    }

    @Test("A row scrolled out of sight is not a drop target")
    func scrolledAwayRowsAreNotCandidates() {
        // Last known frames above and below the band, which is exactly what a
        // scrolled list leaves behind in `rowFrames`.
        let gone: (id: UUID, frame: CGRect) = (UUID(), CGRect(x: 32, y: -200, width: 338, height: 44))
        let below: (id: UUID, frame: CGRect) = (UUID(), CGRect(x: 32, y: 900, width: 338, height: 44))
        let onScreen = deviceRows()
        let all = [gone] + onScreen + [below]

        #expect(dropTarget(at: -180, rows: all, visible: visible) == onScreen[0].id)
        #expect(dropTarget(at: 930, rows: all, visible: visible) == onScreen[4].id)
    }

    @Test("A row straddling the top edge is still a drop target")
    func partiallyVisibleRowsCount() {
        // A row scrolled half out of the band is still half on screen, so it
        // stays a candidate and a drop aimed at the visible half lands on it.
        // Not the first row at rest — `deviceRows()` puts that at 160.33…204.33,
        // wholly inside the band — this is the scrolled case.
        let straddling: (id: UUID, frame: CGRect) = (UUID(), CGRect(x: 32, y: 100, width: 338, height: 44))
        let all = [straddling] + deviceRows()

        #expect(dropTarget(at: 118, rows: all, visible: visible) == straddling.id)
    }

    @Test("Nothing to drop on when nothing is drawn")
    func noRowsMeansNoTarget() {
        #expect(dropTarget(at: 300, rows: [], visible: visible) == nil)
    }
}
