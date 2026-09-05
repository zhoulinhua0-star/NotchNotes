import XCTest
@testable import NotchNotes

final class SystemFileDragProbeTests: XCTestCase {
    func testDragStartsOnlyAfterThePasteboardChangesUnderAHeldButton() {
        var probe = SystemFileDragProbe()

        XCTAssertFalse(probe.update(buttonIsDown: false, changeCount: 7, readFileURLs: { true }))
        XCTAssertFalse(probe.isDragging)

        // Button down, pasteboard untouched: nothing is being dragged yet.
        XCTAssertFalse(probe.update(buttonIsDown: true, changeCount: 7, readFileURLs: { true }))
        XCTAssertFalse(probe.isDragging)

        // The drag session writes its files to the pasteboard.
        XCTAssertTrue(probe.update(buttonIsDown: true, changeCount: 8, readFileURLs: { true }))
        XCTAssertTrue(probe.isDragging)
    }

    func testLeftoverPasteboardContentDoesNotCountAsADrag() {
        var probe = SystemFileDragProbe()
        _ = probe.update(buttonIsDown: false, changeCount: 7, readFileURLs: { true })
        _ = probe.update(buttonIsDown: true, changeCount: 8, readFileURLs: { true })
        XCTAssertTrue(probe.isDragging)

        // Drop finishes; the pasteboard still holds the dragged files.
        XCTAssertTrue(probe.update(buttonIsDown: false, changeCount: 8, readFileURLs: { true }))
        XCTAssertFalse(probe.isDragging)

        // A plain click afterwards must not re-arm the drop target.
        XCTAssertFalse(probe.update(buttonIsDown: true, changeCount: 8, readFileURLs: { true }))
        XCTAssertFalse(probe.isDragging)
    }

    func testNonFileDragIsIgnoredAndReadsThePasteboardOnce() {
        var probe = SystemFileDragProbe()
        _ = probe.update(buttonIsDown: false, changeCount: 1, readFileURLs: { true })

        var reads = 0
        for _ in 0..<5 {
            XCTAssertFalse(probe.update(buttonIsDown: true, changeCount: 2, readFileURLs: {
                reads += 1
                return false
            }))
        }

        XCTAssertFalse(probe.isDragging)
        XCTAssertEqual(reads, 1)
    }

    func testConsecutiveDragsEachRearmTheDropTarget() {
        var probe = SystemFileDragProbe()
        _ = probe.update(buttonIsDown: false, changeCount: 1, readFileURLs: { true })
        _ = probe.update(buttonIsDown: true, changeCount: 2, readFileURLs: { true })
        XCTAssertTrue(probe.isDragging)

        _ = probe.update(buttonIsDown: false, changeCount: 2, readFileURLs: { true })
        XCTAssertFalse(probe.isDragging)

        XCTAssertTrue(probe.update(buttonIsDown: true, changeCount: 3, readFileURLs: { true }))
        XCTAssertTrue(probe.isDragging)
    }
}
