import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var panelController: NotchPanelController?
    private var statusItem: NSStatusItem?
    private var keepAwakeStateObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = NotchPanelController()
        panelController?.showDocked()
        buildStatusItem()
        observeKeepAwakeState()
        buildMainMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.flush()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populateAppMenu(menu)
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imagePosition = .imageOnly
        item.menu = makeAppMenu()
        statusItem = item
        updateStatusItemIcon(isKeepingAwake: panelController?.isKeepingAwake == true)
    }

    private func observeKeepAwakeState() {
        keepAwakeStateObservation = panelController?.keepAwakeStatePublisher
            .removeDuplicates()
            .sink { [weak self] isKeepingAwake in
                self?.updateStatusItemIcon(isKeepingAwake: isKeepingAwake)
            }
    }

    private func updateStatusItemIcon(isKeepingAwake: Bool) {
        statusItem?.button?.image = NSImage(
            systemSymbolName: isKeepingAwake ? "tray.full.fill" : "tray.full",
            accessibilityDescription: isKeepingAwake
                ? "NotchNotes File Shelf, Keep Awake On"
                : "NotchNotes File Shelf, Keep Awake Off"
        )
    }

    private func buildMainMenu() {
        let rootItem = NSMenuItem(title: "NotchNotes", action: nil, keyEquivalent: "")
        rootItem.submenu = makeAppMenu()

        let mainMenu = NSMenu()
        mainMenu.addItem(rootItem)
        NSApp.mainMenu = mainMenu
    }

    private func makeAppMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        populateAppMenu(menu)
        return menu
    }

    private func populateAppMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(menuItem(
            title: "Show File Shelf",
            action: #selector(showShelf)
        ))
        menu.addItem(menuItem(
            title: "Add Files or Folders…",
            action: #selector(addFiles),
            keyEquivalent: "o"
        ))

        let clearItem = menuItem(
            title: "Clear Shelf",
            action: #selector(clearShelf)
        )
        clearItem.isEnabled = panelController?.hasShelfItems == true
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let keepAwakeItem = menuItem(
            title: "Keep Mac Awake",
            action: #selector(toggleKeepAwake)
        )
        keepAwakeItem.state = panelController?.isKeepingAwake == true ? .on : .off
        menu.addItem(keepAwakeItem)

        let triggerItem = NSMenuItem(title: "Open Shelf With", action: nil, keyEquivalent: "")
        let triggerMenu = NSMenu(title: "Open Shelf With")
        for mode in TriggerMode.allCases {
            let item = menuItem(
                title: mode.title,
                action: mode == .click ? #selector(useClickTrigger) : #selector(useHoverTrigger)
            )
            item.state = panelController?.triggerMode == mode ? .on : .off
            triggerMenu.addItem(item)
        }
        triggerItem.submenu = triggerMenu
        menu.addItem(triggerItem)

        menu.addItem(.separator())
        menu.addItem(menuItem(
            title: "Quit NotchNotes",
            action: #selector(quit),
            keyEquivalent: "q"
        ))
    }

    private func menuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func showShelf() {
        panelController?.expand(animated: true)
    }

    @objc private func addFiles() {
        panelController?.addFiles()
    }

    @objc private func clearShelf() {
        panelController?.clearShelf()
    }

    @objc private func toggleKeepAwake() {
        panelController?.toggleKeepAwake()
    }

    @objc private func useClickTrigger() {
        panelController?.setTriggerMode(.click)
    }

    @objc private func useHoverTrigger() {
        panelController?.setTriggerMode(.hover)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
