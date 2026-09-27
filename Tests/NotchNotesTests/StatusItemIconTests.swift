import AppKit
import XCTest
@testable import NotchNotes

@MainActor
final class StatusItemIconTests: XCTestCase {
    func testTrayStaysBlackAcrossAppearanceChanges() throws {
        for isKeepingAwake in [false, true] {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            defer { NSStatusBar.system.removeStatusItem(item) }
            let button = try XCTUnwrap(item.button)
            let icon = StatusItemIcon(button: button)
            icon.show(isKeepingAwake: isKeepingAwake)
            let imageView = try XCTUnwrap(button.subviews.compactMap { $0 as? NSImageView }.first)

            for appearance in [
                NSAppearance.Name.aqua, .darkAqua,
                .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua, .aqua
            ] {
                button.appearance = NSAppearance(named: appearance)
                button.layoutSubtreeIfNeeded()
                for highlighted in [false, true] {
                    button.highlight(highlighted)
                    try assertBlackPixels(in: imageView)
                }
            }
        }
    }

    func testToggleSymbolsStayBlackBeforeAndAfterSettling() async throws {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        let icon = StatusItemIcon(button: button)
        icon.show(isKeepingAwake: false)
        let imageView = try XCTUnwrap(button.subviews.compactMap { $0 as? NSImageView }.first)

        for isKeepingAwake in [true, false] {
            icon.show(isKeepingAwake: isKeepingAwake)
            button.appearance = NSAppearance(named: isKeepingAwake ? .darkAqua : .aqua)
            button.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(250))
            try assertBlackPixels(in: imageView)
            try await Task.sleep(for: .milliseconds(1_200))
            try assertBlackPixels(in: imageView)
        }
    }

    private func assertBlackPixels(
        in view: NSImageView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        var visiblePixelCount = 0
        var brightestComponent: CGFloat = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.1 else { continue }
                visiblePixelCount += 1
                brightestComponent = max(
                    brightestComponent, color.redComponent, color.greenComponent, color.blueComponent
                )
            }
        }
        XCTAssertGreaterThan(visiblePixelCount, 10, "The symbol must be visible", file: file, line: line)
        XCTAssertLessThan(brightestComponent, 0.1, "The symbol must stay black", file: file, line: line)
    }
}
