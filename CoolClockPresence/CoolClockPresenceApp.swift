// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  CoolClockPresenceApp.swift
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

            // Add standard App Menu with Quit option
            CommandGroup(replacing: .appInfo) {
                Button("About CoolClockPresence") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "CoolClockPresence",
                        .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    ])
                }
            }

            CommandGroup(after: .appInfo) {
                Divider()
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSPanel?
    var onboardingWindow: NSWindow?
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default preferences
        defaults.register(defaults: [
            "clockPresence.alwaysOnTop": true,
            "windowX": -1.0,  // -1 means not set yet, will center on first launch
            "windowY": -1.0,
            "windowWidth": 280.0,
            "windowHeight": 100.0,
            "hasCompletedOnboarding": false
        ])

        // Setup Menu Bar Extra (status bar item)
        setupMenuBarExtra()

        // Check if this is the first launch
        let hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")

        if !hasCompletedOnboarding {
            showOnboarding()
        } else {
            showMainClock()
        }
    }

    private func setupMenuBarExtra() {
        // Create status bar item with clock icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "CoolClockPresence")
            button.image?.isTemplate = true
        }

        // Create menu for status bar item
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show Clock Window", action: #selector(toggleClockWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About CoolClockPresence", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Onboarding Again", action: #selector(showOnboardingAgain), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CoolClockPresence", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func toggleClockWindow() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.applicationName: "CoolClockPresence",
            NSApplication.AboutPanelOptionKey.applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func showOnboarding() {
        // Show the app in the dock while onboarding
        NSApp.setActivationPolicy(.regular)

        // Create onboarding window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to CoolClockPresence"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false

        // Create onboarding view with binding
        let onboardingView = OnboardingView(isPresented: .init(
            get: { [weak self] in self?.onboardingWindow != nil },
            set: { [weak self] isPresented in
                if !isPresented {
                    self?.onboardingWindow?.close()
                    self?.onboardingWindow = nil
                    // Show the main clock after onboarding
                    self?.showMainClock()
                }
            }
        ))

        window.contentView = NSHostingView(rootView: onboardingView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.onboardingWindow = window
    }

    private func showMainClock() {
        // Restore saved window size or use defaults
        let savedWidth = defaults.double(forKey: "windowWidth")
        let savedHeight = defaults.double(forKey: "windowHeight")
        let width = savedWidth > 0 ? savedWidth : 280
        let height = savedHeight > 0 ? savedHeight : 100

        // Create a floating panel with saved size - restore original working config with title bar buttons
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel to appear on all spaces including full screen (original working config)
        panel.title = "CoolClockPresence"
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden  // Keep hidden as in original
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true  // Restore original setting
        panel.isRestorable = false  // Disable window restoration to fix className error

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
        panel.delegate = self

        self.window = panel

        // Observe window position changes to save them
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        // Observe window size changes to save them
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: panel
        )

        // Show app in dock and menu bar (required by App Store)
        NSApp.setActivationPolicy(.regular)

        // Observe changes to the alwaysOnTop setting
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWindowLevel),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        updateWindowLevel()

        // Observe "Show Onboarding Again" request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showOnboardingAgain),
            name: NSNotification.Name("ShowOnboardingAgain"),
            object: nil
        )
    }

    @objc private func showOnboardingAgain() {
        // If onboarding window already exists, just bring it to front
        if let existingWindow = onboardingWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Temporarily show app in dock
        NSApp.setActivationPolicy(.regular)

        // Create onboarding window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "CoolClockPresence Tutorial"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false

        // Create onboarding view with binding
        let onboardingView = OnboardingView(isPresented: .init(
            get: { [weak self] in self?.onboardingWindow != nil },
            set: { [weak self] isPresented in
                if !isPresented {
                    self?.onboardingWindow?.close()
                    self?.onboardingWindow = nil
                    // Keep app visible in dock and menu bar
                    NSApp.setActivationPolicy(.regular)
                }
            }
        ))

        window.contentView = NSHostingView(rootView: onboardingView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.onboardingWindow = window
    }

    @objc private func updateWindowLevel() {
        guard let panel = window else { return }
        let isAlwaysOnTop = UserDefaults.standard.bool(forKey: "clockPresence.alwaysOnTop")
        // Use high window level for full screen compatibility when always on top
        panel.level = isAlwaysOnTop ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow))) : .normal
    }

    @objc func windowDidMove(_ notification: Notification) {
        guard let panel = window else { return }
        let origin = panel.frame.origin
        defaults.set(origin.x, forKey: "windowX")
        defaults.set(origin.y, forKey: "windowY")
    }

    @objc func windowDidResize(_ notification: Notification) {
        guard let panel = window else { return }
        let size = panel.frame.size
        defaults.set(size.width, forKey: "windowWidth")
        defaults.set(size.height, forKey: "windowHeight")
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide window instead of closing when close button is clicked
        // App can still be accessed from menu bar and can be quit from there
        sender.orderOut(nil)
        return false
    }
}
#endif
