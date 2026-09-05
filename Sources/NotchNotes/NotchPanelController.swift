import AppKit
import Combine
import SwiftUI

enum HoverActivationPolicy {
    /// Slack on each side of the compact panel that still counts as a hover.
    /// Kept small so the trigger stays within the notch band instead of
    /// reaching out over the tab strip of whatever window sits below.
    static let horizontalMargin: CGFloat = 12

    static func frame(around baseFrame: NSRect, within screenFrame: NSRect) -> NSRect {
        let width = min(baseFrame.width + horizontalMargin * 2, screenFrame.width)
        let proposedX = baseFrame.midX - width / 2
        let x = min(max(proposedX, screenFrame.minX), screenFrame.maxX - width)
        return NSRect(x: x, y: baseFrame.minY, width: width, height: baseFrame.height)
    }
}

struct HoverActivationGate {
    static let resumeCooldown: TimeInterval = 0.45

    private(set) var isSuppressed = false
    private var resumeDeadline: TimeInterval?
    private var requiresPointerExit = false

    mutating func suppress() {
        isSuppressed = true
        resumeDeadline = nil
        requiresPointerExit = false
    }

    mutating func resume(at timestamp: TimeInterval, pointerIsInside: Bool) {
        guard isSuppressed else { return }
        isSuppressed = false
        resumeDeadline = timestamp + Self.resumeCooldown
        requiresPointerExit = pointerIsInside
    }

    mutating func shouldActivate(at timestamp: TimeInterval, pointerIsInside: Bool) -> Bool {
        guard !isSuppressed else { return false }

        if let resumeDeadline, timestamp < resumeDeadline {
            if pointerIsInside {
                requiresPointerExit = true
            }
            return false
        }
        resumeDeadline = nil

        if requiresPointerExit {
            if !pointerIsInside {
                requiresPointerExit = false
            }
            return false
        }

        return pointerIsInside
    }
}

/// Tracks whether a system file drag is currently in flight.
///
/// The drag pasteboard keeps its contents after a drag ends, so its type list
/// alone cannot tell a live drag from the leftovers of the previous one. A real
/// drag session writes to the pasteboard *after* the mouse goes down, so the
/// change count observed while the button was last up acts as the baseline.
struct SystemFileDragProbe {
    private var idleChangeCount: Int?
    private var evaluatedChangeCount: Int?
    private(set) var isDragging = false

    /// - Returns: `true` when `isDragging` changed.
    mutating func update(
        buttonIsDown: Bool,
        changeCount: Int,
        readFileURLs: () -> Bool
    ) -> Bool {
        let wasDragging = isDragging

        guard buttonIsDown else {
            idleChangeCount = changeCount
            evaluatedChangeCount = nil
            isDragging = false
            return isDragging != wasDragging
        }

        guard let idleChangeCount, changeCount != idleChangeCount else {
            isDragging = false
            return isDragging != wasDragging
        }

        if evaluatedChangeCount != changeCount {
            evaluatedChangeCount = changeCount
            isDragging = readFileURLs()
        }
        return isDragging != wasDragging
    }
}

@MainActor
final class NotchPanel: NSPanel {
    var onMouseEvent: ((NSEvent) -> Void)?
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            onEscape?()
            return
        }

        if event.type == .leftMouseDown || event.type == .leftMouseDragged || event.type == .leftMouseUp {
            onMouseEvent?(event)
        }

        super.sendEvent(event)
    }
}

@MainActor
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

@MainActor
class TransparentHitHostingView<Content: View>: FirstMouseHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        // SwiftUI may return nil when every rendered pixel is transparent.
        // Keep the panel's full compact frame interactive without drawing a background.
        return super.hitTest(point) ?? self
    }
}

@MainActor
final class CompactFileDropHostingView<Content: View>: TransparentHitHostingView<Content> {
    var onFileDragTargeted: ((Bool) -> Void)?
    var onFilesDropped: (([URL]) -> Bool)?

    private var isFileDragTargeted = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard supportsFileURLs(sender.draggingPasteboard) else { return [] }
        setFileDragTargeted(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        supportsFileURLs(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setFileDragTargeted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setFileDragTargeted(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        supportsFileURLs(sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { setFileDragTargeted(false) }
        let urls = FileDropPasteboardReader.fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        return onFilesDropped?(urls) ?? false
    }

    private func supportsFileURLs(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: [.fileURL]) != nil
    }

    private func setFileDragTargeted(_ isTargeted: Bool) {
        guard isFileDragTargeted != isTargeted else { return }
        isFileDragTargeted = isTargeted
        onFileDragTargeted?(isTargeted)
    }
}

@MainActor
final class NotchPanelController: NSObject {
    private let settingsStore = AppSettingsStore()
    private let keepAwakeController = KeepAwakeController()
    private let fileShelfStore = FileShelfStore()
    private let workspaceState = NotebookWorkspaceState()
    private let drawerState = DrawerState()
    private let hotPanel: NotchPanel
    private let drawerPanel: NotchPanel
    private var hostingView: NSHostingView<ShelfOnlyView>?
    private var hotHostingView: CompactFileDropHostingView<CompactNotchView>?
    private var mousePollingTimer: Timer?
    private var globalMouseDownMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var isExpanded = false
    private var isRevealedForFileDrag = false
    private var activeMenuTrackingCount = 0
    private var collapseTask: DispatchWorkItem?
    private var hoverActivationGate = HoverActivationGate()
    private var fileDragProbe = SystemFileDragProbe()
    private var isHotFrameExtended = false
    private let dragPasteboard = NSPasteboard(name: .drag)

    override init() {
        hotPanel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        drawerPanel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()
        configurePanel(hotPanel)
        configurePanel(drawerPanel)
        rebuildContent()
        startMousePolling()
        observeScreenChanges()
        observePanelMouseEvents()
        observeGlobalMouseEvents()
        observeMenuTracking()
        observePanelOcclusion()
        observeApplicationActivation()
        observePowerEvents()
    }

    func showDocked() {
        let layout = currentLayout()
        rebuildContent(layout: layout)
        isExpanded = false
        isRevealedForFileDrag = false
        drawerState.isExpanded = false
        drawerState.revealProgress = 0
        hotPanel.setFrame(hotFrame(for: layout), display: true)
        hotPanel.orderFrontRegardless()
        drawerPanel.setFrame(drawerFrame(for: layout), display: true)
        drawerPanel.orderOut(nil)
    }

    func expand(animated: Bool, activate: Bool = true) {
        refreshFileAvailability()
        if isExpanded {
            finishFileDragRevealIfNeeded()
            if activate {
                activateShelf()
            }
            return
        }
        let layout = currentLayout()
        cancelCollapse()
        isExpanded = true
        isRevealedForFileDrag = false
        drawerPanel.setFrame(drawerFrame(for: layout), display: true)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            drawerPanel.makeKeyAndOrderFront(nil)
        } else {
            drawerPanel.orderFrontRegardless()
        }
        hotPanel.orderOut(nil)
        setDrawerExpanded(true, animated: animated)
        guard activate else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self else { return }
            guard self.isExpanded else { return }
            self.activateShelf()
        }
    }

    func collapse(animated: Bool) {
        guard isExpanded else { return }
        isExpanded = false
        isRevealedForFileDrag = false
        workspaceState.isShelfDropTargeted = false
        setDrawerExpanded(false, animated: animated)
        let delay: TimeInterval = animated ? 0.18 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard !self.isExpanded else { return }
            let layout = self.currentLayout()
            self.drawerPanel.orderOut(nil)
            self.hotPanel.setFrame(self.hotFrame(for: layout), display: true)
            self.hotPanel.orderFrontRegardless()
        }
    }

    private func configurePanel(_ panel: NotchPanel) {
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
    }

    private func rebuildContent(layout: NotchLayout? = nil) {
        let layout = layout ?? currentLayout()
        let hotView = CompactNotchView()
        let view = ShelfOnlyView(
            settingsStore: settingsStore,
            keepAwakeController: keepAwakeController,
            fileShelfStore: fileShelfStore,
            workspaceState: workspaceState,
            drawerState: drawerState,
            layout: layout,
            onAddFiles: { [weak self] in
                self?.addFiles()
            }
        )

        if let hotHostingView {
            hotHostingView.rootView = hotView
            configureCompactFileDropCallbacks(hotHostingView)
        } else {
            let host = CompactFileDropHostingView(rootView: hotView)
            configureCompactFileDropCallbacks(host)
            host.translatesAutoresizingMaskIntoConstraints = true
            host.autoresizingMask = [.width, .height]
            host.wantsLayer = true
            host.layer?.masksToBounds = true
            hotPanel.contentView = host
            hotHostingView = host
        }

        if let hostingView {
            hostingView.rootView = view
            return
        }

        let host = FirstMouseHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        host.layer?.masksToBounds = true
        drawerPanel.contentView = host
        hostingView = host
    }

    private func configureCompactFileDropCallbacks(
        _ host: CompactFileDropHostingView<CompactNotchView>
    ) {
        host.onFileDragTargeted = { [weak self] isTargeted in
            self?.handleFileDragTargeted(isTargeted)
        }
        host.onFilesDropped = { [weak self] urls in
            self?.receiveDroppedFiles(urls) ?? false
        }
    }

    private func setDrawerExpanded(_ expanded: Bool, animated: Bool) {
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            drawerState.isExpanded = expanded
            drawerState.revealProgress = expanded ? 1 : 0
            return
        }

        let animation: Animation = expanded
            ? .spring(response: 0.21, dampingFraction: 0.88)
            : .easeOut(duration: 0.16)

        withAnimation(animation) {
            drawerState.isExpanded = expanded
            drawerState.revealProgress = expanded ? 1 : 0
        }
    }

    private func startMousePolling() {
        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(mousePollingTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        mousePollingTimer = timer
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func observePanelMouseEvents() {
        hotPanel.onMouseEvent = { [weak self] event in
            guard let self else { return }
            guard event.type == .leftMouseDown else { return }
            self.expand(animated: true, activate: true)
        }

        drawerPanel.onMouseEvent = { [weak self] event in
            guard let self else { return }
            if event.type == .leftMouseDown {
                NSApp.activate(ignoringOtherApps: true)
                self.drawerPanel.makeKeyAndOrderFront(nil)
            } else if event.type == .leftMouseUp {
                self.workspaceState.isDraggingShelfItem = false
                self.resetFileDropState()
            }
        }

        hotPanel.onEscape = { [weak self] in self?.collapse(animated: true) }
        drawerPanel.onEscape = { [weak self] in self?.collapse(animated: true) }
    }

    private func observeGlobalMouseEvents() {
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      !self.isExpanded,
                      self.settingsStore.triggerMode == .click,
                      self.activationFrame().contains(NSEvent.mouseLocation) else {
                    return
                }
                self.expand(animated: true, activate: true)
            }
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.workspaceState.isDraggingShelfItem = false
                self.resetFileDropState()
                self.finishFileDragRevealIfNeeded()
                let location = NSEvent.mouseLocation
                if self.isExpanded, !self.isPointInExpandedStayRegion(location) {
                    self.collapse(animated: true)
                } else {
                    self.handleMouseLocation(location)
                }
            }
        }
    }

    private func observeMenuTracking() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuTrackingDidBegin),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuTrackingDidEnd),
            name: NSMenu.didEndTrackingNotification,
            object: nil
        )
    }

    private func observePanelOcclusion() {
        for panel in [hotPanel, drawerPanel] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(panelOcclusionStateChanged),
                name: NSWindow.didChangeOcclusionStateNotification,
                object: panel
            )
        }
    }

    private func observePowerEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }

    private func observeApplicationActivation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        let layout = currentLayout()
        cancelCollapse()
        rebuildContent(layout: layout)
        hotPanel.setFrame(hotFrame(for: layout), display: true)
        drawerPanel.setFrame(drawerFrame(for: layout), display: true)
    }

    @objc private func mousePollingTick(_ timer: Timer) {
        updateSystemFileDragTracking()
        handleMouseLocation(NSEvent.mouseLocation)
    }

    @objc private func menuTrackingDidBegin(_ notification: Notification) {
        activeMenuTrackingCount += 1
        cancelCollapse()
    }

    @objc private func menuTrackingDidEnd(_ notification: Notification) {
        activeMenuTrackingCount = max(0, activeMenuTrackingCount - 1)
        guard activeMenuTrackingCount == 0, isExpanded else { return }
        handleMouseLocation(NSEvent.mouseLocation)
    }

    @objc private func panelOcclusionStateChanged(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow else { return }
        let expectedPanel = isExpanded ? drawerPanel : hotPanel
        guard panel === expectedPanel else { return }

        if panel.isVisible, panel.occlusionState.contains(.visible) {
            hoverActivationGate.resume(
                at: ProcessInfo.processInfo.systemUptime,
                pointerIsInside: hoverActivationFrame().contains(NSEvent.mouseLocation)
            )
        } else {
            suppressHoverForWindowManagement()
        }
    }

    @objc private func workspaceWillSleep(_ notification: Notification) {
        keepAwakeController.stop()
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        refreshFileAvailability()
    }

    private func handleMouseLocation(_ point: NSPoint) {
        if !isExpanded,
           !hoverActivationGate.isSuppressed,
           NSEvent.pressedMouseButtons & 1 == 1,
           activationFrame().contains(point),
           FileDropPasteboardReader.containsFileURLs(dragPasteboard) {
            handleFileDragTargeted(true)
            return
        }

        if isExpanded {
            if activeMenuTrackingCount > 0 {
                cancelCollapse()
                return
            }

            if workspaceState.isDraggingShelfItem {
                cancelCollapse()
                return
            }

            if settingsStore.triggerMode == .click {
                cancelCollapse()
                return
            }

            if isPointInExpandedStayRegion(point) {
                cancelCollapse()
            } else {
                scheduleCollapse()
            }
            return
        }

        guard settingsStore.triggerMode == .hover else { return }
        let pointerIsInside = hoverActivationFrame().contains(point)
        guard hoverActivationGate.shouldActivate(
            at: ProcessInfo.processInfo.systemUptime,
            pointerIsInside: pointerIsInside
        ) else {
            return
        }
        if NSEvent.pressedMouseButtons & 1 == 0 {
            expand(animated: true, activate: false)
        }
    }

    private func updateSystemFileDragTracking() {
        let changed = fileDragProbe.update(
            buttonIsDown: NSEvent.pressedMouseButtons & 1 == 1,
            changeCount: dragPasteboard.changeCount,
            readFileURLs: { [dragPasteboard] in
                FileDropPasteboardReader.containsFileURLs(dragPasteboard)
            }
        )
        guard changed else { return }
        setHotFrameExtended(fileDragProbe.isDragging)
    }

    private func setHotFrameExtended(_ extended: Bool) {
        guard isHotFrameExtended != extended else { return }
        isHotFrameExtended = extended

        guard !extended else {
            applyHotFrame()
            return
        }

        // Shrinking runs as the drag ends, so give AppKit a beat to finish its
        // drop callbacks before the dragging destination changes size.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, !self.isHotFrameExtended else { return }
            self.applyHotFrame()
        }
    }

    private func applyHotFrame() {
        hotPanel.setFrame(hotFrame(for: currentLayout()), display: true)
    }

    private func suppressHoverForWindowManagement() {
        hoverActivationGate.suppress()
        cancelCollapse()
        guard isExpanded else { return }

        let layout = currentLayout()
        isExpanded = false
        isRevealedForFileDrag = false
        workspaceState.isShelfDropTargeted = false
        workspaceState.isDraggingShelfItem = false
        drawerState.isExpanded = false
        drawerState.revealProgress = 0
        drawerPanel.orderOut(nil)
        hotPanel.setFrame(hotFrame(for: layout), display: true)
        hotPanel.orderFrontRegardless()
    }

    private func scheduleCollapse() {
        guard collapseTask == nil else { return }
        guard activeMenuTrackingCount == 0 else { return }

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapseTask = nil
            guard self.activeMenuTrackingCount == 0 else { return }
            guard !self.workspaceState.isDraggingShelfItem else { return }
            guard !self.isPointInExpandedStayRegion(NSEvent.mouseLocation) else { return }
            self.collapse(animated: true)
        }

        collapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: task)
    }

    private func cancelCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    private func activationFrame() -> NSRect {
        let frame = hotPanel.frame
        if frame.width > 0, frame.height > 0 {
            return frame
        }
        return hotFrame(for: currentLayout())
    }

    private func hoverActivationFrame() -> NSRect {
        let screenFrame = targetScreen()?.frame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return HoverActivationPolicy.frame(
            around: activationFrame(),
            within: screenFrame
        )
    }

    private func isPointInExpandedStayRegion(_ point: NSPoint) -> Bool {
        let margin: CGFloat = 10
        let triggerFrame = settingsStore.triggerMode == .hover
            ? hoverActivationFrame()
            : activationFrame()
        return drawerPanel.frame.insetBy(dx: -margin, dy: -margin).contains(point)
            || triggerFrame.contains(point)
    }

    private func receiveDroppedFiles(_ urls: [URL]) -> Bool {
        guard fileShelfStore.acceptDrop(urls) else {
            resetFileDropState()
            return false
        }

        resetFileDropState()

        // Do not replace the NSWindow that owns the active dragging destination
        // until AppKit has finished the drop callback and closed its tracking loop.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isExpanded {
                self.finishFileDragRevealIfNeeded()
            } else {
                self.expand(animated: true, activate: false)
            }
        }
        return true
    }

    private func handleFileDragTargeted(_ isTargeted: Bool) {
        let animation: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? nil
            : .spring(response: 0.30, dampingFraction: 0.84)
        withAnimation(animation) {
            workspaceState.isShelfDropTargeted = isTargeted
        }

        if isTargeted {
            revealDrawerForFileDrag()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.finishFileDragRevealIfNeeded()
            }
        }
    }

    private func resetFileDropState() {
        workspaceState.isShelfDropTargeted = false
    }

    private func revealDrawerForFileDrag() {
        guard !isExpanded else { return }

        refreshFileAvailability()
        let layout = currentLayout()
        cancelCollapse()
        isExpanded = true
        isRevealedForFileDrag = true
        drawerPanel.setFrame(drawerFrame(for: layout), display: true)
        drawerPanel.orderFrontRegardless()
        hotPanel.orderFrontRegardless()
        setDrawerExpanded(true, animated: true)
    }

    private func finishFileDragRevealIfNeeded() {
        guard isRevealedForFileDrag else { return }
        isRevealedForFileDrag = false
        hotPanel.orderOut(nil)
        drawerPanel.orderFrontRegardless()
    }

    func flush() {
        keepAwakeController.stop()
    }

    private func refreshFileAvailability() {
        Task { [weak self] in
            guard let self else { return }
            await fileShelfStore.refreshAvailability()
        }
    }

    private func activateShelf() {
        NSApp.activate(ignoringOtherApps: true)
        drawerPanel.makeKeyAndOrderFront(nil)
    }

    var triggerMode: TriggerMode {
        settingsStore.triggerMode
    }

    var isKeepingAwake: Bool {
        keepAwakeController.isKeepingAwake
    }

    var keepAwakeStatePublisher: Published<Bool>.Publisher {
        keepAwakeController.$isKeepingAwake
    }

    var hasShelfItems: Bool {
        !fileShelfStore.items.isEmpty
    }

    func setTriggerMode(_ mode: TriggerMode) {
        settingsStore.triggerMode = mode
    }

    func toggleKeepAwake() {
        keepAwakeController.toggle()
    }

    func clearShelf() {
        fileShelfStore.removeAll()
    }

    func addFiles() {
        expand(animated: true, activate: true)

        let panel = NSOpenPanel()
        panel.title = "Add to File Shelf"
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                _ = self?.fileShelfStore.add(panel.urls)
            }
        }
    }

    private func currentLayout() -> NotchLayout {
        NotchGeometry.layout(for: targetScreen())
    }

    private func targetScreen() -> NSScreen? {
        NotchGeometry.targetScreen()
    }

    private func hotFrame(for layout: NotchLayout) -> NSRect {
        let screen = targetScreen()
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(
            width: layout.compactSize.width,
            height: hotPanelHeight(for: layout, screen: screen)
        )
        return frame(for: size, topY: screenFrame.maxY + layout.compactTopOffset, in: screenFrame)
    }

    /// The compact panel sits above the frontmost window, so every point it
    /// covers is a click that window never sees — the top of a browser's tab
    /// strip, for one. At rest it therefore stays inside the menu bar band,
    /// where no app draws. The physical notch is not a reliable pointer target
    /// either, so Finder needs a dragging destination that reaches well below
    /// it, but only while a drag is actually in flight.
    private func hotPanelHeight(for layout: NotchLayout, screen: NSScreen?) -> CGFloat {
        guard !isHotFrameExtended else {
            return layout.compactSize.height + NotchGeometry.fileDragOverhang
        }

        let reach = screen?.measuredNotchSize == .zero ? 0 : NotchGeometry.notchedRestingReach
        return min(layout.compactSize.height, NotchGeometry.menuBarHeight(for: screen)) + reach
    }

    private func drawerFrame(for layout: NotchLayout) -> NSRect {
        let screen = targetScreen()
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let topY = screenFrame.maxY + layout.expandedTopOffset
        return frame(for: layout.expandedSize, topY: topY, in: screenFrame)
    }

    private func frame(for size: NSSize, topY: CGFloat, in screenFrame: NSRect) -> NSRect {
        let x = screenFrame.midX - size.width / 2
        let y = topY - size.height

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
