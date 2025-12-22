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
    private var openWindows: [UUID: NSPanel] = [:]
    private var openWindowIDs: Set<UUID> = []
    private let settingsManager = ClockSettingsManager.shared
    private let defaults = UserDefaults.standard
    private let openWindowIDsKey = "openWorldClockWindows"

    private init() {
        loadSavedLocations()
        loadOpenWindowIDs()
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

    /// Remove a world clock location
    func removeLocation(id: UUID) {
        // Check if the clock being removed was docked
        let wasDocked = savedLocations.first(where: { $0.id == id })?.isDocked ?? false

        closeWorldClock(for: id)
        savedLocations.removeAll { $0.id == id }
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

    /// True when at least one world clock panel is visible.
    var hasVisibleWindows: Bool {
        openWindows.values.contains { $0.isVisible }
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

        var updatedLocation = location

        // Update size to match the main clock's undocked size when opening
        if let mainWindow = NSApp.windows.first(where: { $0.title == "CoolClockPresence" }) {
            let targetSize = undockedMainClockSize(using: mainWindow)
            updatedLocation.windowWidth = targetSize.width
            updatedLocation.windowHeight = targetSize.height

            // Update saved location with new size
            if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
                savedLocations[index].windowWidth = targetSize.width
                savedLocations[index].windowHeight = targetSize.height
                saveLocations()
            }
        }

        // Notify AppDelegate to create the window
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenWorldClock"),
            object: nil,
            userInfo: ["location": updatedLocation]
        )
        markWindowOpen(location.id)
    }

    /// Register a world clock window (called by AppDelegate after creating it)
    func registerWorldClockWindow(_ window: NSPanel, for locationID: UUID) {
        openWindows[locationID] = window
    }

    /// Unregister a world clock window
    func unregisterWorldClockWindow(for locationID: UUID) {
        openWindows.removeValue(forKey: locationID)
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
    }

    /// Bring back every open world clock window.
    func showAllOpenWorldClocks() {
        openWindows.values.forEach { $0.orderFrontRegardless() }
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

        saveLocations()

        // Open as floating window (will restore saved position)
        openWorldClock(for: savedLocations[index])

        // Notify main window to refresh
        NotificationCenter.default.post(name: NSNotification.Name("WorldClockDockingChanged"), object: nil)

        print("✅ Undocked clock: \(savedLocations[index].displayName)")
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
