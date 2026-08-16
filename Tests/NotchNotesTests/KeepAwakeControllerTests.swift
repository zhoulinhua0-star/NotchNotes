import Foundation
import XCTest
@testable import NotchNotes

final class KeepAwakeControllerTests: XCTestCase {
    func testCommandMatchesCaffeinateDisplayAndIdleAssertions() {
        let command = CaffeinateCommand(appProcessID: 4321)

        XCTAssertEqual(command.executableURL.path, "/usr/bin/caffeinate")
        XCTAssertEqual(command.arguments, ["-di", "-w", "4321"])
    }

    func testCommandDoesNotRequestClosedLidOrAdministratorBehavior() {
        let command = CaffeinateCommand(appProcessID: 7)
        let fullCommand = ([command.executableURL.path] + command.arguments)
            .joined(separator: " ")

        XCTAssertFalse(fullCommand.contains("pmset"))
        XCTAssertFalse(fullCommand.contains("osascript"))
        XCTAssertFalse(command.arguments.contains("-s"))
        XCTAssertFalse(command.arguments.contains("-m"))
    }
}
