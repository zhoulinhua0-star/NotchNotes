import AppKit
import XCTest
@testable import NotchNotes

@MainActor
final class StatusItemIconTests: XCTestCase {
    func testRestingTrayIsTheButtonsTemplateImage() throws {
        for isKeepingAwake in [false, true] {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            defer { NSStatusBar.system.removeStatusItem(item) }
            let button = try XCTUnwrap(item.button)
            let icon = StatusItemIcon(button: button)
            icon.show(isKeepingAwake: isKeepingAwake)

            try assertResting(button, isKeepingAwake: isKeepingAwake)
        }
    }

    func testToggleAnimatesInTheMenuBarColorThenSettlesOnTheTemplate() async throws {
        try XCTSkipIf(
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            "Toggles do not animate while Reduce Motion is on"
        )
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        let icon = StatusItemIcon(button: button)
        icon.show(isKeepingAwake: false)

        for (isKeepingAwake, appearance) in [(true, NSAppearance.Name.darkAqua), (false, .aqua)] {
            button.appearance = NSAppearance(named: appearance)
            icon.show(isKeepingAwake: isKeepingAwake)
            button.layoutSubtreeIfNeeded()

            try await Task.sleep(for: .milliseconds(250))
            let overlay = try XCTUnwrap(overlay(in: button))
            XCTAssertFalse(overlay.isHidden, "The toggle must play in the overlay")
            XCTAssertFalse(button.image?.isTemplate ?? true, "The button tray must hide during the toggle")
            let brightness = try averageBrightness(of: overlay)
            if appearance == .darkAqua {
                XCTAssertGreaterThan(brightness, 0.9, "The overlay must be white on a dark menu bar")
            } else {
                XCTAssertLessThan(brightness, 0.1, "The overlay must be black on a light menu bar")
            }

            try await Task.sleep(for: .milliseconds(1_200))
            try assertResting(button, isKeepingAwake: isKeepingAwake)
        }
    }

    private func assertResting(
        _ button: NSStatusBarButton,
        isKeepingAwake: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let image = try XCTUnwrap(button.image, file: file, line: line)
        XCTAssertTrue(image.isTemplate, "The resting tray must be a template", file: file, line: line)
        let expected = try XCTUnwrap(NSImage(
            systemSymbolName: isKeepingAwake ? "tray.full.fill" : "tray.full",
            accessibilityDescription: nil
        ))
        XCTAssertEqual(image.tiffRepresentation, expected.tiffRepresentation, file: file, line: line)
        if let overlay = overlay(in: button) {
            XCTAssertTrue(overlay.isHidden, "The overlay must hide at rest", file: file, line: line)
            XCTAssertNil(overlay.image, file: file, line: line)
        }
    }

    private func overlay(in button: NSStatusBarButton) -> NSImageView? {
        button.subviews.compactMap { $0 as? NSImageView }.first
    }

    private func averageBrightness(
        of view: NSImageView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> CGFloat {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds), file: file, line: line)
        view.cacheDisplay(in: view.bounds, to: bitmap)
        var visiblePixelCount = 0
        var totalBrightness: CGFloat = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.5 else { continue }
                visiblePixelCount += 1
                totalBrightness += (color.redComponent + color.greenComponent + color.blueComponent) / 3
            }
        }
        XCTAssertGreaterThan(visiblePixelCount, 10, "The symbol must be visible", file: file, line: line)
        return visiblePixelCount == 0 ? 0 : totalBrightness / CGFloat(visiblePixelCount)
    }
}
