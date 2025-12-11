// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  DockedWorldClockView.swift
//
//  Compact world clock view for docking inside main clock window
//

#if os(macOS)
import SwiftUI
import AppKit

/// A compact world clock view that displays inside the main clock window
/// 70% smaller than main clock, shows time + location name with independent settings
struct DockedWorldClockView: View {
    let location: WorldClockLocation
    let scale: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var settingsManager = ClockSettingsManager.shared
    @StateObject private var worldClockManager = WorldClockManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var timelineRefresh: UUID = UUID()
    @State private var liveLocation: WorldClockLocation?

    private var currentLocation: WorldClockLocation {
        liveLocation ?? location
    }

    // Docked clocks always mirror the main clock's font family and color
    private var effectiveSettings: ClockSettings {
        var settings = currentLocation.settings
        settings.fontColorName = settingsManager.mainClockSettings.fontColorName
        settings.fontDesign = settingsManager.mainClockSettings.fontDesign
        return settings
    }

    private var timeZone: TimeZone {
        currentLocation.timeZone ?? .current
    }

    private var fontColor: Color {
        switch effectiveSettings.fontColorName {
        case "white": return .white
        case "black": return .black
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return Color(red: 1.0, green: 0.75, blue: 0.8)
        case "cyan": return Color(red: 0.00, green: 0.78, blue: 1.00)
        case "mint": return Color(red: 0.16, green: 0.90, blue: 0.64)
        case "teal": return Color(red: 0.00, green: 0.64, blue: 0.68)
        case "indigo": return .indigo
        case "primary": return .primary
        default: return .green
        }
    }

    private var outlineColor: Color {
        if colorScheme == .dark {
            return Color(white: 0.88)
        } else {
            return Color.black.opacity(0.78)
        }
    }

    private func clockFont(for scale: CGFloat) -> Font {
        let fontSize = 32 * scale  // 84% of main clock (38pt)

        switch effectiveSettings.fontDesign {
        case "rounded":
            return .system(size: fontSize, weight: .semibold, design: .rounded)
        case "monospaced":
            return .system(size: fontSize, weight: .semibold, design: .monospaced)
        case "serif":
            return .system(size: fontSize, weight: .semibold, design: .serif)
        case "led":
            return Font.custom("DSEG7Classic-Bold", size: fontSize)
        case "ultralight":
            return .system(size: fontSize, weight: .ultraLight, design: .default)
        case "thin":
            return .system(size: fontSize, weight: .thin, design: .default)
        case "light":
            return .system(size: fontSize, weight: .light, design: .default)
        case "medium":
            return .system(size: fontSize, weight: .medium, design: .default)
        case "bold":
            return .system(size: fontSize, weight: .bold, design: .default)
        case "heavy":
            return .system(size: fontSize, weight: .heavy, design: .default)
        case "black":
            return .system(size: fontSize, weight: .black, design: .default)
        default:
            return .system(size: fontSize, weight: .semibold, design: .rounded)
        }
    }

    private func locationFont(for scale: CGFloat) -> Font {
        let fontSize = 14 * scale
        return .system(size: fontSize, weight: .medium, design: .rounded)
    }

    private func timeComponents(from date: Date) -> (hours: String, separator: String, minutes: String, seconds: String?, ampm: String?) {
        if currentLocation.settings.use24HourFormat {
            let calendar = Calendar.autoupdatingCurrent
            let components = calendar.dateComponents(in: timeZone, from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0

            if currentLocation.settings.showSeconds && purchaseManager.isPremium {
                let second = components.second ?? 0
                return (String(format: "%02d", hour), ":", String(format: "%02d", minute), String(format: "%02d", second), nil)
            }

            return (String(format: "%02d", hour), ":", String(format: "%02d", minute), nil, nil)
        }

        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents(in: timeZone, from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        // Convert to 12-hour format
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm = hour >= 12 ? "PM" : "AM"

        if currentLocation.settings.showSeconds && purchaseManager.isPremium {
            let second = components.second ?? 0
            return (String(format: "%d", displayHour), ":", String(format: "%02d", minute), String(format: "%02d", second), ampm)
        }

        return (String(format: "%d", displayHour), ":", String(format: "%02d", minute), nil, ampm)
    }

    var body: some View {
        VStack(spacing: 2 * scale) {
            // Time display (28pt base vs 38pt for main clock = 70% smaller)
            let updateInterval: TimeInterval = (currentLocation.settings.showSeconds && purchaseManager.isPremium) ? 1.0 : 60.0

            TimelineView(.periodic(from: Date(), by: updateInterval)) { context in
                let shouldShowSeconds = currentLocation.settings.showSeconds && purchaseManager.isPremium

                if effectiveSettings.fontColorName == "black" {
                    HStack(spacing: 0) {
                        OutlinedText(
                            text: timeComponents(from: context.date).hours,
                            font: clockFont(for: scale),
                            fillColor: fontColor.opacity(0.92),
                            strokeColor: outlineColor,
                            lineWidth: max(0.5, 0.9 * scale)
                        )
                        BlinkingColon(
                            text: timeComponents(from: context.date).separator,
                            font: clockFont(for: scale),
                            fillColor: fontColor,
                            strokeColor: outlineColor,
                            lineWidth: max(0.5, 0.9 * scale),
                            shouldBlink: !shouldShowSeconds,
                            isOutlined: true
                        )
                        OutlinedText(
                            text: timeComponents(from: context.date).minutes,
                            font: clockFont(for: scale),
                            fillColor: fontColor.opacity(0.92),
                            strokeColor: outlineColor,
                            lineWidth: max(0.5, 0.9 * scale)
                        )
                        if let secondsPart = timeComponents(from: context.date).seconds {
                            OutlinedText(
                                text: ":",
                                font: clockFont(for: scale),
                                fillColor: fontColor.opacity(0.92),
                                strokeColor: outlineColor,
                                lineWidth: max(0.5, 0.9 * scale)
                            )
                            OutlinedText(
                                text: secondsPart,
                                font: clockFont(for: scale),
                                fillColor: fontColor.opacity(0.92),
                                strokeColor: outlineColor,
                                lineWidth: max(0.5, 0.9 * scale)
                            )
                        }
                        if let ampm = timeComponents(from: context.date).ampm {
                            OutlinedText(
                                text: ampm,
                                font: .system(size: 16 * scale, weight: .medium, design: .rounded),
                                fillColor: fontColor.opacity(0.92),
                                strokeColor: outlineColor,
                                lineWidth: max(0.5, 0.9 * scale)
                            )
                            .padding(.leading, 2 * scale)
                        }
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                } else {
                    HStack(spacing: 0) {
                        Text(timeComponents(from: context.date).hours)
                            .font(clockFont(for: scale))
                            .monospacedDigit()
                            .foregroundStyle(fontColor.opacity(0.92))
                        BlinkingColon(
                            text: timeComponents(from: context.date).separator,
                            font: clockFont(for: scale),
                            fillColor: fontColor,
                            strokeColor: .clear,
                            lineWidth: 0,
                            shouldBlink: !shouldShowSeconds,
                            isOutlined: false
                        )
                        Text(timeComponents(from: context.date).minutes)
                            .font(clockFont(for: scale))
                            .monospacedDigit()
                            .foregroundStyle(fontColor.opacity(0.92))
                        if let secondsPart = timeComponents(from: context.date).seconds {
                            Text(":")
                                .font(clockFont(for: scale))
                                .monospacedDigit()
                                .foregroundStyle(fontColor.opacity(0.92))
                            Text(secondsPart)
                                .font(clockFont(for: scale))
                                .monospacedDigit()
                                .foregroundStyle(fontColor.opacity(0.92))
                        }
                        if let ampm = timeComponents(from: context.date).ampm {
                            Text(ampm)
                                .font(.system(size: 16 * scale, weight: .medium, design: .rounded))
                                .foregroundStyle(fontColor.opacity(0.92))
                                .padding(.leading, 2 * scale)
                        }
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                }
            }
            .id(timelineRefresh)

            // Location name (smaller, dimmer)
            Text(currentLocation.displayName)
                .font(locationFont(for: scale))
                .foregroundStyle(fontColor.opacity(0.60))
        }
        .contextMenu {
            Button("Undock") {
                WorldClockManager.shared.undockClock(for: location.id)
            }

            Button("Remove World Clock") {
                WorldClockManager.shared.removeLocation(id: location.id)
            }

            Divider()

            if purchaseManager.isPremium {
                Toggle("Show Seconds", isOn: clockSettingsBinding(\.showSeconds))
                Toggle("Use 24-Hour Format", isOn: clockSettingsBinding(\.use24HourFormat))
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSSystemClockDidChange,
                object: nil,
                queue: .main
            ) { _ in
                timelineRefresh = UUID()
            }
            syncLocation()
        }
        .onReceive(worldClockManager.$savedLocations) { _ in
            syncLocation()
        }
    }

    private func clockSettingsBinding(_ keyPath: WritableKeyPath<ClockSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { currentLocation.settings[keyPath: keyPath] },
            set: { newValue in
                var updatedSettings = currentLocation.settings
                updatedSettings[keyPath: keyPath] = newValue
                WorldClockManager.shared.updateClockSettings(for: location.id, settings: updatedSettings)
                cacheUpdatedSettings(updatedSettings)
                timelineRefresh = UUID()
            }
        )
    }

    private func syncLocation() {
        if let updated = worldClockManager.savedLocations.first(where: { $0.id == location.id }) {
            liveLocation = updated
        }
    }

    private func cacheUpdatedSettings(_ newSettings: ClockSettings) {
        var updated = currentLocation
        updated.settings = newSettings
        liveLocation = updated
    }
}

#endif
