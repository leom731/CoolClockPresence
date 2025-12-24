// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  ClockSettingsManager.swift
//
//  Manages per-window clock settings with persistence and migration
//

#if os(macOS)
import Foundation
import Combine

/// Singleton manager for clock settings
/// Handles main clock settings persistence and migration from global @AppStorage
final class ClockSettingsManager: ObservableObject {
    static let shared = ClockSettingsManager()

    @Published private(set) var mainClockSettings: ClockSettings
    @Published var isMainClockVisible: Bool = true
    private let defaults = UserDefaults.standard

    private init() {
        // Load existing settings or migrate from global @AppStorage
        if let data = defaults.data(forKey: ClockSettings.mainClockKey),
           let settings = try? JSONDecoder().decode(ClockSettings.self, from: data) {
            mainClockSettings = settings
        } else {
            // Migrate from old global @AppStorage keys
            mainClockSettings = Self.migrateGlobalSettings()
            saveMainClockSettings()
        }
    }

    /// Update main clock settings and persist to UserDefaults
    func updateMainClock(_ settings: ClockSettings) {
        mainClockSettings = settings
        saveMainClockSettings()
    }

    /// Update a specific property of main clock settings
    func updateMainClockProperty<T>(_ keyPath: WritableKeyPath<ClockSettings, T>, value: T) {
        mainClockSettings[keyPath: keyPath] = value
        saveMainClockSettings()
    }

    /// Save main clock settings to UserDefaults
    private func saveMainClockSettings() {
        if let data = try? JSONEncoder().encode(mainClockSettings) {
            defaults.set(data, forKey: ClockSettings.mainClockKey)
        }
    }

    /// Migrate settings from old global @AppStorage keys to new ClockSettings model
    private static func migrateGlobalSettings() -> ClockSettings {
        let defaults = UserDefaults.standard

        return ClockSettings(
            fontColorName: defaults.string(forKey: "fontColorName") ?? "green",
            fontDesign: defaults.string(forKey: "fontDesign") ?? "rounded",
            glassStyle: defaults.string(forKey: "glassStyle") ?? "liquid",
            adjustableBlackOpacity: {
                let value = defaults.double(forKey: "adjustableBlackOpacity")
                return value != 0 ? value : 0.82
            }(),
            showSeconds: defaults.bool(forKey: "showSeconds"),
            use24HourFormat: defaults.bool(forKey: "use24HourFormat"),
            showBattery: defaults.bool(forKey: "showBattery"),
            alwaysOnTop: defaults.bool(forKey: "clockPresence.alwaysOnTop"),
            disappearOnHover: defaults.bool(forKey: "disappearOnHover"),
            clockOpacity: {
                let value = defaults.double(forKey: "clockOpacity")
                return value != 0 ? value : 1.0
            }()
        )
    }

    /// Perform one-time migration from old @AppStorage system
    /// Called on app launch to ensure migration happens exactly once
    func performMigrationIfNeeded() {
        let migrationKey = "hasPerformedClockSettingsMigration_v1"
        guard !defaults.bool(forKey: migrationKey) else { return }

        print("🔄 Performing clock settings migration...")

        // Migration happens automatically in init if no mainClockSettings exist
        // Just mark as complete
        defaults.set(true, forKey: migrationKey)

        print("✅ Clock settings migration completed")
    }
}

#endif
