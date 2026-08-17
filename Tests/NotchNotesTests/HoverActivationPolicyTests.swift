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

    func testSuppressionBlocksHoverUntilTheGateResumes() {
        var gate = HoverActivationGate()

        gate.suppress()

        XCTAssertFalse(gate.shouldActivate(at: 10, pointerIsInside: true))
        gate.resume(at: 10, pointerIsInside: false)
        XCTAssertFalse(gate.shouldActivate(at: 10.2, pointerIsInside: true))
    }

    func testPointerMustExitAfterReturningInsideTheTrigger() {
        var gate = HoverActivationGate()
        gate.suppress()
        gate.resume(at: 10, pointerIsInside: true)

        XCTAssertFalse(gate.shouldActivate(at: 11, pointerIsInside: true))
        XCTAssertFalse(gate.shouldActivate(at: 11, pointerIsInside: false))
        XCTAssertTrue(gate.shouldActivate(at: 11.1, pointerIsInside: true))
    }

    func testEnteringDuringCooldownAlsoRequiresAFreshEntry() {
        var gate = HoverActivationGate()
        gate.suppress()
        gate.resume(at: 10, pointerIsInside: false)

        XCTAssertFalse(gate.shouldActivate(at: 10.2, pointerIsInside: true))
        XCTAssertFalse(gate.shouldActivate(at: 11, pointerIsInside: true))
        XCTAssertFalse(gate.shouldActivate(at: 11, pointerIsInside: false))
        XCTAssertTrue(gate.shouldActivate(at: 11.1, pointerIsInside: true))
    }
}
