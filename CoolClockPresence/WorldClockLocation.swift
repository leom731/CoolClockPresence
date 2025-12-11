// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  WorldClockLocation.swift
//
//  Data model for world clock locations
//

import Foundation
import CoreGraphics

/// Represents a world clock location with timezone and display information
struct WorldClockLocation: Codable, Identifiable, Equatable {
    let id: UUID
    let displayName: String        // e.g., "New York" or "Tokyo, Japan"
    let timeZoneIdentifier: String // e.g., "America/New_York"
    var windowX: Double
    var windowY: Double
    var windowWidth: Double
    var windowHeight: Double

    // Per-window appearance settings
    var settings: ClockSettings

    // Docking state
    var isDocked: Bool
    var dockedOrder: Int

    init(
        id: UUID = UUID(),
        displayName: String,
        timeZoneIdentifier: String,
        windowX: Double = -1,
        windowY: Double = -1,
        windowWidth: Double = 280,
        windowHeight: Double = 120,
        settings: ClockSettings = .default,
        isDocked: Bool = false,
        dockedOrder: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.windowX = windowX
        self.windowY = windowY
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.settings = settings
        self.isDocked = isDocked
        self.dockedOrder = dockedOrder
    }

    /// The TimeZone object for this location
    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }

    /// Helper for managing window frame
    var undockedFrame: CGRect? {
        get { CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight) }
        set {
            if let frame = newValue {
                windowX = frame.origin.x
                windowY = frame.origin.y
                windowWidth = frame.size.width
                windowHeight = frame.size.height
            }
        }
    }

    static func == (lhs: WorldClockLocation, rhs: WorldClockLocation) -> Bool {
        lhs.id == rhs.id
    }
}

/// Predefined popular locations for easy selection
extension WorldClockLocation {
    static let popularLocations: [WorldClockLocation] = [
        // US States (Major Cities)
        WorldClockLocation(displayName: "New York, NY", timeZoneIdentifier: "America/New_York"),
        WorldClockLocation(displayName: "Los Angeles, CA", timeZoneIdentifier: "America/Los_Angeles"),
        WorldClockLocation(displayName: "Chicago, IL", timeZoneIdentifier: "America/Chicago"),
        WorldClockLocation(displayName: "Houston, TX", timeZoneIdentifier: "America/Chicago"),
        WorldClockLocation(displayName: "Phoenix, AZ", timeZoneIdentifier: "America/Phoenix"),
        WorldClockLocation(displayName: "Miami, FL", timeZoneIdentifier: "America/New_York"),
        WorldClockLocation(displayName: "Seattle, WA", timeZoneIdentifier: "America/Los_Angeles"),
        WorldClockLocation(displayName: "Denver, CO", timeZoneIdentifier: "America/Denver"),
        WorldClockLocation(displayName: "Atlanta, GA", timeZoneIdentifier: "America/New_York"),
        WorldClockLocation(displayName: "Boston, MA", timeZoneIdentifier: "America/New_York"),
        WorldClockLocation(displayName: "Las Vegas, NV", timeZoneIdentifier: "America/Los_Angeles"),
        WorldClockLocation(displayName: "Honolulu, HI", timeZoneIdentifier: "Pacific/Honolulu"),
        WorldClockLocation(displayName: "Anchorage, AK", timeZoneIdentifier: "America/Anchorage"),

        // International Cities
        WorldClockLocation(displayName: "London, UK", timeZoneIdentifier: "Europe/London"),
        WorldClockLocation(displayName: "Paris, France", timeZoneIdentifier: "Europe/Paris"),
        WorldClockLocation(displayName: "Tokyo, Japan", timeZoneIdentifier: "Asia/Tokyo"),
        WorldClockLocation(displayName: "Sydney, Australia", timeZoneIdentifier: "Australia/Sydney"),
        WorldClockLocation(displayName: "Dubai, UAE", timeZoneIdentifier: "Asia/Dubai"),
        WorldClockLocation(displayName: "Singapore", timeZoneIdentifier: "Asia/Singapore"),
        WorldClockLocation(displayName: "Hong Kong", timeZoneIdentifier: "Asia/Hong_Kong"),
        WorldClockLocation(displayName: "Mumbai, India", timeZoneIdentifier: "Asia/Kolkata"),
        WorldClockLocation(displayName: "Berlin, Germany", timeZoneIdentifier: "Europe/Berlin"),
        WorldClockLocation(displayName: "Rome, Italy", timeZoneIdentifier: "Europe/Rome"),
        WorldClockLocation(displayName: "Madrid, Spain", timeZoneIdentifier: "Europe/Madrid"),
        WorldClockLocation(displayName: "Amsterdam, Netherlands", timeZoneIdentifier: "Europe/Amsterdam"),
        WorldClockLocation(displayName: "Istanbul, Turkey", timeZoneIdentifier: "Europe/Istanbul"),
        WorldClockLocation(displayName: "Moscow, Russia", timeZoneIdentifier: "Europe/Moscow"),
        WorldClockLocation(displayName: "Beijing, China", timeZoneIdentifier: "Asia/Shanghai"),
        WorldClockLocation(displayName: "Seoul, South Korea", timeZoneIdentifier: "Asia/Seoul"),
        WorldClockLocation(displayName: "Bangkok, Thailand", timeZoneIdentifier: "Asia/Bangkok"),
        WorldClockLocation(displayName: "Manila, Philippines", timeZoneIdentifier: "Asia/Manila"),
        WorldClockLocation(displayName: "São Paulo, Brazil", timeZoneIdentifier: "America/Sao_Paulo"),
        WorldClockLocation(displayName: "Mexico City, Mexico", timeZoneIdentifier: "America/Mexico_City"),
        WorldClockLocation(displayName: "Toronto, Canada", timeZoneIdentifier: "America/Toronto"),
        WorldClockLocation(displayName: "Vancouver, Canada", timeZoneIdentifier: "America/Vancouver"),
        WorldClockLocation(displayName: "Auckland, New Zealand", timeZoneIdentifier: "Pacific/Auckland"),
        WorldClockLocation(displayName: "Cairo, Egypt", timeZoneIdentifier: "Africa/Cairo"),
        WorldClockLocation(displayName: "Jerusalem, Israel", timeZoneIdentifier: "Asia/Jerusalem"),
        WorldClockLocation(displayName: "Johannesburg, South Africa", timeZoneIdentifier: "Africa/Johannesburg"),
    ]

    /// Categories for organizing locations
    enum Category: String, CaseIterable {
        case usStates = "United States"
        case international = "International"
        case all = "All Locations"

        func locations() -> [WorldClockLocation] {
            switch self {
            case .usStates:
                return WorldClockLocation.popularLocations.filter { $0.timeZoneIdentifier.hasPrefix("America/") || $0.timeZoneIdentifier.hasPrefix("Pacific/") }
            case .international:
                return WorldClockLocation.popularLocations.filter { !$0.timeZoneIdentifier.hasPrefix("America/") && !$0.timeZoneIdentifier.hasPrefix("Pacific/") }
            case .all:
                return WorldClockLocation.popularLocations
            }
        }
    }
}
