import AppKit
import Symbols

/// Shows the menu bar symbol. At rest the tray is the status button's own template
/// image, so the system tints it for light and dark menu bars like every other icon.
/// NSStatusBarButton cannot play SF Symbol effects, so a toggle briefly plays the
/// coffee-cup animation in an NSImageView layered over the button.
@MainActor
final class StatusItemIcon {
    private let button: NSStatusBarButton
    private let imageView = PassthroughImageView()
    private var isKeepingAwake: Bool?
    private var animationTask: Task<Void, Never>?

    init(button: NSStatusBarButton) {
        self.button = button
        imageView.imageScaling = .scaleNone
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setAccessibilityElement(false)
        button.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    /// Shows the tray for the given state. On a real toggle, a coffee cup briefly
    /// stands in for the tray so the change is unmistakable.
    func show(isKeepingAwake: Bool) {
        let previous = self.isKeepingAwake
        self.isKeepingAwake = isKeepingAwake
        animationTask?.cancel()
        button.setAccessibilityLabel(
            isKeepingAwake
                ? "NotchNotes File Shelf, Keep Awake On"
                : "NotchNotes File Shelf, Keep Awake Off"
        )

        guard let previous, previous != isKeepingAwake,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            settle(isKeepingAwake: isKeepingAwake)
            return
        }
        animateToggle(isKeepingAwake: isKeepingAwake)
    }

    private func animateToggle(isKeepingAwake: Bool) {
        let tray = Self.trayTemplate(isKeepingAwake: isKeepingAwake)
        // A transparent placeholder hides the button's own tray while keeping the
        // status item sized exactly like the symbol.
        button.image = NSImage(size: tray.size, flipped: false) { _ in true }

        // The overlay is not drawn by the status bar, so tint it for the menu bar's
        // current appearance instead of relying on template rendering.
        let color = Self.glyphColor(for: button.effectiveAppearance)
        let cup = Self.symbol(isKeepingAwake ? "cup.and.saucer.fill" : "cup.and.saucer", color: color)
        let overlayTray = Self.symbol(Self.trayName(isKeepingAwake: isKeepingAwake), color: color)
        let transition: ReplaceSymbolEffect = isKeepingAwake ? .replace.upUp : .replace.downUp

        if imageView.image == nil {
            // Start from the tray the button was showing so the cup replaces it.
            imageView.image = Self.symbol(Self.trayName(isKeepingAwake: !isKeepingAwake), color: color)
        }
        imageView.isHidden = false
        imageView.setSymbolImage(cup, contentTransition: transition)
        if isKeepingAwake {
            imageView.addSymbolEffect(.bounce.up, options: .repeat(2))
        }

        animationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(isKeepingAwake ? 900 : 450))
            guard !Task.isCancelled, let self else { return }
            self.imageView.setSymbolImage(overlayTray, contentTransition: transition)

            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self.settle(isKeepingAwake: isKeepingAwake)
        }
    }

    /// Puts the tray back on the button without any animation, so the resting
    /// icon never depends on a symbol transition finishing. Transitions can stall
    /// while the menu bar is hidden, e.g. behind a full-screen app.
    private func settle(isKeepingAwake: Bool) {
        imageView.removeAllSymbolEffects(animated: false)
        imageView.image = nil
        imageView.isHidden = true
        button.image = Self.trayTemplate(isKeepingAwake: isKeepingAwake)
    }

    private static func trayName(isKeepingAwake: Bool) -> String {
        isKeepingAwake ? "tray.full.fill" : "tray.full"
    }

    private static func trayTemplate(isKeepingAwake: Bool) -> NSImage {
        let image = NSImage(
            systemSymbolName: trayName(isKeepingAwake: isKeepingAwake),
            accessibilityDescription: nil
        ) ?? NSImage()
        image.isTemplate = true
        return image
    }

    private static func symbol(_ name: String, color: NSColor) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(paletteColors: [color])) ?? NSImage()
        image.isTemplate = false
        return image
    }

    private static func glyphColor(for appearance: NSAppearance) -> NSColor {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .white : .black
    }
}

/// Lets clicks fall through to the status bar button underneath.
private final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
