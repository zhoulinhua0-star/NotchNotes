import AppKit
import Combine
import Foundation

enum TriggerMode: String, CaseIterable, Identifiable {
    case hover
    case click

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hover:
            return "Hover"
        case .click:
            return "Click"
        }
    }

    var systemImage: String {
        switch self {
        case .hover:
            return "cursorarrow.motionlines"
        case .click:
            return "cursorarrow.click.2"
        }
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var triggerMode: TriggerMode {
        didSet {
            UserDefaults.standard.set(triggerMode.rawValue, forKey: Self.triggerModeKey)
        }
    }
    private static let triggerModeKey = "notchNotes.triggerMode"

    init() {
        let rawMode = UserDefaults.standard.string(forKey: Self.triggerModeKey)
        if let savedMode = rawMode.flatMap(TriggerMode.init(rawValue:)) {
            triggerMode = savedMode
        } else {
            let hasPhysicalNotch = NotchGeometry.targetScreen()?.measuredNotchSize != .zero
            triggerMode = hasPhysicalNotch ? .hover : .click
        }
    }
}
