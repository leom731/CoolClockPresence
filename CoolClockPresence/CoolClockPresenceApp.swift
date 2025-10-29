//
//  CoolClockPresenceApp.swift
//  CoolClockPresence
//
//  macOS entry point that presents the floating glass clock.
//

#if os(macOS)
import SwiftUI
import AppKit

@main
struct CoolClockPresenceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("clockPresence.alwaysOnTop") private var isAlwaysOnTop = true

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("View") {
                Toggle("Always on Top", isOn: $isAlwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel?
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default preferences
        defaults.register(defaults: [
            "clockPresence.alwaysOnTop": true,
            "windowX": -1.0,  // -1 means not set yet, will center on first launch
            "windowY": -1.0
        ])

        // Create a floating panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 100),
            styleMask: [.nonactivatingPanel, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel to appear on all spaces
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        // Set size constraints
        panel.contentMinSize = CGSize(width: 168, height: 60)
        panel.contentMaxSize = CGSize(width: 616, height: 200)

        // Set SwiftUI content
        let contentView = ClockPresenceView()
        panel.contentView = NSHostingView(rootView: contentView)

        // Restore saved position or center if first launch
        let savedX = defaults.double(forKey: "windowX")
        let savedY = defaults.double(forKey: "windowY")

        if savedX >= 0 && savedY >= 0 {
            // Restore saved position
            panel.setFrameOrigin(NSPoint(x: savedX, y: savedY))
        } else {
            // First launch - center the window
            panel.center()
        }

        panel.orderFrontRegardless()

        self.window = panel

        // Observe window position changes to save them
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        // Keep app running as accessory (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Observe changes to the alwaysOnTop setting
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWindowLevel),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        updateWindowLevel()
    }

    @objc private func updateWindowLevel() {
        guard let panel = window else { return }
        let isAlwaysOnTop = UserDefaults.standard.bool(forKey: "clockPresence.alwaysOnTop")
        panel.level = isAlwaysOnTop ? .statusBar : .normal
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let panel = window else { return }
        let origin = panel.frame.origin
        defaults.set(origin.x, forKey: "windowX")
        defaults.set(origin.y, forKey: "windowY")
    }
}
#endif
