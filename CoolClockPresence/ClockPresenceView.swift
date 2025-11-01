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
    @AppStorage("fontColorName") private var fontColorName: String = "cyan"
    @AppStorage("showBattery") private var showBattery: Bool = true
    @AppStorage("clockPresence.alwaysOnTop") private var isAlwaysOnTop: Bool = true
    @AppStorage("disappearOnHover") private var disappearOnHover: Bool = true

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

    private func scale(for size: CGSize) -> CGFloat {
        let widthScale = size.width / baseSize.width
        let heightScale = size.height / baseSize.height
        return min(widthScale, heightScale)
    }

    private func clockFont(for scale: CGFloat) -> Font {
        .system(size: 38 * scale, weight: .semibold, design: .rounded)
    }

    private func batteryFont(for scale: CGFloat) -> Font {
        .system(size: 19 * scale, weight: .medium, design: .rounded)
    }

    var body: some View {
        GeometryReader { geometry in
            let currentScale = scale(for: geometry.size)
            ZStack {
                GlassBackdrop()

                VStack(spacing: 4 * currentScale) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(context.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute().second()))
                            .font(clockFont(for: currentScale))
                            .foregroundStyle(fontColor.opacity(0.92))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }

                    // Battery Status (Premium Only)
                    if showBattery && purchaseManager.isPremium {
                        HStack(spacing: 4 * currentScale) {
                            Image(systemName: batteryMonitor.batteryIcon)
                                .font(.system(size: 19 * currentScale, weight: .medium))
                                .foregroundStyle(batteryMonitor.batteryColor.opacity(0.92))

                            Text("\(batteryMonitor.batteryLevel)%")
                                .font(batteryFont(for: currentScale))
                                .foregroundStyle(batteryMonitor.batteryPercentageColor.opacity(0.92))
                        }
                    }
                }
                .padding(.vertical, 12 * currentScale)
                .padding(.horizontal, 16 * currentScale)
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
                    Toggle("Disappear on Hover", isOn: $disappearOnHover)
                } else {
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
        }
        .frame(minWidth: baseSize.width * 0.6, minHeight: baseSize.height * 0.6)
        .ignoresSafeArea()
        .opacity((isHovering && !isCommandKeyPressed && purchaseManager.isPremium && disappearOnHover) ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isCommandKeyPressed)
        .background(HoverDetector(isHovering: $isHovering, isCommandKeyPressed: $isCommandKeyPressed, isPremium: purchaseManager.isPremium, disappearOnHover: disappearOnHover))
    }
}

// MARK: - Hover Detector

struct HoverDetector: NSViewRepresentable {
    @Binding var isHovering: Bool
    @Binding var isCommandKeyPressed: Bool
    let isPremium: Bool
    let disappearOnHover: Bool

    func makeNSView(context: Context) -> NSView {
        let view = HoverView()
        view.isPremium = isPremium
        view.disappearOnHover = disappearOnHover
        view.onHoverChange = { hovering in
            isHovering = hovering
        }
        view.onCommandKeyChange = { commandPressed in
            isCommandKeyPressed = commandPressed
        }
        view.onShouldIgnoreMouseEvents = { [weak view] shouldIgnore in
            guard let view = view else { return }
            view.applyWindowMouseEventSetting(shouldIgnore)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let hoverView = nsView as? HoverView {
            hoverView.isPremium = isPremium
            hoverView.disappearOnHover = disappearOnHover
            hoverView.requestMouseEventRefresh()
        }
    }
}

class HoverView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    var onCommandKeyChange: ((Bool) -> Void)?
    var onShouldIgnoreMouseEvents: ((Bool) -> Void)?
    var isPremium: Bool = false {
        didSet {
            if isPremium != oldValue {
                requestMouseEventRefresh()
            }
        }
    }
    var disappearOnHover: Bool = true {
        didSet {
            if disappearOnHover != oldValue {
                requestMouseEventRefresh()
            }
        }
    }

    private var trackingArea: NSTrackingArea?
    private var isHovering: Bool = false
    private var isCommandPressed: Bool = false
    private var ignoringMouseEvents: Bool = false
    private weak var lastAppliedWindow: NSWindow?
    private var eventMonitor: Any?
    private var pendingRefresh = false

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
            self?.setCommandKeyState(event.modifierFlags.contains(.command))
            return event
        }
    }

    private func setHoverState(_ hovering: Bool) {
        if isHovering != hovering {
            isHovering = hovering
            scheduleHoverChange(hovering)
        }
        updateMouseEventHandling()
    }

    private func setCommandKeyState(_ commandPressed: Bool) {
        if isCommandPressed != commandPressed {
            isCommandPressed = commandPressed
            scheduleCommandKeyChange(commandPressed)
        }
        updateMouseEventHandling()
    }

    private func scheduleHoverChange(_ hovering: Bool) {
        guard onHoverChange != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onHoverChange?(hovering)
        }
    }

    private func scheduleCommandKeyChange(_ commandPressed: Bool) {
        guard onCommandKeyChange != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onCommandKeyChange?(commandPressed)
        }
    }

    private func scheduleIgnoreMouseEvents(_ shouldIgnore: Bool) {
        guard onShouldIgnoreMouseEvents != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onShouldIgnoreMouseEvents?(shouldIgnore)
        }
    }

    private func updateMouseEventHandling() {
        // Only ignore mouse events when hovering AND command key is NOT pressed (Premium only with disappear on hover enabled)
        let shouldIgnore = isHovering && !isCommandPressed && isPremium && disappearOnHover
        let currentWindow = window
        let windowChanged = currentWindow !== lastAppliedWindow

        guard shouldIgnore != ignoringMouseEvents || windowChanged else { return }

        ignoringMouseEvents = shouldIgnore
        lastAppliedWindow = currentWindow
        scheduleIgnoreMouseEvents(shouldIgnore)
    }

    func requestMouseEventRefresh() {
        guard !pendingRefresh else { return }
        pendingRefresh = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pendingRefresh = false
            self.updateMouseEventHandling()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestMouseEventRefresh()
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
        super.mouseEntered(with: event)
        setCommandKeyState(event.modifierFlags.contains(.command))
        setHoverState(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHoverState(false)
        setCommandKeyState(event.modifierFlags.contains(.command))
    }

    fileprivate func applyWindowMouseEventSetting(_ shouldIgnore: Bool) {
        guard let window = window else { return }
        let targetWindow = window
        DispatchQueue.main.async {
            guard targetWindow.ignoresMouseEvents != shouldIgnore else { return }
            targetWindow.ignoresMouseEvents = shouldIgnore
        }
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
            return Color(red: 0.996, green: 0.784, blue: 0.294)
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
