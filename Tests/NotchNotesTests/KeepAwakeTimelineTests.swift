import XCTest
@testable import NotchNotes

final class KeepAwakeTimelineTests: XCTestCase {
    private let timeline = KeepAwakeTimeline(columns: 14)

    func testNoCellsLightWhileKeepAwakeIsOff() {
        XCTAssertEqual(timeline.filledCells(elapsed: nil), 0)
    }

    func testCurrentTenMinutesCountsAsALitCell() {
        XCTAssertEqual(timeline.filledCells(elapsed: 0), 1)
        XCTAssertEqual(timeline.filledCells(elapsed: 599), 1)
        XCTAssertEqual(timeline.filledCells(elapsed: 600), 2)
        XCTAssertEqual(timeline.filledCells(elapsed: 84 * 60), 9)
    }

    func testClockSkewBeforeStartIsTreatedAsJustStarted() {
        XCTAssertEqual(timeline.filledCells(elapsed: -30), 1)
        XCTAssertEqual(KeepAwakeTimeline.readout(elapsed: -30), "0m")
    }

    func testLongSessionsStopAtGridCapacity() {
        XCTAssertEqual(timeline.capacity, 42)
        XCTAssertEqual(timeline.filledCells(elapsed: 24 * 3600), 42)
    }

    func testFrameCoversEveryColumnWithALitCell() {
        XCTAssertEqual(timeline.framedColumns(filledCells: 0), 0)
        XCTAssertEqual(timeline.framedColumns(filledCells: 1), 1)
        XCTAssertEqual(timeline.framedColumns(filledCells: 3), 1)
        XCTAssertEqual(timeline.framedColumns(filledCells: 4), 2)
    }

    func testReadoutShowsHoursAndMinutes() {
        XCTAssertEqual(KeepAwakeTimeline.readout(elapsed: 59), "0m")
        XCTAssertEqual(KeepAwakeTimeline.readout(elapsed: 12 * 60), "12m")
        XCTAssertEqual(KeepAwakeTimeline.readout(elapsed: 3600), "1h 0m")
        XCTAssertEqual(KeepAwakeTimeline.readout(elapsed: 84 * 60 + 59), "1h 24m")
        XCTAssertEqual(KeepAwakeTimeline.readout(elapsed: 10 * 3600), "10h 0m")
    }
}
