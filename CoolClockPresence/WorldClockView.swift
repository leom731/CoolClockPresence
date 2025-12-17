// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  WorldClockView.swift
//
//  World clock display showing time in different timezones
//

#if os(macOS)
import SwiftUI
import AppKit
import Combine

/// A world clock that displays time for a specific timezone
struct WorldClockView: View {
    let location: WorldClockLocation
    let timeZone: TimeZone

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var worldClockManager = WorldClockManager.shared
    @State private var isHovering: Bool = false
    @State private var isCommandKeyPressed: Bool = false
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingPurchaseSheet = false
    @State private var showingLocationPicker = false
    @State private var mouseLocation: CGPoint = .zero
    @State private var showResizeHints: Bool = false
    @State private var timelineRefresh: UUID = UUID()
    @State private var liveLocation: WorldClockLocation?

    private var currentLocation: WorldClockLocation {
        liveLocation ?? location
    }

    private var activeTimeZone: TimeZone {
        currentLocation.timeZone ?? timeZone
    }

    // Convenience accessors for per-window settings
    private var fontColorName: String { currentLocation.settings.fontColorName }
    private var showSeconds: Bool { currentLocation.settings.showSeconds }
    private var isAlwaysOnTop: Bool { currentLocation.settings.alwaysOnTop }
    private var disappearOnHover: Bool { currentLocation.settings.disappearOnHover }
    private var clockOpacity: Double { currentLocation.settings.clockOpacity }
    private var use24HourFormat: Bool { currentLocation.settings.use24HourFormat }
    private var glassStyle: String { currentLocation.settings.glassStyle }
    private var adjustableBlackOpacity: Double { currentLocation.settings.adjustableBlackOpacity }
    private var fontDesign: String { currentLocation.settings.fontDesign }
    private var dockDragEnabled: Bool {
        // Prevent dock-drag when the window is ignoring mouse events (disappear-on-hover)
        isCommandKeyPressed && !(purchaseManager.isPremium && disappearOnHover && isHovering)
    }

    private var appDelegate: AppDelegate? {
        NSApplication.shared.delegate as? AppDelegate
    }

    private var fontColor: Color {
        switch fontColorName {
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

    private let baseSize = CGSize(width: 240, height: 100)
    private let timeOpacity: Double = 0.55

    private func scale(for size: CGSize) -> CGFloat {
        let widthScale = size.width / baseSize.width
        let heightScale = size.height / baseSize.height
        return min(widthScale, heightScale)
    }

    private func clockFont(for scale: CGFloat) -> Font {
        let fontSize = 38 * scale

        switch fontDesign {
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
        let fontSize = 16 * scale
        return .system(size: fontSize, weight: .medium, design: .rounded)
    }

    private func timeComponents(from date: Date) -> (hours: String, separator: String, minutes: String, seconds: String?, ampm: String?) {
        if use24HourFormat {
            let calendar = Calendar.autoupdatingCurrent
            let components = calendar.dateComponents(in: activeTimeZone, from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0

            if showSeconds && purchaseManager.isPremium {
                let second = components.second ?? 0
                return (String(format: "%02d", hour), ":", String(format: "%02d", minute), String(format: "%02d", second), nil)
            }

            return (String(format: "%02d", hour), ":", String(format: "%02d", minute), nil, nil)
        }

        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents(in: activeTimeZone, from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        // Convert to 12-hour format
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm = hour >= 12 ? "PM" : "AM"

        if showSeconds && purchaseManager.isPremium {
            let second = components.second ?? 0
            return (String(format: "%d", displayHour), ":", String(format: "%02d", minute), String(format: "%02d", second), ampm)
        }

        return (String(format: "%d", displayHour), ":", String(format: "%02d", minute), nil, ampm)
    }

    private func outlineColorForBackground() -> Color {
        if colorScheme == .dark {
            return Color(white: 0.88)
        } else {
            return Color.black.opacity(0.78)
        }
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

    var body: some View {
        GeometryReader { geometry in
            let currentScale = scale(for: geometry.size)
            let strokeColor = outlineColorForBackground()
            ZStack {
                GlassBackdrop(style: glassStyle, adjustableOpacity: adjustableBlackOpacity)

                VStack(spacing: 4 * currentScale) {
                    // Update every second if seconds are shown, otherwise every minute
                    let updateInterval: TimeInterval = (showSeconds && purchaseManager.isPremium) ? 1.0 : 60.0
                    TimelineView(.periodic(from: Date(), by: updateInterval)) { context in
                        let shouldShowSeconds = showSeconds && purchaseManager.isPremium

                        if fontColorName == "black" {
                            HStack(spacing: 0) {
                                OutlinedText(
                                    text: timeComponents(from: context.date).hours,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor.opacity(timeOpacity),
                                    strokeColor: strokeColor,
                                    lineWidth: max(0.5, 1.1 * currentScale)
                                )
                                BlinkingColon(
                                    text: timeComponents(from: context.date).separator,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor.opacity(timeOpacity),
                                    strokeColor: strokeColor,
                                    lineWidth: max(0.5, 1.1 * currentScale),
                                    shouldBlink: !shouldShowSeconds,
                                    isOutlined: true
                                )
                                OutlinedText(
                                    text: timeComponents(from: context.date).minutes,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor.opacity(timeOpacity),
                                    strokeColor: strokeColor,
                                    lineWidth: max(0.5, 1.1 * currentScale)
                                )
                                if let secondsPart = timeComponents(from: context.date).seconds {
                                    OutlinedText(
                                        text: ":",
                                        font: clockFont(for: currentScale),
                                        fillColor: fontColor.opacity(timeOpacity),
                                        strokeColor: strokeColor,
                                        lineWidth: max(0.5, 1.1 * currentScale)
                                    )
                                    OutlinedText(
                                        text: secondsPart,
                                        font: clockFont(for: currentScale),
                                        fillColor: fontColor.opacity(timeOpacity),
                                        strokeColor: strokeColor,
                                        lineWidth: max(0.5, 1.1 * currentScale)
                                    )
                                }
                                if let ampm = timeComponents(from: context.date).ampm {
                                    OutlinedText(
                                        text: ampm,
                                        font: .system(size: 20 * currentScale, weight: .medium, design: .rounded),
                                        fillColor: fontColor.opacity(timeOpacity),
                                        strokeColor: strokeColor,
                                        lineWidth: max(0.5, 1.1 * currentScale)
                                    )
                                    .padding(.leading, 2 * currentScale)
                                }
                            }
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        } else {
                            HStack(spacing: 0) {
                                Text(timeComponents(from: context.date).hours)
                                    .font(clockFont(for: currentScale))
                                    .monospacedDigit()
                                    .foregroundStyle(fontColor.opacity(timeOpacity))
                                BlinkingColon(
                                    text: timeComponents(from: context.date).separator,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor.opacity(timeOpacity),
                                    strokeColor: .clear,
                                    lineWidth: 0,
                                    shouldBlink: !shouldShowSeconds,
                                    isOutlined: false
                                )
                                Text(timeComponents(from: context.date).minutes)
                                    .font(clockFont(for: currentScale))
                                    .monospacedDigit()
                                    .foregroundStyle(fontColor.opacity(timeOpacity))
                                if let secondsPart = timeComponents(from: context.date).seconds {
                                    Text(":")
                                        .font(clockFont(for: currentScale))
                                        .monospacedDigit()
                                        .foregroundStyle(fontColor.opacity(timeOpacity))
                                    Text(secondsPart)
                                        .font(clockFont(for: currentScale))
                                        .monospacedDigit()
                                        .foregroundStyle(fontColor.opacity(timeOpacity))
                                }
                                if let ampm = timeComponents(from: context.date).ampm {
                                    Text(ampm)
                                        .font(.system(size: 20 * currentScale, weight: .medium, design: .rounded))
                                        .foregroundStyle(fontColor.opacity(timeOpacity))
                                        .padding(.leading, 2 * currentScale)
                                }
                            }
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        }
                    }
                    .id(timelineRefresh)

                    // Location name below clock
                    Text(currentLocation.displayName)
                        .font(locationFont(for: currentScale))
                        .foregroundStyle(fontColor.opacity(0.92))
                        .padding(.top, 2 * currentScale)
                }
                .padding(.vertical, 8 * currentScale)
                .padding(.horizontal, 10 * currentScale)
            }
            .contentShape(Rectangle())
            .modifier(
                DockDragModifier(
                    isEnabled: dockDragEnabled,
                    provider: {
                        let provider = NSItemProvider()
                        provider.registerDataRepresentation(forTypeIdentifier: "com.coolclock.worldclock", visibility: .all) { completion in
                            let data = location.id.uuidString.data(using: .utf8)
                            completion(data, nil)
                            return nil
                        }
                        return provider
                    }
                )
            )
            .contextMenu {
                Button("Dock to Main Clock") {
                    WorldClockManager.shared.dockClock(for: location.id)
                }

                Button("Change Location…") {
                    showingLocationPicker = true
                }

                Button("Close This World Clock") {
                    WorldClockManager.shared.closeWorldClock(for: location.id)
                }

                Button("Hide World Clock") {
                    WorldClockManager.shared.hideLocation(id: location.id)
                }

                Button("Manage World Clocks...") {
                    performMenuAction(#selector(AppDelegate.showManageWorldClocks))
                }

                Divider()

                Menu("Font Color") {
                    fontColorButton(title: "White", colorName: "white")
                    fontColorButton(title: "Green", colorName: "green")

                    if purchaseManager.isPremium {
                        Divider()
                        fontColorButton(title: "Black", colorName: "black")
                        fontColorButton(title: "Cyan", colorName: "cyan")
                        fontColorButton(title: "Red", colorName: "red")
                        fontColorButton(title: "Orange", colorName: "orange")
                        fontColorButton(title: "Yellow", colorName: "yellow")
                        fontColorButton(title: "Blue", colorName: "blue")
                        fontColorButton(title: "Purple", colorName: "purple")
                        fontColorButton(title: "Pink", colorName: "pink")
                        fontColorButton(title: "Mint", colorName: "mint")
                        fontColorButton(title: "Teal", colorName: "teal")
                        fontColorButton(title: "Indigo", colorName: "indigo")
                    }
                }

                Menu("Font Style") {
                    fontStyleButton(title: "Rounded (Default)", fontName: "rounded")
                    fontStyleButton(title: "Monospaced", fontName: "monospaced")
                    fontStyleButton(title: "Serif", fontName: "serif")
                    fontStyleButton(title: "Time Circuit (LED)", fontName: "led")
                    Divider()
                    fontStyleButton(title: "Ultra Light", fontName: "ultralight")
                    fontStyleButton(title: "Thin", fontName: "thin")
                    fontStyleButton(title: "Light", fontName: "light")
                    fontStyleButton(title: "Medium", fontName: "medium")
                    fontStyleButton(title: "Bold", fontName: "bold")
                    fontStyleButton(title: "Heavy", fontName: "heavy")
                    fontStyleButton(title: "Black", fontName: "black")
                }

                Divider()

                Button("Glass Style…") {
                    performMenuAction(#selector(AppDelegate.showGlassStyleMenuFromContextMenu))
                }

                Divider()

                // Premium features (excluding battery)
                if purchaseManager.isPremium {
                    Toggle("Show Seconds", isOn: settingsBinding(\.showSeconds))
                    Toggle("Use 24-Hour Format", isOn: settingsBinding(\.use24HourFormat))
                    Toggle("Always on Top", isOn: settingsBinding(\.alwaysOnTop))
                    Toggle("Disappear on Hover", isOn: settingsBinding(\.disappearOnHover))
                } else {
                    Button("Show Seconds 🔒 Premium") {
                        showingPurchaseSheet = true
                    }
                    Button("Use 24-Hour Format 🔒 Premium") {
                        showingPurchaseSheet = true
                    }
                    Button("Always on Top 🔒 Premium") {
                        showingPurchaseSheet = true
                    }
                    Button("Disappear on Hover 🔒 Premium") {
                        showingPurchaseSheet = true
                    }
                }

                Divider()

                if !purchaseManager.isPremium {
                    Button("⭐️ Upgrade to Premium ($1.99)") {
                        showingPurchaseSheet = true
                    }
                    Divider()
                }

                Button("Settings…") {
                    performMenuAction(#selector(AppDelegate.openSettingsWindow))
                }

                Button("About CoolClockPresence") {
                    performMenuAction(#selector(AppDelegate.showAbout))
                }

                Button("Help") {
                    performMenuAction(#selector(AppDelegate.showHelpWindow))
                }
            }
            .sheet(isPresented: $showingPurchaseSheet) {
                PurchaseView()
            }
            .sheet(isPresented: $showingLocationPicker) {
                WorldClockPickerView { newLocation in
                    worldClockManager.replaceLocation(id: location.id, with: newLocation)
                    showingLocationPicker = false
                }
            }
        }
        .overlay(
            HoverAndWindowController(
                isHovering: $isHovering,
                isCommandKeyPressed: $isCommandKeyPressed,
                isPremium: purchaseManager.isPremium,
                disappearOnHover: disappearOnHover,
                mouseLocation: $mouseLocation,
                showResizeHints: $showResizeHints
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        )
        .overlay(
            GeometryReader { geometry in
                if showResizeHints {
                    ResizeEdgeIndicators(size: geometry.size, mouseLocation: mouseLocation)
                }
            }
            .allowsHitTesting(false)
        )
        .frame(minWidth: baseSize.width * 0.6, minHeight: baseSize.height * 0.6)
        .ignoresSafeArea()
        .opacity((isHovering && !isCommandKeyPressed && purchaseManager.isPremium && disappearOnHover) ? 0 : clockOpacity)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isCommandKeyPressed)
        .animation(.easeInOut(duration: 0.2), value: clockOpacity)
        .onReceive(worldClockManager.$savedLocations) { locations in
            if let updated = locations.first(where: { $0.id == location.id }) {
                liveLocation = updated
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
        }
    }

    @ViewBuilder
    private func fontColorButton(title: String, colorName: String) -> some View {
        Button {
            var updatedSettings = currentLocation.settings
            updatedSettings.fontColorName = colorName
            WorldClockManager.shared.updateClockSettings(for: location.id, settings: updatedSettings)
            cacheUpdatedSettings(updatedSettings)
        } label: {
            if fontColorName == colorName {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    @ViewBuilder
    private func fontStyleButton(title: String, fontName: String) -> some View {
        Button {
            var updatedSettings = currentLocation.settings
            updatedSettings.fontDesign = fontName
            WorldClockManager.shared.updateClockSettings(for: location.id, settings: updatedSettings)
            cacheUpdatedSettings(updatedSettings)
        } label: {
            if fontDesign == fontName {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    // Helper to create a binding for settings properties
    private func settingsBinding(_ keyPath: WritableKeyPath<ClockSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { currentLocation.settings[keyPath: keyPath] },
            set: { newValue in
                var updatedSettings = currentLocation.settings
                updatedSettings[keyPath: keyPath] = newValue
                WorldClockManager.shared.updateClockSettings(for: location.id, settings: updatedSettings)
                cacheUpdatedSettings(updatedSettings)
            }
        )
    }

    private func cacheUpdatedSettings(_ newSettings: ClockSettings) {
        var updated = currentLocation
        updated.settings = newSettings
        liveLocation = updated
    }

}

private struct DockDragModifier: ViewModifier {
    let isEnabled: Bool
    let provider: () -> NSItemProvider

    // Only enable the SwiftUI drag session when explicitly requested (Cmd-drag)
    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.onDrag(provider) {
                Color.clear.frame(width: 1, height: 1)
            }
        } else {
            content
        }
    }
}

// MARK: - Preview

struct WorldClockView_Previews: PreviewProvider {
    static var previews: some View {
        WorldClockView(
            location: WorldClockLocation(displayName: "Tokyo, Japan", timeZoneIdentifier: "Asia/Tokyo"),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!
        )
        .frame(width: 320, height: 160)
        .padding()
        .background(
            LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
        )
    }
}
#endif
