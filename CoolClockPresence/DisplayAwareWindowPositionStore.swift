#if os(macOS)
import AppKit

/// Persists a window's position relative to each physical display it has visited.
/// The preferred display is kept even while that display is temporarily disconnected.
final class DisplayAwareWindowPositionStore {
    static let shared = DisplayAwareWindowPositionStore()

    private struct Placement: Codable {
        var offsetX: Double
        var offsetY: Double
        var width: Double
        var height: Double
    }

    private struct WindowState: Codable {
        var preferredDisplayID: String?
        var placements: [String: Placement]
    }

    private let defaults = UserDefaults.standard
    private let keyPrefix = "displayAwareWindowState."

    private init() {}

    func save(frame: NSRect, for role: String, on screen: NSScreen?, makePreferred: Bool) {
        guard let screen else { return }
        let displayID = identifier(for: screen)
        let visible = screen.visibleFrame
        var state = load(role: role)
        state.placements[displayID] = Placement(
            offsetX: frame.minX - visible.minX,
            offsetY: frame.minY - visible.minY,
            width: frame.width,
            height: frame.height
        )
        if makePreferred || state.preferredDisplayID == nil {
            state.preferredDisplayID = displayID
        }
        persist(state, role: role)
    }

    /// Returns nil when the preferred display is disconnected. This deliberately avoids
    /// replacing that preference with the temporary screen chosen by macOS.
    func restoredFrame(for role: String) -> NSRect? {
        let state = load(role: role)
        guard let displayID = state.preferredDisplayID,
              let screen = NSScreen.screens.first(where: { identifier(for: $0) == displayID }),
              let placement = state.placements[displayID] else { return nil }

        let visible = screen.visibleFrame
        let width = min(CGFloat(placement.width), visible.width)
        let height = min(CGFloat(placement.height), visible.height)
        let desired = NSRect(
            x: visible.minX + CGFloat(placement.offsetX),
            y: visible.minY + CGFloat(placement.offsetY),
            width: width,
            height: height
        )
        return clamp(desired, to: visible)
    }

    func preferredDisplayIsConnected(for role: String) -> Bool {
        guard let displayID = load(role: role).preferredDisplayID else { return false }
        return NSScreen.screens.contains { identifier(for: $0) == displayID }
    }

    func hasPreferredDisplay(for role: String) -> Bool {
        load(role: role).preferredDisplayID != nil
    }

    private func identifier(for screen: NSScreen) -> String {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "display-\(number.uint32Value)"
        }
        return "name-\(screen.localizedName)"
    }

    private func load(role: String) -> WindowState {
        guard let data = defaults.data(forKey: keyPrefix + role),
              let state = try? JSONDecoder().decode(WindowState.self, from: data) else {
            return WindowState(preferredDisplayID: nil, placements: [:])
        }
        return state
    }

    private func persist(_ state: WindowState, role: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: keyPrefix + role)
    }

    private func clamp(_ frame: NSRect, to visible: NSRect) -> NSRect {
        var result = frame
        result.origin.x = min(max(result.minX, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.minY, visible.minY), visible.maxY - result.height)
        return result
    }
}
#endif
