// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  WorldClockManager.swift
//
//  Manages multiple world clock windows
//

#if os(macOS)
import SwiftUI
import AppKit
import Combine

/// Singleton manager for world clock windows
class WorldClockManager: ObservableObject {
    static let shared = WorldClockManager()

    @Published private(set) var savedLocations: [WorldClockLocation] = []
    @Published private(set) var hasVisibleWindows: Bool = false
    @Published private(set) var unifiedWindowLocationIDs: [UUID] = []
    private var openWindows: [UUID: NSPanel] = [:]
    private weak var unifiedWindow: NSPanel?
    private var openWindowIDs: Set<UUID> = []
    private var areWorldClocksHidden: Bool = false
    private let settingsManager = ClockSettingsManager.shared
    private let defaults = UserDefaults.standard
    private let openWindowIDsKey = "openWorldClockWindows"
    private let unifiedWindowIDsKey = "unifiedWorldClockIDs"
    private let unifiedWindowOpenKey = "unifiedWorldClockWasOpen"
    private let unifiedWindowFrameKey = "unifiedWorldClockFrame"
    private var unifiedWindowShouldRestore = false

    private init() {
        loadSavedLocations()
        loadOpenWindowIDs()
        loadUnifiedWindowState()

        // Observe photo deletions to clear from world clock backgrounds if needed
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PhotoDeleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let photoID = notification.userInfo?["photoID"] as? UUID,
                  let self = self else { return }

            // Clear from any world clocks using this photo
            for location in self.savedLocations where location.settings.backgroundPhotoID == photoID {
                var updatedSettings = location.settings
                updatedSettings.backgroundPhotoID = nil
                self.updateClockSettings(for: location.id, settings: updatedSettings)
            }
        }
    }

    // MARK: - Location Management

    /// Add a new world clock location
    func addLocation(_ location: WorldClockLocation) {
        var newLocation = location
        // Seed appearance to match current main clock so new windows inherit its style
        newLocation.settings = settingsManager.mainClockSettings

        // Set window size and position based on main clock window
        if let mainWindow = NSApp.windows.first(where: { $0.title == "CoolClockPresence" }) {
            // Copy size from main clock
            newLocation.windowWidth = mainWindow.frame.size.width
            newLocation.windowHeight = mainWindow.frame.size.height

            // Position offset from main window (for when undocked later)
            newLocation.windowX = mainWindow.frame.origin.x + 40
            newLocation.windowY = mainWindow.frame.origin.y - 40
        } else {
            // Default to center-ish if main window not found
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                newLocation.windowX = screenFrame.midX - (newLocation.windowWidth / 2)
                newLocation.windowY = screenFrame.midY - (newLocation.windowHeight / 2)
            }
        }

        // Dock by default when first added
        newLocation.isDocked = true
        newLocation.dockedOrder = nextDockedOrder()

        savedLocations.append(newLocation)
        saveLocations()

        // Notify main window to refresh and show the docked clock
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)

        print("✅ Added and docked clock: \(newLocation.displayName)")
    }

    /// Add a location directly to the combined, detached world-clock window.
    func addLocationToUnifiedWindow(_ location: WorldClockLocation) {
        if let existing = savedLocations.first(where: { $0.id == location.id }) {
            addClockToUnifiedWindow(existing.id)
            return
        }

        var newLocation = location
        newLocation.settings = settingsManager.mainClockSettings
        newLocation.isDocked = false
        newLocation.dockedOrder = savedLocations.count
        savedLocations.append(newLocation)
        saveLocations()
        addClockToUnifiedWindow(newLocation.id)
    }

    /// Remove a world clock location
    func removeLocation(id: UUID) {
        // Check if the clock being removed was docked
        let wasDocked = savedLocations.first(where: { $0.id == id })?.isDocked ?? false

        closeWorldClock(for: id)
        savedLocations.removeAll { $0.id == id }
        unifiedWindowLocationIDs.removeAll { $0 == id }
        saveUnifiedWindowState()
        closeUnifiedWindowIfEmpty()
        saveLocations()

        // Notify main window to refresh if a docked clock was removed
        if wasDocked {
            NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)
            print("✅ Removed docked clock")
        }
    }

    /// Hide a saved location without deleting it so it can be reopened later.
    /// Used when the user dismisses a docked clock or closes a world clock window.
    func hideLocation(id: UUID) {
        guard let index = savedLocations.firstIndex(where: { $0.id == id }) else { return }

        let wasDocked = savedLocations[index].isDocked
        savedLocations[index].isDocked = false
        unifiedWindowLocationIDs.removeAll { $0 == id }
        saveUnifiedWindowState()
        closeUnifiedWindowIfEmpty()

        // Close any open window for this clock
        closeWorldClock(for: id)
        saveLocations()

        if wasDocked {
            NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)
        }
    }

    /// Update location window position and size
    func updateLocationWindow(id: UUID, x: Double, y: Double, width: Double, height: Double) {
        if let index = savedLocations.firstIndex(where: { $0.id == id }) {
            savedLocations[index].windowX = x
            savedLocations[index].windowY = y
            savedLocations[index].windowWidth = width
            savedLocations[index].windowHeight = height
            saveLocations()
        }
    }

    /// Check if a location is currently open
    func isLocationOpen(id: UUID) -> Bool {
        openWindows[id] != nil
    }

    private func updateVisibility() {
        hasVisibleWindows = (!openWindows.isEmpty || unifiedWindow?.isVisible == true) && !areWorldClocksHidden
    }

    // MARK: - Window Management
    private func undockedMainClockSize(using mainWindow: NSWindow) -> CGSize {
        let preDockWidth = defaults.double(forKey: "preDockWindowWidth")
        let preDockHeight = defaults.double(forKey: "preDockWindowHeight")

        if preDockWidth > 0 && preDockHeight > 0 {
            return CGSize(width: preDockWidth, height: preDockHeight)
        }

        return mainWindow.frame.size
    }

    /// Open a world clock window for a location (window creation delegated to AppDelegate)
    func openWorldClock(for location: WorldClockLocation) {
        // Don't open if already open
        guard openWindows[location.id] == nil else {
            // Just bring to front if already open
            openWindows[location.id]?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Notify AppDelegate to create the window using the saved size from the location
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenWorldClock"),
            object: nil,
            userInfo: ["location": location]
        )
        markWindowOpen(location.id)
    }

    /// Register a world clock window (called by AppDelegate after creating it)
    func registerWorldClockWindow(_ window: NSPanel, for locationID: UUID) {
        openWindows[locationID] = window
        updateVisibility()
    }

    /// Unregister a world clock window
    func unregisterWorldClockWindow(for locationID: UUID) {
        openWindows.removeValue(forKey: locationID)
        updateVisibility()
    }

    /// Close a world clock window
    func closeWorldClock(for locationID: UUID) {
        if let window = openWindows[locationID] {
            window.close()
            openWindows.removeValue(forKey: locationID)
        }
        markWindowClosed(locationID)
    }

    /// Toggle a world clock window (open if closed, close if open)
    func toggleWorldClock(for location: WorldClockLocation) {
        if openWindows[location.id] != nil {
            closeWorldClock(for: location.id)
        } else {
            openWorldClock(for: location)
        }
    }

    /// Close all world clock windows
    func closeAllWorldClocks() {
        var didChange = false

        for (id, window) in openWindows {
            window.close()
            if openWindowIDs.remove(id) != nil {
                didChange = true
            }
        }
        openWindows.removeAll()

        if didChange {
            saveOpenWindowIDs()
        }
    }

    /// Hide every open world clock without closing the windows so they can be restored.
    func hideAllOpenWorldClocks() {
        openWindows.values.forEach { $0.orderOut(nil) }
        unifiedWindow?.orderOut(nil)
        areWorldClocksHidden = true
        updateVisibility()
    }

    /// Bring back every open world clock window.
    func showAllOpenWorldClocks() {
        openWindows.values.forEach { $0.orderFrontRegardless() }
        unifiedWindow?.orderFrontRegardless()
        areWorldClocksHidden = false
        updateVisibility()
    }

    // MARK: - Docking Management

    /// All docked clocks sorted by order
    var dockedClocks: [WorldClockLocation] {
        savedLocations.filter { $0.isDocked }.sorted { $0.dockedOrder < $1.dockedOrder }
    }

    /// Dock a world clock to the main clock window
    func dockClock(for locationID: UUID) {
        guard let index = savedLocations.firstIndex(where: { $0.id == locationID }) else {
            print("⚠️ Cannot dock: location not found")
            return
        }

        // Verify main window is visible
        guard let mainWindow = NSApp.windows.first(where: { $0.title == "CoolClockPresence" }),
              mainWindow.isVisible else {
            print("⚠️ Cannot dock: main window not visible")
            // Optionally show main window
            NotificationCenter.default.post(name: NSNotification.Name("ShowMainClockWindow"), object: nil)
            return
        }

        // Save current window state before docking (if window is open)
        if let window = openWindows[locationID] {
            let frame = window.frame
            savedLocations[index].windowX = frame.origin.x
            savedLocations[index].windowY = frame.origin.y
            savedLocations[index].windowWidth = frame.size.width
            savedLocations[index].windowHeight = frame.size.height

            // Close the floating window
            window.close()
            openWindows.removeValue(forKey: locationID)
        }

        // Set docking state
        savedLocations[index].isDocked = true
        unifiedWindowLocationIDs.removeAll { $0 == locationID }
        saveUnifiedWindowState()
        closeUnifiedWindowIfEmpty()
        savedLocations[index].dockedOrder = nextDockedOrder()
        markWindowClosed(locationID)

        saveLocations()

        // Notify main window to refresh
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)

        print("✅ Docked clock: \(savedLocations[index].displayName)")
    }

    /// Undock a world clock from the main clock window
    func undockClock(for locationID: UUID) {
        guard let index = savedLocations.firstIndex(where: { $0.id == locationID }) else {
            print("⚠️ Cannot undock: location not found")
            return
        }

        // Remove docking state
        savedLocations[index].isDocked = false

        // A newly detached clock starts at the main clock's current size.
        if let mainWindow = NSApp.windows.first(where: { $0.title == "CoolClockPresence" }) {
            let targetSize = undockedMainClockSize(using: mainWindow)
            savedLocations[index].windowWidth = targetSize.width
            savedLocations[index].windowHeight = targetSize.height
        }

        saveLocations()

        // Open as floating window (will restore saved position)
        openWorldClock(for: savedLocations[index])

        // Notify main window to refresh
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)

        print("✅ Undocked clock: \(savedLocations[index].displayName)")
    }

    /// Undock every clock currently attached to the main clock into one window.
    func undockAllClocks() {
        let ids = dockedClocks.map(\.id)
        guard !ids.isEmpty else { return }

        // Match the main clock's width, but fit height to the detached clocks.
        if let mainWindow = NSApp.windows.first(where: { $0.title == "CoolClockPresence" }) {
            let currentFrame = restoredUnifiedWindowFrame ?? mainWindow.frame
            let storedScale = defaults.double(forKey: "unifiedWorldClockFontScale")
            let scale = storedScale > 0 ? storedScale : 1.0
            let fittedHeight = unifiedWindowHeight(clockCount: ids.count, fontScale: scale)
            let detachedFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.midY - fittedHeight / 2,
                width: mainWindow.frame.width,
                height: fittedHeight
            )
            updateUnifiedWindowFrame(detachedFrame)
        }

        for id in ids {
            if let index = savedLocations.firstIndex(where: { $0.id == id }) {
                savedLocations[index].isDocked = false
            }
            closeWorldClock(for: id)
        }
        unifiedWindowLocationIDs = ids
        unifiedWindowShouldRestore = true
        saveUnifiedWindowState()
        saveLocations()
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)
        presentUnifiedWindow()
    }

    /// Put another saved clock in the combined detached window.
    func addClockToUnifiedWindow(_ locationID: UUID) {
        guard let index = savedLocations.firstIndex(where: { $0.id == locationID }) else { return }
        savedLocations[index].isDocked = false
        closeWorldClock(for: locationID)
        if !unifiedWindowLocationIDs.contains(locationID) {
            unifiedWindowLocationIDs.append(locationID)
        }
        unifiedWindowShouldRestore = true
        saveUnifiedWindowState()
        saveLocations()
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)
        presentUnifiedWindow()
    }

    func removeClockFromUnifiedWindow(_ locationID: UUID) {
        unifiedWindowLocationIDs.removeAll { $0 == locationID }
        saveUnifiedWindowState()
        closeUnifiedWindowIfEmpty()
    }

    func redockAllUnifiedClocks() {
        let ids = unifiedWindowLocationIDs
        for id in ids {
            dockClock(for: id)
        }
    }

    var unifiedWindowSettings: ClockSettings {
        unifiedWindowLocationIDs.compactMap { id in
            savedLocations.first(where: { $0.id == id })?.settings
        }.first ?? .default
    }

    func isInUnifiedWindow(_ locationID: UUID) -> Bool {
        unifiedWindowLocationIDs.contains(locationID)
    }

    func updateUnifiedClockSettings<T>(_ keyPath: WritableKeyPath<ClockSettings, T>, value: T) {
        let unifiedIDs = Set(unifiedWindowLocationIDs)
        savedLocations = savedLocations.map { location in
            guard unifiedIDs.contains(location.id) else { return location }
            var updated = location
            updated.settings[keyPath: keyPath] = value
            return updated
        }
        saveLocations()
    }

    func setUnifiedAlwaysOnTop(_ enabled: Bool) {
        updateUnifiedClockSettings(\.alwaysOnTop, value: enabled)
        unifiedWindow?.level = enabled
            ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
            : .normal
    }

    func registerUnifiedWindow(_ window: NSPanel) {
        unifiedWindow = window
        window.level = unifiedWindowSettings.alwaysOnTop
            ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
            : .normal
        unifiedWindowShouldRestore = true
        saveUnifiedWindowState()
        updateVisibility()
    }

    func unregisterUnifiedWindow() {
        unifiedWindow = nil
        updateVisibility()
    }

    var restoredUnifiedWindowFrame: NSRect? {
        guard let value = defaults.string(forKey: unifiedWindowFrameKey) else { return nil }
        let frame = NSRectFromString(value)
        return frame.width > 0 && frame.height > 0 ? frame : nil
    }

    func updateUnifiedWindowFrame(_ frame: NSRect) {
        defaults.set(NSStringFromRect(frame), forKey: unifiedWindowFrameKey)
        if let unifiedWindow, unifiedWindow.frame != frame {
            unifiedWindow.setFrame(frame, display: true)
        }
    }

    func fitUnifiedWindowToClocks(fontScale: Double) {
        guard !unifiedWindowLocationIDs.isEmpty else { return }
        let currentFrame = unifiedWindow?.frame ?? restoredUnifiedWindowFrame ?? NSRect(x: 0, y: 0, width: 360, height: 180)
        let fittedHeight = unifiedWindowHeight(clockCount: unifiedWindowLocationIDs.count, fontScale: fontScale)
        let fittedFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.midY - fittedHeight / 2,
            width: currentFrame.width,
            height: fittedHeight
        )
        updateUnifiedWindowFrame(fittedFrame)
    }

    private func unifiedWindowHeight(clockCount: Int, fontScale: Double) -> CGFloat {
        let verticalPadding: CGFloat = 16
        let rowHeight = CGFloat(68 * max(0.8, min(fontScale, 1.2)))
        return max(80, min(720, verticalPadding + CGFloat(clockCount) * rowHeight))
    }

    private func presentUnifiedWindow() {
        if let unifiedWindow {
            unifiedWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("OpenUnifiedWorldClocks"), object: nil)
        }
    }

    private func closeUnifiedWindowIfEmpty() {
        guard unifiedWindowLocationIDs.isEmpty else { return }
        unifiedWindowShouldRestore = false
        saveUnifiedWindowState()
        unifiedWindow?.close()
        unifiedWindow = nil
        updateVisibility()
    }

    /// Get the next available docked order number
    private func nextDockedOrder() -> Int {
        let maxOrder = savedLocations.filter { $0.isDocked }.map { $0.dockedOrder }.max() ?? -1
        return maxOrder + 1
    }

    /// Reorder docked clocks (for drag-to-reorder in future)
    func reorderDockedClock(from sourceIndex: Int, to destinationIndex: Int) {
        var docked = savedLocations.filter { $0.isDocked }.sorted { $0.dockedOrder < $1.dockedOrder }

        guard sourceIndex < docked.count, destinationIndex < docked.count else { return }

        let item = docked.remove(at: sourceIndex)
        docked.insert(item, at: destinationIndex)

        // Update dockedOrder for all docked clocks
        for (index, location) in docked.enumerated() {
            if let savedIndex = savedLocations.firstIndex(where: { $0.id == location.id }) {
                savedLocations[savedIndex].dockedOrder = index
            }
        }

        saveLocations()
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)
    }

    // MARK: - Reordering

    /// Move a saved world clock relative to another clock (used by drag-and-drop in Manage view).
    func moveLocation(draggedID: UUID, to targetID: UUID) {
        guard let fromIndex = savedLocations.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = savedLocations.firstIndex(where: { $0.id == targetID }) else { return }

        moveLocation(from: fromIndex, to: targetIndex)
    }

    /// Move a saved world clock to the end of the list (drop below the final item).
    func moveLocationToEnd(_ id: UUID) {
        guard let fromIndex = savedLocations.firstIndex(where: { $0.id == id }) else { return }
        let item = savedLocations.remove(at: fromIndex)
        savedLocations.append(item)
        resequenceDockedOrders()
        saveLocations()
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)
    }

    private func moveLocation(from fromIndex: Int, to targetIndex: Int) {
        guard fromIndex != targetIndex else { return }

        let item = savedLocations.remove(at: fromIndex)
        let insertionIndex = targetIndex > fromIndex ? targetIndex - 1 : targetIndex
        savedLocations.insert(item, at: insertionIndex)
        resequenceDockedOrders()
        saveLocations()
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)
    }

    /// Ensure docked clocks keep a stable, contiguous order after reordering.
    private func resequenceDockedOrders() {
        var dockedOrderValue = 0

        for (index, location) in savedLocations.enumerated() where location.isDocked {
            savedLocations[index].dockedOrder = dockedOrderValue
            dockedOrderValue += 1
        }
    }

    /// Update settings for a specific world clock
    func updateClockSettings(for locationID: UUID, settings: ClockSettings) {
        guard let index = savedLocations.firstIndex(where: { $0.id == locationID }) else { return }
        savedLocations[index].settings = settings
        saveLocations()
    }

    /// Apply a settings change to every saved world clock (used when global settings change).
    func updateAllClockSettings<T>(_ keyPath: WritableKeyPath<ClockSettings, T>, value: T) {
        savedLocations = savedLocations.map { location in
            var updated = location
            updated.settings[keyPath: keyPath] = value
            return updated
        }
        saveLocations()
    }

    /// Apply a custom transformation to every saved world clock's settings.
    func updateAllClockSettings(_ update: (inout ClockSettings) -> Void) {
        savedLocations = savedLocations.map { location in
            var updated = location
            update(&updated.settings)
            return updated
        }
        saveLocations()
    }

    /// Replace the city/timezone for an existing clock without removing the window.
    /// Keeps the existing window position, size, settings, and docked state intact.
    func replaceLocation(id: UUID, with newLocation: WorldClockLocation) {
        guard let index = savedLocations.firstIndex(where: { $0.id == id }) else { return }

        let existing = savedLocations[index]
        let merged = WorldClockLocation(
            id: existing.id,
            displayName: newLocation.displayName,
            timeZoneIdentifier: newLocation.timeZoneIdentifier,
            windowX: existing.windowX,
            windowY: existing.windowY,
            windowWidth: existing.windowWidth,
            windowHeight: existing.windowHeight,
            settings: existing.settings,
            isDocked: existing.isDocked,
            dockedOrder: existing.dockedOrder
        )

        savedLocations[index] = merged
        saveLocations()

        // Update the window title if it's open
        if let window = openWindows[id] {
            window.title = "World Clock - \(merged.displayName)"
        }

        // Notify docked clocks/main view to refresh
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)
    }

    // MARK: - Persistence

    /// Restore any floating world clocks that were open the last time the app ran.
    func restoreOpenWorldClocks() {
        let idsToRestore = Array(openWindowIDs)
        var didPrune = false

        for id in idsToRestore {
            guard let location = savedLocations.first(where: { $0.id == id }) else {
                openWindowIDs.remove(id)
                didPrune = true
                continue
            }

            if location.isDocked {
                openWindowIDs.remove(id)
                didPrune = true
                continue
            }

            openWorldClock(for: location)
        }

        if didPrune {
            saveOpenWindowIDs()
        }

        unifiedWindowLocationIDs = unifiedWindowLocationIDs.filter { id in
            savedLocations.contains(where: { $0.id == id && !$0.isDocked })
        }
        saveUnifiedWindowState()
        if unifiedWindowShouldRestore && !unifiedWindowLocationIDs.isEmpty {
            presentUnifiedWindow()
        }
    }

    private func loadUnifiedWindowState() {
        unifiedWindowShouldRestore = defaults.bool(forKey: unifiedWindowOpenKey)
        guard let data = defaults.data(forKey: unifiedWindowIDsKey) else { return }
        unifiedWindowLocationIDs = (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
    }

    private func saveUnifiedWindowState() {
        defaults.set(unifiedWindowShouldRestore, forKey: unifiedWindowOpenKey)
        if let data = try? JSONEncoder().encode(unifiedWindowLocationIDs) {
            defaults.set(data, forKey: unifiedWindowIDsKey)
        }
    }

    private func loadOpenWindowIDs() {
        guard let data = defaults.data(forKey: openWindowIDsKey) else { return }
        do {
            let ids = try JSONDecoder().decode([UUID].self, from: data)
            openWindowIDs = Set(ids)
        } catch {
            print("⚠️ Failed to load open world clock IDs: \(error)")
            openWindowIDs = []
        }
    }

    private func saveOpenWindowIDs() {
        do {
            let data = try JSONEncoder().encode(Array(openWindowIDs))
            defaults.set(data, forKey: openWindowIDsKey)
        } catch {
            print("⚠️ Failed to save open world clock IDs: \(error)")
        }
    }

    private func markWindowOpen(_ id: UUID) {
        if openWindowIDs.insert(id).inserted {
            saveOpenWindowIDs()
        }
    }

    private func markWindowClosed(_ id: UUID) {
        if openWindowIDs.remove(id) != nil {
            saveOpenWindowIDs()
        }
    }

    private func loadSavedLocations() {
        guard let data = defaults.data(forKey: "worldClockLocations") else { return }
        do {
            savedLocations = try JSONDecoder().decode([WorldClockLocation].self, from: data)
        } catch {
            print("⚠️ Failed to load world clock locations: \(error)")
            savedLocations = []
        }
    }

    private func saveLocations() {
        do {
            let data = try JSONEncoder().encode(savedLocations)
            defaults.set(data, forKey: "worldClockLocations")
        } catch {
            print("⚠️ Failed to save world clock locations: \(error)")
        }
    }
}

#endif
