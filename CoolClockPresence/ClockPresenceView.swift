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
    @AppStorage("windowWidth") private var windowWidth: Double = 280
    @AppStorage("windowHeight") private var windowHeight: Double = 100
    @AppStorage("fontColorName") private var fontColorName: String = "cyan"
    @AppStorage("showBattery") private var showBattery: Bool = true
    @AppStorage("clockPresence.alwaysOnTop") private var isAlwaysOnTop: Bool = true

    @State private var windowSize: CGSize = CGSize(width: 280, height: 100)
    @State private var isHovering: Bool = false
    @State private var isCommandKeyPressed: Bool = false
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingPurchaseSheet = false

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
        default: return .cyan
        }
    }

    private let baseSize = CGSize(width: 280, height: 100)

    private var scale: CGFloat {
        // Calculate scale based on current window size relative to base size
        let widthScale = windowSize.width / baseSize.width
        let heightScale = windowSize.height / baseSize.height
        return min(widthScale, heightScale)
    }

    private var clockFont: Font {
        .system(size: 38 * scale, weight: .semibold, design: .rounded)
    }

    private var batteryFont: Font {
        .system(size: 19 * scale, weight: .medium, design: .rounded)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GlassBackdrop()

                VStack(spacing: 4 * scale) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(context.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute().second()))
                            .font(clockFont)
                            .foregroundStyle(fontColor.opacity(0.92))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }

                    // Battery Status (Premium Only)
                    if showBattery && purchaseManager.isPremium {
                        HStack(spacing: 4 * scale) {
                            Image(systemName: batteryMonitor.batteryIcon)
                                .font(.system(size: 19 * scale, weight: .medium))
                                .foregroundStyle(batteryMonitor.batteryColor.opacity(0.92))

                            Text("\(batteryMonitor.batteryLevel)%")
                                .font(batteryFont)
                                .foregroundStyle(batteryMonitor.batteryPercentageColor.opacity(0.92))
                        }
                    }
                }
                .padding(.vertical, 12 * scale)
                .padding(.horizontal, 16 * scale)
            }
            .contentShape(Rectangle())
            .contextMenu {
                Menu("Font Color") {
                    // Free colors
                    Button("White") { fontColorName = "white" }
                    Button("Cyan") { fontColorName = "cyan" }
                    Button("Default") { fontColorName = "primary" }

                    // Premium colors
                    if purchaseManager.isPremium {
                        Divider()
                        Button("Black") { fontColorName = "black" }
                        Button("Red") { fontColorName = "red" }
                        Button("Orange") { fontColorName = "orange" }
                        Button("Yellow") { fontColorName = "yellow" }
                        Button("Green") { fontColorName = "green" }
                        Button("Blue") { fontColorName = "blue" }
                        Button("Purple") { fontColorName = "purple" }
                        Button("Pink") { fontColorName = "pink" }
                        Button("Mint") { fontColorName = "mint" }
                        Button("Teal") { fontColorName = "teal" }
                        Button("Indigo") { fontColorName = "indigo" }
                    }
                }
                Divider()

                // Premium features
                if purchaseManager.isPremium {
                    Toggle("Show Battery", isOn: $showBattery)
                    Toggle("Always on Top", isOn: $isAlwaysOnTop)
                } else {
                    Button("Show Battery 🔒 Premium") {
                        showingPurchaseSheet = true
                    }
                    Button("Always on Top 🔒 Premium") {
                        showingPurchaseSheet = true
                    }
                }

                Divider()

                // Upgrade option
                if !purchaseManager.isPremium {
                    Button("⭐️ Upgrade to Premium ($0.99)") {
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
            .onAppear {
                // Restore saved window size
                windowSize = CGSize(width: windowWidth, height: windowHeight)
            }
            .onChange(of: geometry.size) { _, newSize in
                // Use Task to avoid layout recursion
                Task { @MainActor in
                    windowSize = newSize
                    // Save window size
                    windowWidth = newSize.width
                    windowHeight = newSize.height
                }
            }
        }
        .frame(minWidth: baseSize.width * 0.6, minHeight: baseSize.height * 0.6)
        .ignoresSafeArea()
        .opacity((isHovering && !isCommandKeyPressed && purchaseManager.isPremium) ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isCommandKeyPressed)
        .background(HoverDetector(isHovering: $isHovering, isCommandKeyPressed: $isCommandKeyPressed, isPremium: purchaseManager.isPremium))
    }
}

// MARK: - Hover Detector

struct HoverDetector: NSViewRepresentable {
    @Binding var isHovering: Bool
    @Binding var isCommandKeyPressed: Bool
    let isPremium: Bool

    func makeNSView(context: Context) -> NSView {
        let view = HoverView()
        view.isPremium = isPremium
        view.onHoverChange = { hovering in
            isHovering = hovering
        }
        view.onCommandKeyChange = { commandPressed in
            isCommandKeyPressed = commandPressed
        }
        view.onShouldIgnoreMouseEvents = { shouldIgnore in
            // Make window click-through only when hovering without command key (Premium only)
            if let window = view.window, view.isPremium {
                window.ignoresMouseEvents = shouldIgnore
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let hoverView = nsView as? HoverView {
            hoverView.isPremium = isPremium
        }
    }
}

class HoverView: NSView {
// clase HoverView: NSView
    var onHoverChange: ((Bool) -> Void)?
    var onCommandKeyChange: ((Bool) -> Void)?
    var onShouldIgnoreMouseEvents: ((Bool) -> Void)?
    var isPremium: Bool = false

    private var trackingArea: NSTrackingArea?
    private var isHovering: Bool = false
    private var isCommandPressed: Bool = false
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

    private func setupCommandKeyMonitor() {
        // Monitor for flag changes (modifier keys)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }

            let commandPressed = event.modifierFlags.contains(.command)

            if self.isCommandPressed != commandPressed {
                self.isCommandPressed = commandPressed
                self.onCommandKeyChange?(commandPressed)
                self.updateMouseEventHandling()
            }

            return event
        }
    }

    private func updateMouseEventHandling() {
        // Only ignore mouse events when hovering AND command key is NOT pressed (Premium only)
        let shouldIgnore = isHovering && !isCommandPressed && isPremium
        onShouldIgnoreMouseEvents?(shouldIgnore)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existingTrackingArea = trackingArea {
            removeTrackingArea(existingTrackingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        isCommandPressed = event.modifierFlags.contains(.command)
        onHoverChange?(true)
        onCommandKeyChange?(isCommandPressed)
        updateMouseEventHandling()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        onHoverChange?(false)
        updateMouseEventHandling()
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

    var batteryIcon: String {
        if isCharging {
            return "battery.100percent.bolt"
        }

        switch batteryLevel {
        case 0...10:
            return "battery.0percent"
        case 11...25:
            return "battery.25percent"
        case 26...50:
            return "battery.50percent"
        case 51...75:
            return "battery.75percent"
        default:
            return "battery.100percent"
        }
    }

    var batteryColor: Color {
        if isCharging {
            return .green
        }

        if batteryLevel <= 20 {
            return .red
        } else if batteryLevel <= 50 {
            return Color(white: 0.8)
       } else if batteryLevel <= 70 {
            return Color(white: 0.8)
        } else {
            return Color(white: 0.8)
        }
    }

    var batteryPercentageColor: Color {
        if batteryLevel <= 20 {
            return .red
        } else if batteryLevel <= 50 {
            return .orange
        } else if batteryLevel <= 70 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Glass Backdrop

private struct GlassBackdrop: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.3))
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color.cyan.opacity(0.08),
                            Color.purple.opacity(0.10),
                            Color.blue.opacity(0.08)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .blur(radius: 30)
                    .opacity(0.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.08)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
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
