// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  ClockSettings.swift
//
//  Per-window clock appearance settings
//

import Foundation

/// Encapsulates all appearance settings for a clock window
/// Allows each clock (main and world clocks) to have independent appearance
struct ClockSettings: Codable, Equatable {
    var fontColorName: String
    var fontDesign: String
    var glassStyle: String
    var adjustableBlackOpacity: Double
    var showSeconds: Bool
    var use24HourFormat: Bool
    var showBattery: Bool
    var alwaysOnTop: Bool
    var disappearOnHover: Bool
    var clockOpacity: Double
    var backgroundPhotoID: UUID?
    var backgroundPhotoAspectMode: String
    var backgroundPhotoOpacity: Double

    /// Default settings matching app defaults
    static let `default` = ClockSettings(
        fontColorName: "green",
        fontDesign: "rounded",
        glassStyle: "liquid",
        adjustableBlackOpacity: 0.82,
        showSeconds: false,
        use24HourFormat: false,
        showBattery: true,
        alwaysOnTop: true,
        disappearOnHover: true,
        clockOpacity: 1.0,
        backgroundPhotoID: nil,
        backgroundPhotoAspectMode: "fill",
        backgroundPhotoOpacity: 0.6
    )

    /// UserDefaults key for main clock settings
    static let mainClockKey = "mainClockSettings"

    init(
        fontColorName: String = "green",
        fontDesign: String = "rounded",
        glassStyle: String = "liquid",
        adjustableBlackOpacity: Double = 0.82,
        showSeconds: Bool = false,
        use24HourFormat: Bool = false,
        showBattery: Bool = true,
        alwaysOnTop: Bool = true,
        disappearOnHover: Bool = true,
        clockOpacity: Double = 1.0,
        backgroundPhotoID: UUID? = nil,
        backgroundPhotoAspectMode: String = "fill",
        backgroundPhotoOpacity: Double = 0.6
    ) {
        self.fontColorName = fontColorName
        self.fontDesign = fontDesign
        self.glassStyle = glassStyle
        self.adjustableBlackOpacity = adjustableBlackOpacity
        self.showSeconds = showSeconds
        self.use24HourFormat = use24HourFormat
        self.showBattery = showBattery
        self.alwaysOnTop = alwaysOnTop
        self.disappearOnHover = disappearOnHover
        self.clockOpacity = clockOpacity
        self.backgroundPhotoID = backgroundPhotoID
        self.backgroundPhotoAspectMode = backgroundPhotoAspectMode
        self.backgroundPhotoOpacity = backgroundPhotoOpacity
    }
}
