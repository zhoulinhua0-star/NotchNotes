import SwiftUI

/// Cell arithmetic for the Keep Awake timeline, kept apart from the view so it can be tested.
struct KeepAwakeTimeline: Equatable {
    static let rows = 3
    static let secondsPerCell: TimeInterval = 10 * 60

    let columns: Int

    var capacity: Int { columns * Self.rows }

    /// Cells lit for a session that has run for `elapsed` seconds; the current,
    /// partly used ten minutes counts as a lit cell. Nil means Keep Awake is off.
    func filledCells(elapsed: TimeInterval?) -> Int {
        guard let elapsed else { return 0 }
        let started = Int(max(0, elapsed) / Self.secondsPerCell) + 1
        return min(capacity, started)
    }

    func framedColumns(filledCells: Int) -> Int {
        (filledCells + Self.rows - 1) / Self.rows
    }

    /// "0m", "12m", "1h 24m": units spelled out so it never reads as minutes:seconds.
    static func readout(elapsed: TimeInterval) -> String {
        let minutes = Int(max(0, elapsed)) / 60
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// The band beside the notch at the top of the File Shelf: a grid that fills one
/// cell per ten minutes of Keep Awake, and a running clock. Each time the shelf
/// opens, the cells ripple in outward from the notch.
struct KeepAwakeStrip: View {
    @ObservedObject var controller: KeepAwakeController
    @ObservedObject var drawerState: DrawerState
    let layout: NotchLayout

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippleStart: Date?
    @State private var isBreathing = false

    private static let cellSize: CGFloat = 7
    private static let cellGap: CGFloat = 2
    private static var pitch: CGFloat { cellSize + cellGap }
    private static let edgeInset: CGFloat = 18
    private static let accent = Color(red: 1, green: 0.54, blue: 0.24)

    private static let rippleLead: TimeInterval = 0.1
    private static let rippleStagger: TimeInterval = 0.022
    private static let rippleCellDuration: TimeInterval = 0.32

    var body: some View {
        TimelineView(.animation(
            minimumInterval: rippleStart == nil ? 1 : nil,
            paused: rippleStart == nil && !isLive
        )) { context in
            content(now: context.date)
        }
        .padding(.horizontal, Self.edgeInset)
        .frame(width: layout.expandedSize.width, height: layout.compactSize.height)
        .allowsHitTesting(false)
        .onChange(of: drawerState.isExpanded) { _, isExpanded in
            if isExpanded { startRipple() }
            updateBreathing()
        }
        .onChange(of: controller.isKeepingAwake) { _, _ in updateBreathing() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keep Awake timeline")
        .accessibilityValue(accessibilityValue)
    }

    private func content(now: Date) -> some View {
        let isOn = controller.isKeepingAwake
        let elapsed = controller.startedAt.map { now.timeIntervalSince($0) }
        let filled = timeline.filledCells(elapsed: isOn ? elapsed : nil)
        let rippleTime = rippleStart.map { now.timeIntervalSince($0) }

        return HStack(spacing: 0) {
            grid(filled: filled, isOn: isOn, rippleTime: rippleTime)
                .frame(width: earWidth, alignment: .leading)
            Spacer(minLength: 0)
            readout(isOn: isOn, elapsed: elapsed ?? 0, rippleTime: rippleTime)
                .frame(width: earWidth, alignment: .trailing)
        }
    }

    // MARK: Grid

    private func grid(filled: Int, isOn: Bool, rippleTime: TimeInterval?) -> some View {
        HStack(spacing: Self.cellGap) {
            ForEach(0..<timeline.columns, id: \.self) { column in
                VStack(spacing: Self.cellGap) {
                    ForEach(0..<KeepAwakeTimeline.rows, id: \.self) { row in
                        cell(
                            index: column * KeepAwakeTimeline.rows + row,
                            column: column,
                            filled: filled,
                            isOn: isOn,
                            rippleTime: rippleTime
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.6), value: filled)
        .overlay(alignment: .topLeading) {
            sessionFrame(filled: filled)
        }
    }

    private func cell(
        index: Int,
        column: Int,
        filled: Int,
        isOn: Bool,
        rippleTime: TimeInterval?
    ) -> some View {
        let isLit = index < filled
        let isCurrent = isOn && index == filled - 1
        let ripple = rippleState(column: column, time: rippleTime)
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)

        return shape
            .fill(isLit ? Self.accent.opacity(litOpacity(index: index, filled: filled)) : .white.opacity(0.08))
            .overlay(shape.fill(.white.opacity(ripple.flash)))
            .frame(width: Self.cellSize, height: Self.cellSize)
            .shadow(
                color: Self.accent.opacity(isCurrent && isBreathing ? 0.8 : 0),
                radius: 3
            )
            .scaleEffect(ripple.scale)
            .opacity(ripple.opacity)
    }

    /// Older cells are dimmer, so the trail reads left to right like time.
    private func litOpacity(index: Int, filled: Int) -> Double {
        0.3 + 0.7 * Double(index + 1) / Double(max(filled, 1))
    }

    private func sessionFrame(filled: Int) -> some View {
        let columns = timeline.framedColumns(filledCells: filled)
        let rows = CGFloat(KeepAwakeTimeline.rows)
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Self.accent.opacity(0.85), lineWidth: 1.5)
            .frame(
                width: columns > 0 ? CGFloat(columns) * Self.pitch - Self.cellGap + 6 : 0,
                height: rows * Self.pitch - Self.cellGap + 6
            )
            .offset(x: -3, y: -3)
            .opacity(filled > 0 ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.62), value: filled)
    }

    // MARK: Readout

    private func readout(isOn: Bool, elapsed: TimeInterval, rippleTime: TimeInterval?) -> some View {
        let appear = rippleTime.map { min(max(($0 - 0.2) / 0.3, 0), 1) } ?? 1

        // Two lines only: the strip is barely taller than the notch.
        return VStack(alignment: .trailing, spacing: 2) {
            Text(isOn ? KeepAwakeTimeline.readout(elapsed: elapsed) : "—")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(isOn ? 0.92 : 0.25))
            HStack(spacing: 0) {
                Text(isOn ? "AWAKE" : "IDLE")
                    .foregroundStyle(isOn ? Self.accent : .white.opacity(0.42))
                Text(" · 10 MIN / CELL")
                    .foregroundStyle(.white.opacity(0.38))
            }
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .tracking(1)
        }
        .lineLimit(1)
        .animation(.easeInOut(duration: 0.5), value: isOn)
        .opacity(appear)
        .offset(x: (1 - appear) * -6)
    }

    // MARK: Ripple

    private func rippleState(column: Int, time: TimeInterval?) -> (scale: CGFloat, opacity: Double, flash: Double) {
        guard let time else { return (1, 1, 0) }
        // The notch sits to the right of this grid, so the wave starts at the last column.
        let delay = Self.rippleLead + Double(timeline.columns - 1 - column) * Self.rippleStagger
        let progress = (time - delay) / Self.rippleCellDuration
        if progress <= 0 { return (0.3, 0, 0) }
        if progress >= 1 { return (1, 1, 0) }
        return (0.3 + 0.7 * easeOutBack(progress), min(progress * 2, 1), sin(.pi * progress) * 0.85)
    }

    private func easeOutBack(_ x: Double) -> CGFloat {
        let c1 = 1.70158, c3 = c1 + 1
        return CGFloat(1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2))
    }

    private var rippleDuration: TimeInterval {
        Self.rippleLead + Double(timeline.columns - 1) * Self.rippleStagger + Self.rippleCellDuration
    }

    private func startRipple() {
        guard !reduceMotion else { return }
        let start = Date().addingTimeInterval(0.08)
        rippleStart = start
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(rippleDuration + 0.2))
            if rippleStart == start { rippleStart = nil }
        }
    }

    private func updateBreathing() {
        let shouldBreathe = isLive && !reduceMotion
        guard shouldBreathe != isBreathing else { return }
        if shouldBreathe {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        } else {
            withAnimation(nil) { isBreathing = false }
        }
    }

    // MARK: Layout

    private var isLive: Bool {
        controller.isKeepingAwake && drawerState.isExpanded
    }

    /// Width beside the notch on each side, leaving a little air next to it.
    private var earWidth: CGFloat {
        max(0, (layout.expandedSize.width - layout.notchSize.width) / 2 - Self.edgeInset - 8)
    }

    private var timeline: KeepAwakeTimeline {
        let fit = Int((earWidth + Self.cellGap) / Self.pitch)
        return KeepAwakeTimeline(columns: max(1, min(14, fit)))
    }

    private var accessibilityValue: String {
        guard controller.isKeepingAwake, let startedAt = controller.startedAt else { return "Off" }
        let minutes = Int(Date().timeIntervalSince(startedAt)) / 60
        return "On for \(minutes / 60) hours \(minutes % 60) minutes"
    }
}
