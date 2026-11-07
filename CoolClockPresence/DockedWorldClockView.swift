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
    var onAddWorldClock: (() -> Void)? = nil
    var onRedockToMainClock: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("worldClockDimmed") private var isWorldClockDimmed: Bool = true
    @StateObject private var worldClockManager = WorldClockManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var timelineRefresh: UUID = UUID()
    @State private var liveLocation: WorldClockLocation?
    private var timeOpacity: Double {
        isWorldClockDimmed ? 0.55 : 0.92
    }

    private var currentLocation: WorldClockLocation {
        liveLocation ?? location
    }

    private var unifiedWindowLocations: [WorldClockLocation] {
        worldClockManager.unifiedWindowLocationIDs.compactMap { id in
            worldClockManager.savedLocations.first(where: { $0.id == id })
        }
    }

    private var effectiveSettings: ClockSettings {
        currentLocation.settings
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
                            fillColor: fontColor.opacity(timeOpacity),
                            strokeColor: outlineColor,
                            lineWidth: max(0.5, 0.9 * scale)
                        )
                        BlinkingColon(
                            text: timeComponents(from: context.date).separator,
                            font: clockFont(for: scale),
                            fillColor: fontColor.opacity(timeOpacity),
                            strokeColor: outlineColor,
                            lineWidth: max(0.5, 0.9 * scale),
                            shouldBlink: !shouldShowSeconds,
                            isOutlined: true
                        )
                        OutlinedText(
                            text: timeComponents(from: context.date).minutes,
                            font: clockFont(for: scale),
                            fillColor: fontColor.opacity(timeOpacity),
                            strokeColor: outlineColor,
                            lineWidth: max(0.5, 0.9 * scale)
                        )
                        if let secondsPart = timeComponents(from: context.date).seconds {
                            OutlinedText(
                                text: ":",
                                font: clockFont(for: scale),
                                fillColor: fontColor.opacity(timeOpacity),
                                strokeColor: outlineColor,
                                lineWidth: max(0.5, 0.9 * scale)
                            )
                            OutlinedText(
                                text: secondsPart,
                                font: clockFont(for: scale),
                                fillColor: fontColor.opacity(timeOpacity),
                                strokeColor: outlineColor,
                                lineWidth: max(0.5, 0.9 * scale)
                            )
                        }
                        if let ampm = timeComponents(from: context.date).ampm {
                            OutlinedText(
                                text: ampm,
                                font: .system(size: 16 * scale, weight: .medium, design: .rounded),
                                fillColor: fontColor.opacity(timeOpacity),
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
                            .foregroundStyle(fontColor.opacity(timeOpacity))
                        BlinkingColon(
                            text: timeComponents(from: context.date).separator,
                            font: clockFont(for: scale),
                            fillColor: fontColor.opacity(timeOpacity),
                            strokeColor: .clear,
                            lineWidth: 0,
                            shouldBlink: !shouldShowSeconds,
                            isOutlined: false
                        )
                        Text(timeComponents(from: context.date).minutes)
                            .font(clockFont(for: scale))
                            .monospacedDigit()
                            .foregroundStyle(fontColor.opacity(timeOpacity))
                        if let secondsPart = timeComponents(from: context.date).seconds {
                            Text(":")
                                .font(clockFont(for: scale))
                                .monospacedDigit()
                                .foregroundStyle(fontColor.opacity(timeOpacity))
                            Text(secondsPart)
                                .font(clockFont(for: scale))
                                .monospacedDigit()
                                .foregroundStyle(fontColor.opacity(timeOpacity))
                        }
                        if let ampm = timeComponents(from: context.date).ampm {
                            Text(ampm)
                                .font(.system(size: 16 * scale, weight: .medium, design: .rounded))
                                .foregroundStyle(fontColor.opacity(timeOpacity))
                                .padding(.leading, 2 * scale)
                        }
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                }
            }
            .id(timelineRefresh)

            // Location name (constant brightness)
            Text(currentLocation.displayName)
                .font(locationFont(for: scale))
                .foregroundStyle(fontColor.opacity(0.92))
        }
        .contextMenu {
            if let onAddWorldClock {
                Button("Add World Clock…", action: onAddWorldClock)
                Divider()
            }

            if let onRedockToMainClock {
                if unifiedWindowLocations.count > 1 {
                    Menu("Redock to Main Clock") {
                        Button("All World Clocks") {
                            worldClockManager.redockAllUnifiedClocks()
                        }

                        Divider()

                        ForEach(unifiedWindowLocations) { unifiedLocation in
                            Button(unifiedLocation.displayName) {
                                worldClockManager.dockClock(for: unifiedLocation.id)
                            }
                        }
                    }
                } else {
                    Button("Redock to Main Clock", action: onRedockToMainClock)
                }
            } else {
                Menu("Undock") {
                    Button("This World Clock") {
                        WorldClockManager.shared.undockClock(for: location.id)
                    }
                    Button("All World Clocks Together") {
                        WorldClockManager.shared.undockAllClocks()
                    }
                }

                Button("Remove from Dock") {
                    worldClockManager.hideLocation(id: location.id)
                }
            }

            Button("Manage World Clocks...") {
                performMenuAction(#selector(AppDelegate.showManageWorldClocks))
            }

            Button {
                isWorldClockDimmed.toggle()
            } label: {
                if isWorldClockDimmed {
                    Label("Dim World Clock", systemImage: "checkmark")
                } else {
                    Text("Dim World Clock")
                }
            }

            Divider()

            Menu("Font Color") {
                dockedFontColorButton("White", color: "white")
                dockedFontColorButton("Green", color: "green")
                if purchaseManager.isPremium {
                    Divider()
                    dockedFontColorButton("Black", color: "black")
                    dockedFontColorButton("Cyan", color: "cyan")
                    dockedFontColorButton("Red", color: "red")
                    dockedFontColorButton("Orange", color: "orange")
                    dockedFontColorButton("Yellow", color: "yellow")
                    dockedFontColorButton("Blue", color: "blue")
                    dockedFontColorButton("Purple", color: "purple")
                    dockedFontColorButton("Pink", color: "pink")
                    dockedFontColorButton("Mint", color: "mint")
                    dockedFontColorButton("Teal", color: "teal")
                    dockedFontColorButton("Indigo", color: "indigo")
                }
            }

            if worldClockManager.isInUnifiedWindow(location.id),
               worldClockManager.unifiedWindowLocationIDs.count > 1 {
                Menu("All Clocks Font Color") {
                    allClocksFontColorButton("White", color: "white")
                    allClocksFontColorButton("Green", color: "green")
                    if purchaseManager.isPremium {
                        Divider()
                        allClocksFontColorButton("Black", color: "black")
                        allClocksFontColorButton("Cyan", color: "cyan")
                        allClocksFontColorButton("Red", color: "red")
                        allClocksFontColorButton("Orange", color: "orange")
                        allClocksFontColorButton("Yellow", color: "yellow")
                        allClocksFontColorButton("Blue", color: "blue")
                        allClocksFontColorButton("Purple", color: "purple")
                        allClocksFontColorButton("Pink", color: "pink")
                        allClocksFontColorButton("Mint", color: "mint")
                        allClocksFontColorButton("Teal", color: "teal")
                        allClocksFontColorButton("Indigo", color: "indigo")
                    }
                }
            }

            Menu("Font Style") {
                dockedFontStyleButton("Rounded (Default)", style: "rounded")
                dockedFontStyleButton("Monospaced", style: "monospaced")
                dockedFontStyleButton("Serif", style: "serif")
                dockedFontStyleButton("Time Circuit (LED)", style: "led")
                Divider()
                dockedFontStyleButton("Ultra Light", style: "ultralight")
                dockedFontStyleButton("Thin", style: "thin")
                dockedFontStyleButton("Light", style: "light")
                dockedFontStyleButton("Medium", style: "medium")
                dockedFontStyleButton("Bold", style: "bold")
                dockedFontStyleButton("Heavy", style: "heavy")
                dockedFontStyleButton("Black", style: "black")
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
        .onReceive(worldClockManager.$savedLocations) { updatedLocations in
            syncLocation(from: updatedLocations)
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

    @ViewBuilder private func dockedFontColorButton(_ title: String, color: String) -> some View {
        Button { updateSetting(\.fontColorName, value: color) } label: {
            if effectiveSettings.fontColorName == color { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }

    @ViewBuilder private func dockedFontStyleButton(_ title: String, style: String) -> some View {
        Button { updateSetting(\.fontDesign, value: style) } label: {
            if effectiveSettings.fontDesign == style { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }

    @ViewBuilder private func allClocksFontColorButton(_ title: String, color: String) -> some View {
        Button {
            worldClockManager.updateUnifiedClockSettings(\.fontColorName, value: color)
        } label: {
            Text(title)
        }
    }

    private func updateSetting<T>(_ keyPath: WritableKeyPath<ClockSettings, T>, value: T) {
        var updatedSettings = currentLocation.settings
        updatedSettings[keyPath: keyPath] = value
        worldClockManager.updateClockSettings(for: location.id, settings: updatedSettings)
        cacheUpdatedSettings(updatedSettings)
        timelineRefresh = UUID()
    }

    private func syncLocation() {
        if let updated = worldClockManager.savedLocations.first(where: { $0.id == location.id }) {
            liveLocation = updated
        }
    }

    private func syncLocation(from locations: [WorldClockLocation]) {
        if let updated = locations.first(where: { $0.id == location.id }) {
            liveLocation = updated
        }
    }

    private func cacheUpdatedSettings(_ newSettings: ClockSettings) {
        var updated = currentLocation
        updated.settings = newSettings
        liveLocation = updated
    }

    private func performMenuAction(_ selector: Selector) {
        let send = {
            if !NSApp.sendAction(selector, to: NSApp.delegate, from: nil) {
                NSApp.sendAction(selector, to: nil, from: nil)
            }
        }

        if Thread.isMainThread {
            send()
        } else {
            DispatchQueue.main.async(execute: send)
        }
    }
}

#endif
