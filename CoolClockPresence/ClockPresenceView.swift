// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  ClockPresenceView.swift
//
//  Crafted for a floating, glassy clock on macOS.
//
//

#if os(macOS)
import SwiftUI
import AppKit
import Combine
import IOKit.ps

/// A compact glass-inspired clock that can float above other windows.
struct ClockPresenceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var settingsManager = ClockSettingsManager.shared
    @StateObject private var worldClockManager = WorldClockManager.shared
    @AppStorage("windowPositionPreset") private var windowPositionPreset: String = ClockWindowPosition.topCenter.rawValue

    @State private var isHovering: Bool = false
    @State private var isCommandKeyPressed: Bool = false
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var photoManager = PhotoWindowManager.shared
    @State private var showingPurchaseSheet = false
    @State private var mouseLocation: CGPoint = .zero
    @State private var showResizeHints: Bool = false
    @State private var timelineRefresh: UUID = UUID()

    // Convenience accessors for settings
    private var fontColorName: String { settingsManager.mainClockSettings.fontColorName }
    private var showBattery: Bool { settingsManager.mainClockSettings.showBattery }
    private var showSeconds: Bool { settingsManager.mainClockSettings.showSeconds }
    private var isAlwaysOnTop: Bool { settingsManager.mainClockSettings.alwaysOnTop }
    private var disappearOnHover: Bool { settingsManager.mainClockSettings.disappearOnHover }
    private var clockOpacity: Double { settingsManager.mainClockSettings.clockOpacity }
    private var use24HourFormat: Bool { settingsManager.mainClockSettings.use24HourFormat }
    private var glassStyle: String { settingsManager.mainClockSettings.glassStyle }
    private var adjustableBlackOpacity: Double { settingsManager.mainClockSettings.adjustableBlackOpacity }
    private var fontDesign: String { settingsManager.mainClockSettings.fontDesign }

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
        case "cyan": return Color(red: 0.00, green: 0.78, blue: 1.00)   // vivid cyan
        case "mint": return Color(red: 0.16, green: 0.90, blue: 0.64)   // bright mint
        case "teal": return Color(red: 0.00, green: 0.64, blue: 0.68)   // deeper teal
        case "indigo": return .indigo
        case "primary": return .primary
        default: return .green
        }
    }

    private let baseSize = CGSize(width: 240, height: 80)
    private static let menuCheckmarkImage: NSImage = {
        NSImage(named: NSImage.menuOnStateTemplateName) ?? NSImage(size: NSSize(width: 12, height: 12))
    }()
    private static let menuEmptyCheckmarkImage: NSImage = {
        let image = NSImage(size: menuCheckmarkImage.size)
        image.lockFocus()
        NSColor.clear.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: menuCheckmarkImage.size)).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
    private var checkmarkTemplate: NSImage { Self.menuCheckmarkImage }
    private var emptyCheckmarkTemplate: NSImage { Self.menuEmptyCheckmarkImage }
    private var checkmarkIconWidth: CGFloat { checkmarkTemplate.size.width }

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
            // Back to the Future time-circuit LED look using DSEG7 Classic
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

    private func batteryFont(for scale: CGFloat) -> Font {
        let fontSize = 19 * scale

        switch fontDesign {
        case "rounded":
            return .system(size: fontSize, weight: .medium, design: .rounded)
        case "monospaced":
            return .system(size: fontSize, weight: .medium, design: .monospaced)
        case "serif":
            return .system(size: fontSize, weight: .medium, design: .serif)
        case "led":
            // Back to the Future time-circuit LED look using DSEG7 Classic
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
            return .system(size: fontSize, weight: .medium, design: .rounded)
        }
    }

    private func formattedTime(from date: Date, colonVisible: Bool = true) -> String {
        if use24HourFormat {
            let calendar = Calendar.autoupdatingCurrent
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0

            if showSeconds && purchaseManager.isPremium {
                let second = components.second ?? 0
                return String(format: "%02d:%02d:%02d", hour, minute, second)
            }

            let separator = colonVisible ? ":" : " "
            return String(format: "%02d%@%02d", hour, separator, minute)
        }

        var formatStyle = Date.FormatStyle()
            .hour(.defaultDigits(amPM: .abbreviated))
            .minute()

        if showSeconds && purchaseManager.isPremium {
            formatStyle = formatStyle.second()
        }

        let timeString = date.formatted(formatStyle)

        // Replace colon with space when not visible (only if seconds not shown)
        if !colonVisible && !(showSeconds && purchaseManager.isPremium) {
            return timeString.replacingOccurrences(of: ":", with: " ")
        }

        return timeString
    }

    private func timeComponents(from date: Date) -> (hours: String, separator: String, minutes: String, seconds: String?, ampm: String?) {
        if use24HourFormat {
            let calendar = Calendar.autoupdatingCurrent
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0

            if showSeconds && purchaseManager.isPremium {
                let second = components.second ?? 0
                return (String(format: "%02d", hour), ":", String(format: "%02d", minute), String(format: "%02d", second), nil)
            }

            return (String(format: "%02d", hour), ":", String(format: "%02d", minute), nil, nil)
        }

        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
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

    var body: some View {
        GeometryReader { geometry in
            let currentScale = scale(for: geometry.size)
            let strokeColor = outlineColorForBackground()
            ZStack(alignment: .center) {
                // Background photo layer (behind glass)
                if let photoID = settingsManager.mainClockSettings.backgroundPhotoID {
                    BackgroundPhotoView(
                        photoID: photoID,
                        opacity: settingsManager.mainClockSettings.backgroundPhotoOpacity,
                        aspectMode: settingsManager.mainClockSettings.backgroundPhotoAspectMode
                    )
                }

                GlassBackdrop(style: glassStyle, adjustableOpacity: adjustableBlackOpacity)

                VStack(spacing: 2 * currentScale) {
                    // Battery optimization: Only update every second if seconds are shown, otherwise update every minute
                    let updateInterval: TimeInterval = (showSeconds && purchaseManager.isPremium) ? 1.0 : 60.0
                    TimelineView(.periodic(from: Date(), by: updateInterval)) { context in
                        // Calculate if colon should be visible (blink when seconds disabled)
                        let shouldShowSeconds = showSeconds && purchaseManager.isPremium

                        if fontColorName == "black" {
                            HStack(spacing: 0) {
                                OutlinedText(
                                    text: timeComponents(from: context.date).hours,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor.opacity(0.92),
                                    strokeColor: strokeColor,
                                    lineWidth: max(0.5, 1.1 * currentScale)
                                )
                                BlinkingColon(
                                    text: timeComponents(from: context.date).separator,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor,
                                    strokeColor: strokeColor,
                                    lineWidth: max(0.5, 1.1 * currentScale),
                                    shouldBlink: !shouldShowSeconds,
                                    isOutlined: true
                                )
                                OutlinedText(
                                    text: timeComponents(from: context.date).minutes,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor.opacity(0.92),
                                    strokeColor: strokeColor,
                                    lineWidth: max(0.5, 1.1 * currentScale)
                                )
                                if let secondsPart = timeComponents(from: context.date).seconds {
                                    OutlinedText(
                                        text: ":",
                                        font: clockFont(for: currentScale),
                                        fillColor: fontColor.opacity(0.92),
                                        strokeColor: strokeColor,
                                        lineWidth: max(0.5, 1.1 * currentScale)
                                    )
                                    OutlinedText(
                                        text: secondsPart,
                                        font: clockFont(for: currentScale),
                                        fillColor: fontColor.opacity(0.92),
                                        strokeColor: strokeColor,
                                        lineWidth: max(0.5, 1.1 * currentScale)
                                    )
                                }
                                if let ampm = timeComponents(from: context.date).ampm {
                                    OutlinedText(
                                        text: ampm,
                                        font: .system(size: 20 * currentScale, weight: .medium, design: .rounded),
                                        fillColor: fontColor.opacity(0.92),
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
                                    .foregroundStyle(fontColor.opacity(0.92))
                                BlinkingColon(
                                    text: timeComponents(from: context.date).separator,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor,
                                    strokeColor: .clear,
                                    lineWidth: 0,
                                    shouldBlink: !shouldShowSeconds,
                                    isOutlined: false
                                )
                                Text(timeComponents(from: context.date).minutes)
                                    .font(clockFont(for: currentScale))
                                    .monospacedDigit()
                                    .foregroundStyle(fontColor.opacity(0.92))
                                if let secondsPart = timeComponents(from: context.date).seconds {
                                    Text(":")
                                        .font(clockFont(for: currentScale))
                                        .monospacedDigit()
                                        .foregroundStyle(fontColor.opacity(0.92))
                                    Text(secondsPart)
                                        .font(clockFont(for: currentScale))
                                        .monospacedDigit()
                                        .foregroundStyle(fontColor.opacity(0.92))
                                }
                                if let ampm = timeComponents(from: context.date).ampm {
                                    Text(ampm)
                                        .font(.system(size: 20 * currentScale, weight: .medium, design: .rounded))
                                        .foregroundStyle(fontColor.opacity(0.92))
                                        .padding(.leading, 2 * currentScale)
                                }
                            }
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        }
                    }
                    .id(timelineRefresh)

                    // Battery Status (Premium Only)
                    if showBattery && purchaseManager.isPremium {
                        HStack(spacing: 6 * currentScale) {
                            BatteryIndicatorView(
                                level: batteryMonitor.batteryLevel,
                                isCharging: batteryMonitor.isCharging,
                                scale: currentScale
                            )

                            // Battery optimization: Only update frequently when battery is low and needs to flash
                            let shouldFlash = batteryMonitor.batteryLevel <= 25 && !batteryMonitor.isPluggedIn
                            let batteryUpdateInterval: TimeInterval = shouldFlash ? 1.0 : 60.0
                            TimelineView(.periodic(from: Date(), by: batteryUpdateInterval)) { context in
                                let isVisible = shouldFlash ? (Int(context.date.timeIntervalSince1970) % 2 == 0) : true

                                Text("\(batteryMonitor.batteryLevel)%")
                                    .font(batteryFont(for: currentScale))
                                    .foregroundStyle(batteryMonitor.batteryPercentageColor.opacity(0.92))
                                .opacity(isVisible ? 1 : 0)
                            }
                        }
                        .padding(.top, 4 * currentScale)
                    }

                    // Docked World Clocks
                    if !worldClockManager.dockedClocks.isEmpty {
                        Divider()
                            .frame(height: 1)
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 6 * currentScale)

                        ForEach(worldClockManager.dockedClocks) { location in
                            DockedWorldClockView(location: location, scale: currentScale)
                                .padding(.bottom, 4 * currentScale)
                        }
                    }
                }
                .padding(.vertical, 6 * currentScale)
                .padding(.horizontal, 10 * currentScale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .contentShape(Rectangle())
            .onDrop(of: ["com.coolclock.worldclock"], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            .contextMenu {
                Button {
                    performMenuAction(#selector(AppDelegate.toggleClockWindow))
                } label: {
                    let hasMainClock = settingsManager.isMainClockVisible
                    let hasWorldClocks = worldClockManager.hasVisibleWindows
                    let hasPhotos = photoManager.hasVisiblePhotos
                    let isVisible = hasMainClock || hasWorldClocks || hasPhotos
                    Text(isVisible ? "Hide Clock Window" : "Show Clock Window")
                }

                Button {
                    performMenuAction(#selector(AppDelegate.toggleClocksOnly))
                } label: {
                    let hasMainClock = settingsManager.isMainClockVisible
                    let hasWorldClocks = worldClockManager.hasVisibleWindows
                    let isVisible = hasMainClock || hasWorldClocks
                    Text(isVisible ? "Hide Clocks Only" : "Show Clocks Only")
                }

                Button {
                    performMenuAction(#selector(AppDelegate.togglePhotosOnly))
                } label: {
                    let isVisible = photoManager.hasVisiblePhotos
                    Text(isVisible ? "Hide Photos Only" : "Show Photos Only")
                }

                Divider()

                Menu("Font Color") {
                    // Free colors
                    fontColorButton(title: "White", colorName: "white")
                    fontColorButton(title: "Green", colorName: "green")

                    // Premium colors
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

                Menu("Background Photo") {
                    Button("None") {
                        settingsManager.updateMainClockProperty(\.backgroundPhotoID, value: nil as UUID?)
                    }

                    if !photoManager.savedPhotos.isEmpty {
                        Divider()

                        ForEach(photoManager.savedPhotos, id: \.id) { photo in
                            Button {
                                settingsManager.updateMainClockProperty(\.backgroundPhotoID, value: photo.id)
                            } label: {
                                if settingsManager.mainClockSettings.backgroundPhotoID == photo.id {
                    Label(photo.displayName, systemImage: "checkmark")
                                } else {
                                    Text(photo.displayName)
                                }
                            }
                        }

                        Divider()

                        Menu("Opacity") {
                            ForEach([1.0, 0.8, 0.6, 0.4, 0.2], id: \.self) { opacity in
                                Button {
                                    settingsManager.updateMainClockProperty(\.backgroundPhotoOpacity, value: opacity)
                                } label: {
                                    let currentOpacity = settingsManager.mainClockSettings.backgroundPhotoOpacity
                                    if abs(currentOpacity - opacity) < 0.001 {
                                        Label("\(Int(opacity * 100))%", systemImage: "checkmark")
                                    } else {
                                        Text("\(Int(opacity * 100))%")
                                    }
                                }
                            }
                        }

                        Menu("Display Mode") {
                            Button {
                                settingsManager.updateMainClockProperty(\.backgroundPhotoAspectMode, value: "fill")
                            } label: {
                                if settingsManager.mainClockSettings.backgroundPhotoAspectMode == "fill" {
                                    Label("Aspect Fill", systemImage: "checkmark")
                                } else {
                                    Text("Aspect Fill")
                                }
                            }
                            Button {
                                settingsManager.updateMainClockProperty(\.backgroundPhotoAspectMode, value: "fit")
                            } label: {
                                if settingsManager.mainClockSettings.backgroundPhotoAspectMode == "fit" {
                                    Label("Aspect Fit", systemImage: "checkmark")
                                } else {
                                    Text("Aspect Fit")
                                }
                            }
                        }
                    } else {
                        Text("No photos available")
                        Button("Add Photo...") {
                            performMenuAction(#selector(AppDelegate.showPhotoPicker))
                        }
                    }
                }
                Divider()

                Menu("Clock Position") {
                    ForEach(ClockWindowPosition.allCases) { position in
                        positionButton(for: position)
                    }
                }
                Divider()

                // World Clocks submenu
                Menu("World Clocks") {
                    Button("Add World Clock...") {
                        performMenuAction(#selector(AppDelegate.showWorldClockPicker))
                    }

                    if !worldClockManager.savedLocations.isEmpty {
                        Divider()

                        // Floating clocks
                        let floatingClocks = worldClockManager.savedLocations.filter { !$0.isDocked }
                        if !floatingClocks.isEmpty {
                            ForEach(floatingClocks) { location in
                                Menu(location.displayName) {
                                    if worldClockManager.isLocationOpen(id: location.id) {
                                        Button("Close Window") {
                                            worldClockManager.closeWorldClock(for: location.id)
                                        }
                                    } else {
                                        Button("Open Window") {
                                            worldClockManager.openWorldClock(for: location)
                                        }
                                    }
                                    Button("Dock to Main Clock") {
                                        worldClockManager.dockClock(for: location.id)
                                    }
                                }
                            }
                        }

                        // Docked clocks
                        if !worldClockManager.dockedClocks.isEmpty {
                            Divider()
                            ForEach(worldClockManager.dockedClocks) { location in
                                Button("📌 \(location.displayName)") {
                                    worldClockManager.undockClock(for: location.id)
                                }
                            }
                        }

                        Divider()

                        Button("Manage World Clocks...") {
                            performMenuAction(#selector(AppDelegate.showManageWorldClocks))
                        }
                    }
                }
                Divider()

                Menu("Photos") {
                    Button("Add Photo...") {
                        performMenuAction(#selector(AppDelegate.showPhotoPicker))
                    }

                    if !photoManager.savedPhotos.isEmpty {
                        Divider()

                        ForEach(photoManager.savedPhotos, id: \.id) { photo in
                            Button {
                                photoManager.togglePhotoWindow(for: photo)
                            } label: {
                                if photoManager.isPhotoOpen(id: photo.id) {
                                    Label(photo.displayName, systemImage: "checkmark")
                                } else {
                                    Text(photo.displayName)
                                }
                            }
                        }

                        Divider()
                    }

                    Button("Manage Photos...") {
                        performMenuAction(#selector(AppDelegate.showManagePhotos))
                    }
                }
                Divider()

                // Premium features
                if purchaseManager.isPremium {
                    Toggle("Show Seconds", isOn: settingsBinding(\.showSeconds))
                    Toggle("Use 24-Hour Format", isOn: settingsBinding(\.use24HourFormat))
                    Toggle("Show Battery", isOn: settingsBinding(\.showBattery))
                    Toggle("Always on Top", isOn: settingsBinding(\.alwaysOnTop))
                    Toggle("Disappear on Hover", isOn: settingsBinding(\.disappearOnHover))
                } else {
                    Button("Show Seconds 🔒 Premium") {
                        showingPurchaseSheet = true
                    }
                    Button("Use 24-Hour Format 🔒 Premium") {
                        showingPurchaseSheet = true
                    }
                    Button("Show Battery 🔒 Premium") {
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

                // Upgrade option
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

                Divider()

                Button("Show Onboarding Again") {
                    performMenuAction(#selector(AppDelegate.showOnboardingAgain))
                }
                Divider()

                Button("Quit CoolClockPresence") {
                    performMenuAction(#selector(AppDelegate.quitApp))
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .sheet(isPresented: $showingPurchaseSheet) {
                PurchaseView()
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
            // Resize hint indicators
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
        .onAppear {
            // Observe system clock changes to keep the clock synced
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSSystemClockDidChange,
                object: nil,
                queue: .main
            ) { _ in
                // Force TimelineView to recreate with updated system time
                timelineRefresh = UUID()
            }

            // Observe world clock docking changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WorldClockDockingChanged"),
                object: nil,
                queue: .main
            ) { _ in
                // Refresh view when docking state changes
                timelineRefresh = UUID()
            }
        }
    }

    @ViewBuilder
    private func fontColorButton(title: String, colorName: String) -> some View {
        Button {
            settingsManager.updateMainClockProperty(\.fontColorName, value: colorName)
        } label: {
            let isSelected = fontColorName == colorName
            HStack(spacing: 8) {
                Image(nsImage: isSelected ? checkmarkTemplate : emptyCheckmarkTemplate)
                    .frame(width: checkmarkIconWidth, alignment: .leading)
                Text(title)
            }
        }
    }

    @ViewBuilder
    private func fontStyleButton(title: String, fontName: String) -> some View {
        Button {
            settingsManager.updateMainClockProperty(\.fontDesign, value: fontName)
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
            get: { settingsManager.mainClockSettings[keyPath: keyPath] },
            set: { newValue in
                settingsManager.updateMainClockProperty(keyPath, value: newValue)
            }
        )
    }

    // Handle drop for drag-and-drop docking
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadDataRepresentation(forTypeIdentifier: "com.coolclock.worldclock") { data, error in
            guard let data = data,
                  let idString = String(data: data, encoding: .utf8),
                  let locationID = UUID(uuidString: idString) else { return }

            DispatchQueue.main.async {
                worldClockManager.dockClock(for: locationID)
            }
        }
        return true
    }

    @ViewBuilder
    private func positionButton(for position: ClockWindowPosition) -> some View {
        Button {
            windowPositionPreset = position.rawValue
            (NSApplication.shared.delegate as? AppDelegate)?.applyWindowPosition(position)
        } label: {
            if windowPositionPreset == position.rawValue {
                Label(position.displayName, systemImage: "checkmark")
            } else {
                Text(position.displayName)
            }
        }
    }
}

// MARK: - Hover And Window Controller

struct HoverAndWindowController: NSViewRepresentable {
    @Binding var isHovering: Bool
    @Binding var isCommandKeyPressed: Bool
    let isPremium: Bool
    let disappearOnHover: Bool
    @Binding var mouseLocation: CGPoint
    @Binding var showResizeHints: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isHovering: $isHovering,
            isCommandKeyPressed: $isCommandKeyPressed,
            mouseLocation: $mouseLocation,
            showResizeHints: $showResizeHints
        )
    }

    func makeNSView(context: Context) -> HoverControlView {
        let view = HoverControlView()
        view.coordinator = context.coordinator
        context.coordinator.isPremium = isPremium
        context.coordinator.disappearOnHover = disappearOnHover
        return view
    }

    func updateNSView(_ nsView: HoverControlView, context: Context) {
        // Only update coordinator properties - DON'T trigger window updates here
        context.coordinator.isPremium = isPremium
        context.coordinator.disappearOnHover = disappearOnHover
    }

    class Coordinator {
        @Binding var isHovering: Bool
        @Binding var isCommandKeyPressed: Bool
        @Binding var mouseLocation: CGPoint
        @Binding var showResizeHints: Bool
        var isPremium: Bool = false
        var disappearOnHover: Bool = true

        private var updateWorkItem: DispatchWorkItem?

        init(isHovering: Binding<Bool>, isCommandKeyPressed: Binding<Bool>, mouseLocation: Binding<CGPoint>, showResizeHints: Binding<Bool>) {
            _isHovering = isHovering
            _isCommandKeyPressed = isCommandKeyPressed
            _mouseLocation = mouseLocation
            _showResizeHints = showResizeHints
        }

        func updateWindow(_ window: NSWindow?, hovering: Bool, commandPressed: Bool) {
            // Cancel any pending updates
            updateWorkItem?.cancel()

            // Calculate the desired state
            let shouldIgnore = hovering && !commandPressed && isPremium && disappearOnHover

            // Create a new work item
            let workItem = DispatchWorkItem { [weak window] in
                guard let window = window else { return }
                // Only update if actually different
                if window.ignoresMouseEvents != shouldIgnore {
                    window.ignoresMouseEvents = shouldIgnore
                }
            }

            updateWorkItem = workItem

            // Schedule it to run AFTER the current layout pass
            DispatchQueue.main.async(execute: workItem)
        }
    }
}

class HoverControlView: NSView {
    weak var coordinator: HoverAndWindowController.Coordinator?
    private var trackingArea: NSTrackingArea?
    private var eventMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCommandKeyMonitor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCommandKeyMonitor()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // Return zero intrinsic content size to not influence layout
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    // Override layout - call super.layout() as recommended by Apple
    override func layout() {
        super.layout()
        // Tracking areas are updated via updateTrackingAreas callback
    }

    private func setupCommandKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let isPressed = event.modifierFlags.contains(.command)
            self?.coordinator?.isCommandKeyPressed = isPressed
            self?.updateWindowState()
            return event
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Defer tracking area setup to avoid triggering during layout
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let existingTrackingArea = self.trackingArea {
                self.removeTrackingArea(existingTrackingArea)
            }

            self.trackingArea = NSTrackingArea(
                rect: self.bounds,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )

            if let trackingArea = self.trackingArea {
                self.addTrackingArea(trackingArea)
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        coordinator?.isHovering = true
        coordinator?.showResizeHints = true
        coordinator?.isCommandKeyPressed = event.modifierFlags.contains(.command)
        updateMouseLocation(event)
        updateWindowState()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateMouseLocation(event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        coordinator?.isHovering = false
        coordinator?.showResizeHints = false
        coordinator?.isCommandKeyPressed = event.modifierFlags.contains(.command)
        updateWindowState()
    }

    private func updateMouseLocation(_ event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        coordinator?.mouseLocation = location
    }

    private func updateWindowState() {
        guard let coordinator = coordinator else { return }
        coordinator.updateWindow(window, hovering: coordinator.isHovering, commandPressed: coordinator.isCommandKeyPressed)
    }
}

// MARK: - Battery Indicator View

struct BatteryIndicatorView: View {
    let level: Int
    let isCharging: Bool
    let scale: CGFloat

    private var batteryColor: Color {
        if isCharging {
            return Color(white: 0.7)
        }

        if level <= 25 {
            return .orange
        } else if level <= 50 {
            return Color(white: 0.7)
        } else {
            return Color(white: 0.7)
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Battery body outline
            RoundedRectangle(cornerRadius: 2 * scale)
                .strokeBorder(batteryColor.opacity(0.92), lineWidth: 1.5 * scale)
                .frame(width: 22 * scale, height: 11 * scale)

            // Battery fill
            RoundedRectangle(cornerRadius: 1.5 * scale)
                .fill(batteryColor.opacity(0.92))
                .frame(width: max(0, (20 * scale) * CGFloat(level) / 100), height: 9 * scale)
                .padding(.leading, 1 * scale)

            // Battery terminal (nub on right side)
            RoundedRectangle(cornerRadius: 1 * scale)
                .fill(batteryColor.opacity(0.92))
                .frame(width: 1.5 * scale, height: 6 * scale)
                .offset(x: 22.5 * scale)

            // Charging bolt icon overlay
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 7 * scale, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .offset(x: 7.5 * scale)
            }
        }
        .frame(width: 24 * scale, height: 11 * scale)
    }
}

// MARK: - Battery Monitor

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false

    private var runLoopSource: CFRunLoopSource?

    init() {
        updateBatteryInfo()
        startMonitoring()
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    private func startMonitoring() {
        // Battery optimization: Use event-based notifications instead of polling
        // This way we only update when battery state actually changes, not every 30 seconds
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.updateBatteryInfo()
        }

        runLoopSource = IOPSNotificationCreateRunLoopSource(callback, context).takeRetainedValue()
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    private func updateBatteryInfo() {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            // Get battery level
            if let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                DispatchQueue.main.async {
                    self.batteryLevel = (currentCapacity * 100) / maxCapacity
                }
            }

            // Get charging status
            if let isCharging = info[kIOPSIsChargingKey] as? Bool {
                DispatchQueue.main.async {
                    self.isCharging = isCharging
                }
            }

            // Get power source (AC or battery)
            if let powerSource = info[kIOPSPowerSourceStateKey] as? String {
                DispatchQueue.main.async {
                    self.isPluggedIn = (powerSource == kIOPSACPowerValue)
                }
            }
        }
    }

    var batteryPercentageColor: Color {
        if batteryLevel <= 20 {
            return .red
        } else if batteryLevel <= 50 {
            return .orange
        } else if batteryLevel <= 70 {
            return Color(red: 0.996, green: 0.784, blue: 0.294)
        } else {
            return .green
        }
    }
}

// MARK: - Menu Slider Control (AppKit-backed)

/// AppKit slider for use inside context menus so dragging does not trigger the stepper overlay.
private struct MenuSliderControl: NSViewRepresentable {
    @Binding var value: Double
    let minValue: Double
    let maxValue: Double

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: minValue, maxValue: maxValue, target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        slider.isContinuous = true
        slider.numberOfTickMarks = 0
        slider.controlSize = .small
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        let clamped = min(max(value, minValue), maxValue)
        if nsView.doubleValue != clamped {
            nsView.doubleValue = clamped
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, minValue: minValue, maxValue: maxValue)
    }

    final class Coordinator: NSObject {
        @Binding var value: Double
        let minValue: Double
        let maxValue: Double

        init(value: Binding<Double>, minValue: Double, maxValue: Double) {
            self._value = value
            self.minValue = minValue
            self.maxValue = maxValue
        }

        @objc func changed(_ sender: NSSlider) {
            let clamped = min(max(sender.doubleValue, minValue), maxValue)
            if clamped != sender.doubleValue {
                sender.doubleValue = clamped
            }
            value = clamped
        }
    }
}

// MARK: - Preview

struct ClockPresenceView_Previews: PreviewProvider {
    static var previews: some View {
        ClockPresenceView()
            .frame(width: 320, height: 180)
            .padding()
            .background(
                LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
            )
    }
}
#endif
