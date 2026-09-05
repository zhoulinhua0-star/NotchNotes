import AppKit
import CoreGraphics

struct NotchLayout: Equatable {
    let notchSize: NSSize
    let compactSize: NSSize
    let expandedSize: NSSize
    let compactTopOffset: CGFloat
    let expandedTopOffset: CGFloat
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }

    var isBuiltInDisplay: Bool {
        guard let displayID else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }

    var measuredNotchSize: NSSize {
        guard #available(macOS 12.0, *), safeAreaInsets.top > 0 else {
            return .zero
        }

        guard let leftArea = auxiliaryTopLeftArea, let rightArea = auxiliaryTopRightArea else {
            return .zero
        }

        let notchWidth = frame.width - leftArea.width - rightArea.width
        guard notchWidth > 0, notchWidth < frame.width else {
            return .zero
        }

        return NSSize(width: notchWidth, height: safeAreaInsets.top)
    }
}

@MainActor
enum NotchGeometry {
    /// How far the compact panel reaches below the notch while a system file
    /// drag is in flight, so Finder can enter a destination the cursor can
    /// actually reach. See `NotchPanelController.hotFrame(for:)`.
    static let fileDragOverhang: CGFloat = 28

    /// Extra reach below the menu bar kept at rest on notched displays, where
    /// the cursor is hidden inside the cutout and needs a sliver of visible
    /// target just under it. Displays without a notch need none.
    static let notchedRestingReach: CGFloat = 6

    /// Height of the band no app draws into. On notched displays the menu bar
    /// is exactly as deep as the cutout.
    static func menuBarHeight(for screen: NSScreen?) -> CGFloat {
        if let top = screen?.safeAreaInsets.top, top > 0 {
            return top
        }
        return NSStatusBar.system.thickness
    }

    static func targetScreen() -> NSScreen? {
        NSScreen.screens.first(where: \.isBuiltInDisplay)
            ?? NSScreen.screens.first { $0.measuredNotchSize != .zero }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    static func layout(for screen: NSScreen?) -> NotchLayout {
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let measured = screen?.measuredNotchSize ?? .zero
        let fallbackNotch = NSSize(width: 210, height: 32)
        let notch = measured == .zero ? fallbackNotch : measured

        let compactWidth = min(max(notch.width - 6, 182), 238)
        let compactHeight = min(max(notch.height + 2, 32), 38)
        let expandedWidth = min(max(notch.width + 220, 480), 540, screenFrame.width - 36)
        let expandedHeight = min(max(notch.height + 178, 210), screenFrame.height - 84)

        return NotchLayout(
            notchSize: notch,
            compactSize: NSSize(width: compactWidth, height: compactHeight),
            expandedSize: NSSize(width: expandedWidth, height: expandedHeight),
            compactTopOffset: 0,
            expandedTopOffset: 0
        )
    }
}
