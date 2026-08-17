import AppKit
import SwiftUI

@MainActor
final class DrawerState: ObservableObject {
    @Published var isExpanded = false
    @Published var revealProgress: CGFloat = 0
}

struct ShelfOnlyView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var keepAwakeController: KeepAwakeController
    @ObservedObject var fileShelfStore: FileShelfStore
    @ObservedObject var workspaceState: NotebookWorkspaceState
    @ObservedObject var drawerState: DrawerState
    let layout: NotchLayout
    let onAddFiles: () -> Void

    var body: some View {
        drawer
            .frame(
                width: layout.expandedSize.width,
                height: layout.expandedSize.height,
                alignment: .top
            )
            .dropDestination(for: URL.self) { urls, _ in
                guard !workspaceState.isDraggingShelfItem else {
                    workspaceState.isShelfDropTargeted = false
                    return false
                }
                return receiveDroppedFiles(urls)
            } isTargeted: { isTargeted in
                withAnimation(shelfAnimation) {
                    workspaceState.isShelfDropTargeted = isTargeted
                        && !workspaceState.isDraggingShelfItem
                }
            }
            .environment(\.colorScheme, .dark)
    }

    private var drawer: some View {
        expandedContent
            .frame(
                width: layout.expandedSize.width,
                height: layout.expandedSize.height,
                alignment: .top
            )
            .opacity(expandedContentOpacity)
            .background(Color(red: 0.02, green: 0.02, blue: 0.025).opacity(0.98))
            .mask(alignment: .top) {
                TopAttachedRoundedShape(radius: cornerRadius)
                    .frame(width: revealWidth, height: revealHeight)
            }
            .overlay(alignment: .top) {
                TopAttachedRoundedShape(radius: cornerRadius)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
                    .frame(width: revealWidth, height: revealHeight)
            }
            .contentShape(Rectangle())
            .allowsHitTesting(drawerState.isExpanded)
    }

    private var expandedContent: some View {
        VStack(spacing: 8) {
            header

            FileShelfView(
                store: fileShelfStore,
                workspaceState: workspaceState,
                size: shelfSize
            )
            .frame(width: shelfSize.width, height: shelfSize.height)

            footer
        }
        .padding(.top, layout.compactSize.height + 6)
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 12)
        .onDisappear {
            workspaceState.isShelfDropTargeted = false
            workspaceState.isDraggingShelfItem = false
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .accessibilityHidden(true)

            Text("File Shelf")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            Text(itemCountText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))

            Spacer(minLength: 8)

            KeepAwakeButton(controller: keepAwakeController)
            TriggerModeMenu(settingsStore: settingsStore)
        }
        .frame(height: 28)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: onAddFiles) {
                Label("Add Files", systemImage: "plus")
                    .frame(height: 26)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(ShelfToolbarButtonStyle())
            .keyboardShortcut("o", modifiers: .command)
            .help("Add files or folders")

            Text("References only — originals stay in place")
                .font(.system(size: 9.5, weight: .regular))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                withAnimation(shelfAnimation) {
                    fileShelfStore.removeAll()
                }
            } label: {
                Image(systemName: "trash")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(ShelfToolbarButtonStyle())
            .disabled(fileShelfStore.items.isEmpty)
            .help("Clear shelf (original files stay on disk)")
            .accessibilityLabel("Clear file shelf")
        }
        .frame(height: 28)
    }

    private var shelfSize: CGSize {
        CGSize(
            width: layout.expandedSize.width - horizontalPadding * 2,
            height: 76
        )
    }

    private var horizontalPadding: CGFloat { 16 }

    private var itemCountText: String {
        let count = fileShelfStore.items.count
        return count == 1 ? "1 item" : "\(count) items"
    }

    private var revealWidth: CGFloat {
        interpolate(from: layout.compactSize.width, to: layout.expandedSize.width)
    }

    private var revealHeight: CGFloat {
        interpolate(from: layout.compactSize.height, to: layout.expandedSize.height)
    }

    private var cornerRadius: CGFloat {
        interpolate(from: 12, to: 18)
    }

    private var expandedContentOpacity: CGFloat {
        min(max((drawerState.revealProgress - 0.22) / 0.32, 0), 1)
    }

    private var shelfAnimation: Animation {
        .spring(response: 0.28, dampingFraction: 0.86)
    }

    private func interpolate(from start: CGFloat, to end: CGFloat) -> CGFloat {
        start + (end - start) * drawerState.revealProgress
    }

    private func receiveDroppedFiles(_ urls: [URL]) -> Bool {
        let didAcceptDrop = fileShelfStore.acceptDrop(urls)
        workspaceState.isShelfDropTargeted = false
        return didAcceptDrop
    }
}

private struct TriggerModeMenu: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @State private var isHovering = false

    var body: some View {
        Menu {
            Text("Open shelf with")

            ForEach(TriggerMode.allCases) { mode in
                Button {
                    settingsStore.triggerMode = mode
                } label: {
                    Label(
                        mode.title,
                        systemImage: settingsStore.triggerMode == mode
                            ? "checkmark"
                            : mode.systemImage
                    )
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.white.opacity(isHovering ? 0.92 : 0.72))
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.white.opacity(isHovering ? 0.09 : 0.045))
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isHovering = $0 }
        .help("Open shelf with \(settingsStore.triggerMode.title.lowercased())")
        .accessibilityLabel("Shelf trigger mode")
        .accessibilityValue(settingsStore.triggerMode.title)
    }
}

private struct KeepAwakeButton: View {
    @ObservedObject var controller: KeepAwakeController

    var body: some View {
        Button(action: controller.toggle) {
            Image(
                systemName: controller.isKeepingAwake
                    ? "cup.and.saucer.fill"
                    : "cup.and.saucer"
            )
            .frame(width: 28, height: 28)
        }
        .buttonStyle(ShelfToolbarButtonStyle(isActive: controller.isKeepingAwake))
        .help(helpText)
        .accessibilityLabel("Keep Mac awake")
        .accessibilityValue(controller.isKeepingAwake ? "On" : "Off")
        .alert(
            "Couldn’t Keep Mac Awake",
            isPresented: Binding(
                get: { controller.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        controller.dismissError()
                    }
                }
            )
        ) {
            Button("OK", action: controller.dismissError)
        } message: {
            Text(controller.errorMessage ?? "")
        }
    }

    private var helpText: String {
        controller.isKeepingAwake
            ? "Stop keeping Mac awake (turns off automatically when Mac sleeps)"
            : "Keep display and Mac awake until it sleeps"
    }
}

private struct ShelfToolbarButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.58 : 0.82))
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        .white.opacity(
                            configuration.isPressed ? 0.14 : (isActive ? 0.12 : 0.055)
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.white.opacity(isActive ? 0.16 : 0.07), lineWidth: 1)
            }
    }
}

struct CompactNotchView: View {
    let layout: NotchLayout

    var body: some View {
        Color.clear
            .frame(width: layout.compactSize.width, height: layout.compactSize.height + 28)
            .contentShape(Rectangle())
            .accessibilityLabel("Open file shelf")
    }
}

struct TopAttachedRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(radius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}
