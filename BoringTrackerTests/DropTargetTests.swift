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

    /// Measured on an iPhone 17, logged out of the running app rather than read
    /// off a screenshot: the `List`'s proxy reports this frame with
    /// `safeAreaInsets` of 116 top and 34 bottom, so the frame is already the
    /// safe area and 116...840 is the whole of the visible list.
    let visible = CGRect(x: 0, y: 116, width: 402, height: 724)

    /// The row frames the app actually records — the reordering `HStack`, which
    /// is 44pt tall because the drag handle is, *not* the taller `List` cell
    /// around it. Middles logged from a real drag: 188, 320, 394, 503, 634.7.
    /// The spacing is uneven on purpose: 74 between two members of one group,
    /// 109 to a loose tracker, ~132 across a section header.
    func deviceRows() -> [(id: UUID, frame: CGRect)] {
        [188.0, 320.0, 394.0, 503.0, 634.7].map { middle in
            (UUID(), CGRect(x: 32, y: middle - 22, width: 338, height: 44))
        }
    }

    @Test("A finger on the first row drops on the first row")
    func theFirstRowIsDroppable() {
        let rows = deviceRows()

        // 193.7 is the position logged from a finger resting on the first row's
        // handle, 6pt below its middle.
        #expect(dropTarget(at: 193.7, rows: rows, visible: visible) == rows[0].id)
        #expect(dropTarget(at: 188, rows: rows, visible: visible) == rows[0].id)
    }

    @Test("The band is the list's frame, not that frame minus insets it already had")
    func theBandIsNotShrunkByInsetsItAlreadyHad() {
        let rows = deviceRows()

        // Adding `insets.top` back to a frame that had already had it taken off
        // turned 116...840 into 232...806. The first row is 166...210, entirely
        // above that, so it stopped being a candidate and a finger squarely on
        // it resolved to the second row instead.
        let doubleCounted = CGRect(x: 0, y: 232, width: 402, height: 574)
        #expect(dropTarget(at: 193.7, rows: rows, visible: doubleCounted) == rows[1].id)
        #expect(dropTarget(at: 193.7, rows: rows, visible: visible) == rows[0].id)
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
        #expect(dropTarget(at: 634.7, rows: rows, visible: visible) == rows[4].id)
        #expect(dropTarget(at: 800, rows: rows, visible: visible) == rows[4].id)
    }

    @Test("The nearest middle wins, and the boundary sits between two rows")
    func nearestMiddleWins() {
        let rows = deviceRows()
        let second = rows[1].frame.midY  // 320, first member of a group
        let third = rows[2].frame.midY   // 394, the member below it
        let boundary = (second + third) / 2

        #expect(dropTarget(at: boundary - 1, rows: rows, visible: visible) == rows[1].id)
        #expect(dropTarget(at: boundary + 1, rows: rows, visible: visible) == rows[2].id)
        // Exactly halfway resolves upward, because the rows arrive in the order
        // they are drawn and the first one to tie keeps it.
        #expect(dropTarget(at: boundary, rows: rows, visible: visible) == rows[1].id)
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
        // Half under the navigation bar is half on screen, and it is the row a
        // finger at the top edge is aiming at.
        let straddling: (id: UUID, frame: CGRect) = (UUID(), CGRect(x: 32, y: 100, width: 338, height: 44))
        let all = [straddling] + deviceRows()

        #expect(dropTarget(at: 118, rows: all, visible: visible) == straddling.id)
    }

    @Test("Nothing to drop on when nothing is drawn")
    func noRowsMeansNoTarget() {
        #expect(dropTarget(at: 300, rows: [], visible: visible) == nil)
    }
}
