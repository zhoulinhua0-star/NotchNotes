import AppKit
import SwiftUI
import XCTest
@testable import NotchNotes

@MainActor
final class TransparentHitHostingViewTests: XCTestCase {
    func testTransparentContentRemainsInteractiveInsideBounds() {
        let hostingView = TransparentHitHostingView(rootView: Color.clear)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 36)

        XCTAssertNotNil(hostingView.hitTest(NSPoint(x: 100, y: 18)))
        XCTAssertNil(hostingView.hitTest(NSPoint(x: 201, y: 18)))
    }

    /// `CompactNotchView` no longer carries an explicit frame, so the hosting
    /// view must keep filling the panel for hit testing and file drops to cover
    /// the whole hot zone as it resizes around a drag.
    func testCompactHostingViewFillsThePanelAcrossResizes() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 204, height: 22),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let host = CompactFileDropHostingView(rootView: CompactNotchView())
        host.translatesAutoresizingMaskIntoConstraints = true
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        XCTAssertEqual(host.bounds.size, NSSize(width: 204, height: 22))
        XCTAssertNotNil(host.hitTest(NSPoint(x: 102, y: 11)))

        panel.setFrame(NSRect(x: 0, y: 0, width: 204, height: 62), display: true)

        XCTAssertEqual(host.bounds.size, NSSize(width: 204, height: 62))
        XCTAssertNotNil(host.hitTest(NSPoint(x: 102, y: 50)))
    }
}
