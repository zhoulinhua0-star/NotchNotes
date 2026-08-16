import AppKit
import XCTest
@testable import NotchNotes

final class HoverActivationPolicyTests: XCTestCase {
    func testHoverFrameWidensWithoutMovingOffScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let compact = NSRect(x: 618, y: 838, width: 204, height: 62)

        let frame = HoverActivationPolicy.frame(around: compact, within: screen)

        XCTAssertEqual(frame.width, 360)
        XCTAssertEqual(frame.midX, compact.midX)
        XCTAssertEqual(frame.height, compact.height)
        XCTAssertTrue(screen.contains(frame))
    }
}
