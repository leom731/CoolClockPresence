//
//  ClockPresenceView.swift
//  CoolClockPresence
//
//  Crafted for a floating, glassy clock experience on macOS.
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
    @AppStorage("fontColorName") private var fontColorName: String = "green"

    @State private var windowSize: CGSize = CGSize(width: 280, height: 100)
    @StateObject private var batteryMonitor = BatteryMonitor()

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
        case "pink": return .pink
        case "cyan": return .cyan
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        case "primary": return .primary
        default: return .green
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
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date

            GeometryReader { geometry in
                ZStack {
                    GlassBackdrop()

                    VStack(spacing: 4 * scale) {
                        Text(date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute().second()))
                            .font(clockFont)
                            .foregroundStyle(fontColor.opacity(0.92))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .contextMenu {
                                Menu("Font Color") {
                                    Button("White") { fontColorName = "white" }
                                    Button("Black") { fontColorName = "black" }
                                    Button("Red") { fontColorName = "red" }
                                    Button("Orange") { fontColorName = "orange" }
                                    Button("Yellow") { fontColorName = "yellow" }
                                    Button("Green") { fontColorName = "green" }
                                    Button("Blue") { fontColorName = "blue" }
                                    Button("Purple") { fontColorName = "purple" }
                                    Button("Pink") { fontColorName = "pink" }
                                    Button("Cyan") { fontColorName = "cyan" }
                                    Button("Mint") { fontColorName = "mint" }
                                    Button("Teal") { fontColorName = "teal" }
                                    Button("Indigo") { fontColorName = "indigo" }
                                    Divider()
                                    Button("Default") { fontColorName = "primary" }
                                }
                            }

                        // Battery Status
                        HStack(spacing: 4 * scale) {
                            Image(systemName: batteryMonitor.batteryIcon)
                                .font(.system(size: 19 * scale, weight: .medium))
                                .foregroundStyle(batteryMonitor.batteryColor.opacity(0.92))

                            Text("\(batteryMonitor.batteryLevel)%")
                                .font(batteryFont)
                                .foregroundStyle(fontColor.opacity(0.92))
                        }
                    }
                    .padding(.vertical, 12 * scale)
                    .padding(.horizontal, 16 * scale)
                }
                .onAppear {
                    // Restore saved window size
                    windowSize = CGSize(width: windowWidth, height: windowHeight)
                }
                .onChange(of: geometry.size) { _, newSize in
                    windowSize = newSize
                    // Save window size
                    windowWidth = newSize.width
                    windowHeight = newSize.height
                }
            }
            .frame(minWidth: baseSize.width * 0.6, minHeight: baseSize.height * 0.6)
        }
        .ignoresSafeArea()
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
        if isCharging || isPluggedIn {
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
        if isCharging || isPluggedIn {
            return .green
        }

        if batteryLevel <= 20 {
            return .red
        } else if batteryLevel <= 50 {
            return .yellow
        } else {
            return .primary
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
