import AppKit
import Symbols

/// Draws the menu bar symbol in an NSImageView layered over the status button,
/// because NSStatusBarButton cannot play SF Symbol effects itself.
@MainActor
final class StatusItemIcon {
    private let button: NSStatusBarButton
    private let imageView = PassthroughImageView()
    private var isKeepingAwake: Bool?
    private var settleTask: Task<Void, Never>?

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
        settleTask?.cancel()

        let tray = Self.symbol(isKeepingAwake ? "tray.full.fill" : "tray.full")
        updateButton(tray: tray, isKeepingAwake: isKeepingAwake)

        guard let previous, previous != isKeepingAwake,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            imageView.image = tray
            return
        }

        let cup = Self.symbol(isKeepingAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
        if isKeepingAwake {
            imageView.setSymbolImage(cup, contentTransition: .replace.upUp)
            imageView.addSymbolEffect(.bounce.up, options: .repeat(2))
        } else {
            imageView.setSymbolImage(cup, contentTransition: .replace.downUp)
        }

        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(isKeepingAwake ? 900 : 450))
            guard !Task.isCancelled, let self else { return }
            self.imageView.setSymbolImage(
                tray,
                contentTransition: isKeepingAwake ? .replace.upUp : .replace.downUp
            )
        }
    }

    private func updateButton(tray: NSImage, isKeepingAwake: Bool) {
        // A transparent placeholder keeps the status item sized exactly like the symbol.
        button.image = NSImage(size: tray.size, flipped: false) { _ in true }
        button.setAccessibilityLabel(
            isKeepingAwake
                ? "NotchNotes File Shelf, Keep Awake On"
                : "NotchNotes File Shelf, Keep Awake Off"
        )
    }

    private static func symbol(_ name: String) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        image.isTemplate = true
        return image
    }
}

/// Lets clicks fall through to the status bar button underneath.
private final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
