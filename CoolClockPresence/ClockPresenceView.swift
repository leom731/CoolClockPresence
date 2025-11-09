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
    @AppStorage("windowPositionPreset") private var windowPositionPreset: String = ClockWindowPosition.topCenter.rawValue
    @AppStorage("fontDesign") private var fontDesign: String = "rounded"

    @State private var isHovering: Bool = false
    @State private var isCommandKeyPressed: Bool = false
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingPurchaseSheet = false
    @State private var mouseLocation: CGPoint = .zero
    @State private var showResizeHints: Bool = false

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
        case "cyan": return .cyan
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        case "primary": return .primary
        default: return .green
        }
    }

    private let baseSize = CGSize(width: 240, height: 80)

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
            // Use DSEG7 Classic LED font for authentic 7-segment display look
            return Font.custom("DSEG7Classic-Bold", size: fontSize)
        case "pixel":
            // Use Press Start 2P for authentic pixelated retro display look
            return Font.custom("PressStart2P-Regular", size: fontSize)
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
            // Use DSEG7 Classic LED font for authentic 7-segment display look
            return Font.custom("DSEG7Classic-Bold", size: fontSize)
        case "pixel":
            // Use Press Start 2P for authentic pixelated retro display look
            return Font.custom("PressStart2P-Regular", size: fontSize)
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
                GlassBackdrop(style: glassStyle)

                VStack(spacing: 2 * currentScale) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        // Calculate if colon should be visible (blink when seconds disabled)
                        let shouldShowSeconds = showSeconds && purchaseManager.isPremium
                        let colonBright = shouldShowSeconds || (Int(context.date.timeIntervalSince1970) % 2 == 0)
                        let colonOpacity = colonBright ? 0.92 : 0.25

                        if fontColorName == "black" {
                            HStack(spacing: 0) {
                                OutlinedText(
                                    text: timeComponents(from: context.date).hours,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor.opacity(0.92),
                                    strokeColor: strokeColor,
                                    lineWidth: max(0.5, 1.1 * currentScale)
                                )
                                OutlinedText(
                                    text: timeComponents(from: context.date).separator,
                                    font: clockFont(for: currentScale),
                                    fillColor: fontColor.opacity(colonOpacity),
                                    strokeColor: strokeColor.opacity(colonOpacity / 0.92),
                                    lineWidth: max(0.5, 1.1 * currentScale)
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
                                    .foregroundStyle(fontColor.opacity(0.92))
                                Text(timeComponents(from: context.date).separator)
                                    .font(clockFont(for: currentScale))
                                    .foregroundStyle(fontColor.opacity(colonOpacity))
                                Text(timeComponents(from: context.date).minutes)
                                    .font(clockFont(for: currentScale))
                                    .foregroundStyle(fontColor.opacity(0.92))
                                if let secondsPart = timeComponents(from: context.date).seconds {
                                    Text(":")
                                        .font(clockFont(for: currentScale))
                                        .foregroundStyle(fontColor.opacity(0.92))
                                    Text(secondsPart)
                                        .font(clockFont(for: currentScale))
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

                    // Battery Status (Premium Only)
                    if showBattery && purchaseManager.isPremium {
                        HStack(spacing: 6 * currentScale) {
                            BatteryIndicatorView(
                                level: batteryMonitor.batteryLevel,
                                isCharging: batteryMonitor.isCharging,
                                scale: currentScale
                            )

                            // Use TimelineView for flashing without state changes
                            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                                // Only flash if battery is low AND not plugged in
                                let shouldFlash = batteryMonitor.batteryLevel <= 25 && !batteryMonitor.isPluggedIn
                                let isVisible = shouldFlash ? (Int(context.date.timeIntervalSince1970 * 2) % 2 == 0) : true

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
                Menu("Font Color") {
                    // Free colors
                    fontColorButton(title: "White", colorName: "white")
                    fontColorButton(title: "Blue", colorName: "blue")

                    // Premium colors
                    if purchaseManager.isPremium {
                        Divider()
                        fontColorButton(title: "Black", colorName: "black")
                        fontColorButton(title: "Green", colorName: "green")
                        fontColorButton(title: "Red", colorName: "red")
                        fontColorButton(title: "Orange", colorName: "orange")
                        fontColorButton(title: "Yellow", colorName: "yellow")
                        fontColorButton(title: "Cyan", colorName: "cyan")
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
                    fontStyleButton(title: "LED (7-Segment)", fontName: "led")
                    fontStyleButton(title: "Pixel (Retro 1980s)", fontName: "pixel")
                    fontStyleButton(title: "Serif", fontName: "serif")
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

                // Glass Style submenu
                Menu("Glass Style") {
                    Button {
                        glassStyle = "liquid"
                    } label: {
                        if glassStyle == "liquid" {
                            Label("Liquid Glass", systemImage: "checkmark")
                        } else {
                            Text("Liquid Glass")
                        }
                    }
                    Button {
                        glassStyle = "clear"
                    } label: {
                        if glassStyle == "clear" {
                            Label("Clear Glass", systemImage: "checkmark")
                        } else {
                            Text("Clear Glass")
                        }
                    }
                    Button {
                        glassStyle = "black"
                    } label: {
                        if glassStyle == "black" {
                            Label("Black Glass", systemImage: "checkmark")
                        } else {
                            Text("Black Glass")
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

                Button("Show Onboarding Again") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowOnboardingAgain"), object: nil)
                }
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
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
    }

    @ViewBuilder
    private func fontColorButton(title: String, colorName: String) -> some View {
        Button {
            fontColorName = colorName
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

// MARK: - Outlined Text Helper

private struct OutlinedText: View {
    let text: String
    let font: Font
    let fillColor: Color
    let strokeColor: Color
    let lineWidth: CGFloat

    private var outlineOffsets: [(CGFloat, CGFloat)] {
        let step = lineWidth / 2
        return [
            (-step, -step), (0, -step), (step, -step),
            (-step, 0),                 (step, 0),
            (-step, step),  (0, step),  (step, step)
        ]
    }

    var body: some View {
        ZStack {
            ForEach(Array(outlineOffsets.enumerated()), id: \.offset) { item in
                Text(text)
                    .font(font)
                    .foregroundColor(strokeColor)
                    .offset(x: item.element.0, y: item.element.1)
            }
            Text(text)
                .font(font)
                .foregroundColor(fillColor)
        }
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
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

    private var timer: Timer?

    init() {
        updateBatteryInfo()
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    private func startMonitoring() {
        // Update battery info every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
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

// MARK: - Glass Backdrop

private struct GlassBackdrop: View {
    let style: String

    var body: some View {
        if style == "liquid" {
            liquidGlassStyle
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
                .blur(radius: 20)

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
                .blur(radius: 30)
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
