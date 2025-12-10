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
    private let defaults = UserDefaults.standard

    private init() {
        loadSavedLocations()
    }

    // MARK: - Location Management

    /// Add a new world clock location
    func addLocation(_ location: WorldClockLocation) {
        var newLocation = location

        // Set window size and position based on main clock window
        if let mainWindow = NSApp.windows.first(where: { $0.title == "CoolClockPresence" }) {
            // Copy size from main clock
            newLocation.windowWidth = mainWindow.frame.size.width
            newLocation.windowHeight = mainWindow.frame.size.height

            // Position offset from main window
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

        savedLocations.append(newLocation)
        saveLocations()
        openWorldClock(for: newLocation)
    }

    /// Remove a world clock location
    func removeLocation(id: UUID) {
        closeWorldClock(for: id)
        savedLocations.removeAll { $0.id == id }
        saveLocations()
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

    // MARK: - Window Management

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

        // Update size to match main clock when opening
        if let mainWindow = NSApp.windows.first(where: { $0.title == "CoolClockPresence" }) {
            updatedLocation.windowWidth = mainWindow.frame.size.width
            updatedLocation.windowHeight = mainWindow.frame.size.height

            // Update saved location with new size
            if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
                savedLocations[index].windowWidth = mainWindow.frame.size.width
                savedLocations[index].windowHeight = mainWindow.frame.size.height
                saveLocations()
            }
        }

        // Notify AppDelegate to create the window
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenWorldClock"),
            object: nil,
            userInfo: ["location": updatedLocation]
        )
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
        for (_, window) in openWindows {
            window.close()
        }
        openWindows.removeAll()
    }

    // MARK: - Persistence

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
