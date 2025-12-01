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
    @AppStorage("fontColorName") private var fontColorName: String = "blue"
    @AppStorage("showBattery") private var showBattery: Bool = true
    @AppStorage("showSeconds") private var showSeconds: Bool = true
    @AppStorage("clockPresence.alwaysOnTop") private var isAlwaysOnTop: Bool = true
    @AppStorage("disappearOnHover") private var disappearOnHover: Bool = true
    @AppStorage("clockOpacity") private var clockOpacity: Double = 1.0
    @AppStorage("use24HourFormat") private var use24HourFormat: Bool = false
    @AppStorage("glassStyle") private var glassStyle: String = "liquid"
    @AppStorage("adjustableBlackOpacity") private var adjustableBlackOpacity: Double = 0.82
    @AppStorage("windowPositionPreset") private var windowPositionPreset: String = ClockWindowPosition.topCenter.rawValue
    @AppStorage("fontDesign") private var fontDesign: String = "rounded"

    @State private var isHovering: Bool = false
    @State private var isCommandKeyPressed: Bool = false
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingPurchaseSheet = false
    @State private var mouseLocation: CGPoint = .zero
    @State private var showResizeHints: Bool = false
    @State private var timelineRefresh: UUID = UUID()

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
            ZStack {
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
                    }
                }
                .padding(.vertical, 6 * currentScale)
                .padding(.horizontal, 10 * currentScale)
            }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            performMenuAction(#selector(AppDelegate.toggleClockWindow))
                        } label: {
                            let isVisible = appDelegate?.window?.isVisible ?? false
                            if isVisible {
                                Label("Show Clock Window", systemImage: "checkmark")
                            } else {
                        Text("Show Clock Window")
                    }
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
                Divider()

                Menu("Clock Position") {
                    ForEach(ClockWindowPosition.allCases) { position in
                        positionButton(for: position)
                    }
                }
                Divider()

                // Premium features
                if purchaseManager.isPremium {
                    Toggle("Show Seconds", isOn: $showSeconds)
                    Toggle("Use 24-Hour Format", isOn: $use24HourFormat)
                    Toggle("Show Battery", isOn: $showBattery)
                    Toggle("Always on Top", isOn: $isAlwaysOnTop)
                    Toggle("Disappear on Hover", isOn: $disappearOnHover)
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
        }
    }

    @ViewBuilder
    private func fontColorButton(title: String, colorName: String) -> some View {
        Button {
            fontColorName = colorName
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
            fontDesign = fontName
        } label: {
            if fontDesign == fontName {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
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

// MARK: - Blinking Colon Helper

/// Battery-efficient blinking colon that uses GPU animation instead of timeline updates
private struct BlinkingColon: View {
    let text: String
    let font: Font
    let fillColor: Color
    let strokeColor: Color
    let lineWidth: CGFloat
    let shouldBlink: Bool
    let isOutlined: Bool

    @State private var isVisible: Bool = true

    var body: some View {
        // Render the text with constant colors to prevent position shifts
        // Apply opacity to the entire view instead of to individual color components
        Group {
            if isOutlined {
                OutlinedText(
                    text: text,
                    font: font,
                    fillColor: fillColor.opacity(0.92),
                    strokeColor: strokeColor,
                    lineWidth: lineWidth
                )
            } else {
                Text(text)
                    .font(font)
                    .monospacedDigit()
                    .foregroundStyle(fillColor.opacity(0.92))
            }
        }
        // Apply opacity animation to the entire rendered view
        // This keeps the text rendering identical, preventing alignment shifts
        .opacity(shouldBlink ? (isVisible ? 1.0 : 0.27) : 1.0)
        .onAppear {
            if shouldBlink {
                // GPU-based animation that repeats without requiring view updates
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
        }
        .onChange(of: shouldBlink) { _, newValue in
            // Reset to visible when seconds are shown (shouldBlink becomes false)
            if !newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = true
                }
            } else {
                // Start blinking animation when seconds are hidden
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - Outlined Text Helper

private struct OutlinedText: View {
    let text: String
    let font: Font
    let fillColor: Color
    let strokeColor: Color
    let lineWidth: CGFloat

    var body: some View {
        // Battery optimization: Use shadows instead of 9 text copies for much better performance
        // This reduces GPU/CPU load significantly while maintaining visual quality
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(fillColor)
            .shadow(color: strokeColor, radius: lineWidth * 0.4, x: 0, y: 0)
            .shadow(color: strokeColor, radius: lineWidth * 0.4, x: 0, y: 0)
            .shadow(color: strokeColor, radius: lineWidth * 0.3, x: lineWidth * 0.3, y: lineWidth * 0.3)
            .shadow(color: strokeColor, radius: lineWidth * 0.3, x: -lineWidth * 0.3, y: -lineWidth * 0.3)
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

// MARK: - Glass Backdrop

private struct GlassBackdrop: View {
    let style: String
    let adjustableOpacity: Double

    private var clampedAdjustableOpacity: Double {
        min(max(adjustableOpacity, 0.4), 1.0)
    }

    var body: some View {
        if style == "liquid" {
            liquidGlassStyle
        } else if style == "adjustableBlack" {
            adjustableBlackGlassStyle
        } else if style == "black" {
            blackGlassStyle
        } else {
            clearGlassStyle
        }
    }

    // New Liquid Glass effect - more vibrant and visible with blur transparency
    private var liquidGlassStyle: some View {
        ZStack {
            // Base material layer with blur and transparency
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.5)

            // Vibrant gradient overlay - slightly more opaque for visibility
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.cyan.opacity(0.12),
                        Color.purple.opacity(0.10),
                        Color.blue.opacity(0.12),
                        Color.pink.opacity(0.08)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .blur(radius: 12)  // Battery optimization: Reduced from 20 to 12 for better performance

            // Shimmer highlight layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.15),
                        Color.clear
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )

            // Inner glow for depth
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(colors: [
                        Color.white.opacity(0.1),
                        Color.clear
                    ], center: .topLeading, startRadius: 0, endRadius: 300)
                )
                .padding(2)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 25, x: 0, y: 12)
        .shadow(color: Color.cyan.opacity(0.08), radius: 15, x: 0, y: 5)
    }

    // Original Clear Glass style
    private var clearGlassStyle: some View {
        ZStack {
            // Outer border layer for smooth edge - made nearly transparent
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(0.02),
                        Color.white.opacity(0.01)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(0.5)

            // Inner glass layer - made very transparent
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.05))
                .padding(1.5)

            // Background gradient layer - made very subtle
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.cyan.opacity(0.02),
                        Color.purple.opacity(0.03),
                        Color.blue.opacity(0.02)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .blur(radius: 15)  // Battery optimization: Reduced from 30 to 15 for better performance
                .opacity(0.1)
                .padding(1.5)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
    }

    // Black Glass style - all black background
    private var blackGlassStyle: some View {
        ZStack {
            // Solid black base layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.95))

            // Subtle edge highlight for definition
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05),
                        Color.clear
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )

            // Very subtle inner glow for depth
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(colors: [
                        Color.white.opacity(0.03),
                        Color.clear
                    ], center: .topLeading, startRadius: 0, endRadius: 300)
                )
                .padding(2)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
    }

    // Adjustable Black Glass - user controlled transparency to tune visibility
    private var adjustableBlackGlassStyle: some View {
        let baseOpacity = clampedAdjustableOpacity
        let edgeHighlight = 0.12 + (1.0 - baseOpacity) * 0.2
        let overlayOpacity = 0.14 + (1.0 - baseOpacity) * 0.2
        let innerGlowOpacity = 0.03 + (1.0 - baseOpacity) * 0.07

        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.black.opacity(baseOpacity),
                        Color.black.opacity(max(0.35, baseOpacity * 0.8))
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            // Edge highlight adapts with opacity so definition remains clear
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [
                        Color.white.opacity(edgeHighlight),
                        Color.white.opacity(edgeHighlight * 0.5),
                        Color.clear
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.25
                )

            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(overlayOpacity),
                        Color.white.opacity(overlayOpacity * 0.25)
                    ], startPoint: .top, endPoint: .bottom)
                )
                .opacity(0.2)
                .blur(radius: 12)
                .padding(1)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(colors: [
                        Color.white.opacity(innerGlowOpacity),
                        Color.clear
                    ], center: .topLeading, startRadius: 0, endRadius: 280)
                )
                .padding(2)
        }
        .shadow(color: Color.black.opacity(0.3 + baseOpacity * 0.15), radius: 24, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.18 + baseOpacity * 0.08), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Resize Edge Indicators

/// Visual indicators that appear near window edges to show where you can resize
private struct ResizeEdgeIndicators: View {
    let size: CGSize
    let mouseLocation: CGPoint
    
    // Increased from 8 to 20 to match the window's edge detection
    private let edgeThickness: CGFloat = 20.0
    
    private var isNearTop: Bool {
        mouseLocation.y >= size.height - edgeThickness
    }
    
    private var isNearBottom: Bool {
        mouseLocation.y <= edgeThickness
    }
    
    private var isNearLeft: Bool {
        mouseLocation.x <= edgeThickness
    }
    
    private var isNearRight: Bool {
        mouseLocation.x >= size.width - edgeThickness
    }
    
    var body: some View {
        ZStack {
            // Top edge indicator
            if isNearTop {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: edgeThickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            
            // Bottom edge indicator
            if isNearBottom {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: edgeThickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            
            // Left edge indicator
            if isNearLeft {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: edgeThickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            
            // Right edge indicator
            if isNearRight {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: edgeThickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            
            // Corner indicators (only show when near corners)
            if isNearTop && isNearLeft {
                cornerIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            
            if isNearTop && isNearRight {
                cornerIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            
            if isNearBottom && isNearLeft {
                cornerIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            
            if isNearBottom && isNearRight {
                cornerIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isNearTop)
        .animation(.easeInOut(duration: 0.15), value: isNearBottom)
        .animation(.easeInOut(duration: 0.15), value: isNearLeft)
        .animation(.easeInOut(duration: 0.15), value: isNearRight)
    }
    
    private var cornerIndicator: some View {
        Circle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 8, height: 8)
            .padding(6)
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
