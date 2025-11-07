#if os(macOS)
import Foundation

/// Predefined locations the floating clock can snap to.
enum ClockWindowPosition: String, CaseIterable, Identifiable {
    case topLeft
    case topCenter
    case topRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Middle"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Middle"
        case .bottomRight: return "Bottom Right"
        }
    }
}

extension ClockWindowPosition {
    /// Identifier stored when the user drags the window to a custom spot.
    static let customIdentifier = "custom"
}
#endif
