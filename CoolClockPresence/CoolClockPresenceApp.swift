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
    @StateObject private var purchaseManager = PurchaseManager.shared
    @AppStorage("fontColorName") private var fontColorName = "cyan"
    @AppStorage("showSeconds") private var showSeconds = true
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("clockPresence.alwaysOnTop") private var isAlwaysOnTop = true
    @AppStorage("disappearOnHover") private var disappearOnHover = true

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandMenu("Clock Controls") {
                Menu("Font Color") {
                    fontColorCommandButton(title: "White", colorName: "white")
                    fontColorCommandButton(title: "Cyan", colorName: "cyan")
                    fontColorCommandButton(title: "Default", colorName: "primary")

                    if purchaseManager.isPremium {
                        Divider()
                        fontColorCommandButton(title: "Black", colorName: "black")
                        fontColorCommandButton(title: "Red", colorName: "red")
                        fontColorCommandButton(title: "Orange", colorName: "orange")
                        fontColorCommandButton(title: "Yellow", colorName: "yellow")
                        fontColorCommandButton(title: "Green", colorName: "green")
                        fontColorCommandButton(title: "Blue", colorName: "blue")
                        fontColorCommandButton(title: "Purple", colorName: "purple")
                        fontColorCommandButton(title: "Pink", colorName: "pink")
                        fontColorCommandButton(title: "Mint", colorName: "mint")
                        fontColorCommandButton(title: "Teal", colorName: "teal")
                        fontColorCommandButton(title: "Indigo", colorName: "indigo")
                    }
                }

                Divider()

                if purchaseManager.isPremium {
                    Toggle("Show Seconds", isOn: $showSeconds)
                    Toggle("Show Battery", isOn: $showBattery)
                    Toggle("Always on Top", isOn: $isAlwaysOnTop)
                    Toggle("Disappear on Hover", isOn: $disappearOnHover)
                } else {
                    Button("Show Seconds 🔒 Premium") {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowPurchaseView"), object: nil)
                    }
                    Button("Show Battery 🔒 Premium") {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowPurchaseView"), object: nil)
                    }
                    Button("Always on Top 🔒 Premium") {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowPurchaseView"), object: nil)
                    }
                    Button("Disappear on Hover 🔒 Premium") {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowPurchaseView"), object: nil)
                    }
                }

                Divider()

                if !purchaseManager.isPremium {
                    Button("⭐️ Upgrade to Premium ($0.99)") {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowPurchaseView"), object: nil)
                    }
                    Divider()
                }

                Button("Show Onboarding Again") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowOnboardingAgain"), object: nil)
                }

                Divider()

                Button("Quit CoolClockPresence") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }

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

            // Add Help menu
            CommandGroup(replacing: .help) {
                Button("CoolClockPresence Help") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowHelpWindow"), object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}

private extension CoolClockPresenceApp {
    @ViewBuilder
    func fontColorCommandButton(title: String, colorName: String) -> some View {
        Button {
            fontColorName = colorName
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "checkmark")
                    .opacity(fontColorName == colorName ? 1 : 0)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSPanel?
    var onboardingWindow: NSWindow?
    var helpWindow: NSWindow?
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default preferences
        defaults.register(defaults: [
            "clockPresence.alwaysOnTop": true,
            "disappearOnHover": true,
            "windowX": -1.0,  // -1 means not set yet, will center on first launch
            "windowY": -1.0,
            "windowWidth": 280.0,
            "windowHeight": 100.0,
            "hasCompletedOnboarding": false
        ])

        // Setup Menu Bar Extra (status bar item)
        setupMenuBarExtra()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPurchaseView),
            name: NSNotification.Name("ShowPurchaseView"),
            object: nil
        )

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

        // Build menu dynamically
        updateMenuBarMenu()

        // Observe premium status changes to rebuild menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarMenu),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func updateMenuBarMenu() {
        let menu = NSMenu()
        let isPremium = defaults.bool(forKey: "isPremiumUnlocked")

        // Show/Hide Clock Window
        menu.addItem(NSMenuItem(title: "Show Clock Window", action: #selector(toggleClockWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Font Color submenu
        let fontColorMenu = NSMenu()

        // Free colors
        fontColorMenu.addItem(createFontColorMenuItem(title: "White", colorName: "white"))
        fontColorMenu.addItem(createFontColorMenuItem(title: "Cyan", colorName: "cyan"))
        fontColorMenu.addItem(createFontColorMenuItem(title: "Default", colorName: "primary"))

        // Premium colors
        if isPremium {
            fontColorMenu.addItem(NSMenuItem.separator())
            fontColorMenu.addItem(createFontColorMenuItem(title: "Black", colorName: "black"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Red", colorName: "red"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Orange", colorName: "orange"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Yellow", colorName: "yellow"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Green", colorName: "green"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Blue", colorName: "blue"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Purple", colorName: "purple"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Pink", colorName: "pink"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Mint", colorName: "mint"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Teal", colorName: "teal"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Indigo", colorName: "indigo"))
        }

        let fontColorItem = NSMenuItem(title: "Font Color", action: nil, keyEquivalent: "")
        fontColorItem.submenu = fontColorMenu
        menu.addItem(fontColorItem)
        menu.addItem(NSMenuItem.separator())

        // Premium features
        if isPremium {
            let showSecondsItem = NSMenuItem(title: "Show Seconds", action: #selector(toggleSeconds), keyEquivalent: "")
            showSecondsItem.state = defaults.bool(forKey: "showSeconds") ? .on : .off
            menu.addItem(showSecondsItem)

            let showBatteryItem = NSMenuItem(title: "Show Battery", action: #selector(toggleBattery), keyEquivalent: "")
            showBatteryItem.state = defaults.bool(forKey: "showBattery") ? .on : .off
            menu.addItem(showBatteryItem)

            let alwaysOnTopItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
            alwaysOnTopItem.state = defaults.bool(forKey: "clockPresence.alwaysOnTop") ? .on : .off
            menu.addItem(alwaysOnTopItem)

            let disappearOnHoverItem = NSMenuItem(title: "Disappear on Hover", action: #selector(toggleDisappearOnHover), keyEquivalent: "")
            disappearOnHoverItem.state = defaults.bool(forKey: "disappearOnHover") ? .on : .off
            menu.addItem(disappearOnHoverItem)
        } else {
            menu.addItem(NSMenuItem(title: "Show Seconds 🔒 Premium", action: #selector(showPurchaseView), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Show Battery 🔒 Premium", action: #selector(showPurchaseView), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Always on Top 🔒 Premium", action: #selector(showPurchaseView), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Disappear on Hover 🔒 Premium", action: #selector(showPurchaseView), keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())

        // Upgrade option
        if !isPremium {
            menu.addItem(NSMenuItem(title: "⭐️ Upgrade to Premium ($0.99)", action: #selector(showPurchaseView), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
        }

        // About and other options
        menu.addItem(NSMenuItem(title: "About CoolClockPresence", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Help", action: #selector(showHelpWindow), keyEquivalent: "?"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Onboarding Again", action: #selector(showOnboardingAgain), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CoolClockPresence", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func createFontColorMenuItem(title: String, colorName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(changeFontColor(_:)), keyEquivalent: "")
        item.representedObject = colorName

        // Add checkmark if this is the current color
        let currentColor = defaults.string(forKey: "fontColorName") ?? "cyan"
        if currentColor == colorName {
            item.state = .on
        }

        return item
    }

    @objc private func changeFontColor(_ sender: NSMenuItem) {
        if let colorName = sender.representedObject as? String {
            defaults.set(colorName, forKey: "fontColorName")
            updateMenuBarMenu()
        }
    }

    @objc private func toggleSeconds() {
        let current = defaults.bool(forKey: "showSeconds")
        defaults.set(!current, forKey: "showSeconds")
        updateMenuBarMenu()
    }

    @objc private func toggleBattery() {
        let current = defaults.bool(forKey: "showBattery")
        defaults.set(!current, forKey: "showBattery")
        updateMenuBarMenu()
    }

    @objc private func toggleAlwaysOnTop() {
        let current = defaults.bool(forKey: "clockPresence.alwaysOnTop")
        defaults.set(!current, forKey: "clockPresence.alwaysOnTop")
        updateMenuBarMenu()
    }

    @objc private func toggleDisappearOnHover() {
        let current = defaults.bool(forKey: "disappearOnHover")
        defaults.set(!current, forKey: "disappearOnHover")
        updateMenuBarMenu()
    }

    @objc private func showPurchaseView() {
        // Show purchase view in a new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Upgrade to Premium"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false

        let purchaseView = PurchaseView()
        window.contentView = NSHostingView(rootView: purchaseView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    @objc private func showHelpWindow() {
        // If help window already exists, just bring it to front
        if let existingWindow = helpWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create help window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "CoolClockPresence Help"
        window.titlebarAppearsTransparent = false
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("HelpWindow")

        let helpView = HelpView(isPresented: .init(
            get: { [weak self] in self?.helpWindow != nil },
            set: { [weak self] isPresented in
                if !isPresented {
                    self?.helpWindow?.close()
                    self?.helpWindow = nil
                }
            }
        ))

        window.contentView = NSHostingView(rootView: helpView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.helpWindow = window
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

        // Hide the standard window buttons BEFORE setting the NSHostingView to avoid NSRemoteView warnings
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

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

        // Observe "Show Help Window" request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showHelpWindow),
            name: NSNotification.Name("ShowHelpWindow"),
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
