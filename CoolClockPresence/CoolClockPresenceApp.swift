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

    var body: some Scene {
        Settings {
            SettingsView()
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

            CommandMenu("Clock Position") {
                let currentPreset = UserDefaults.standard.string(forKey: "windowPositionPreset") ?? ClockWindowPosition.topCenter.rawValue
                ForEach(ClockWindowPosition.allCases) { position in
                    Button {
                        appDelegate.applyWindowPosition(position)
                    } label: {
                        if currentPreset == position.rawValue {
                            Label(position.displayName, systemImage: "checkmark")
                        } else {
                            Text(position.displayName)
                        }
                    }
                }
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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var window: NSPanel?
    var onboardingWindow: NSWindow?
    var helpWindow: NSWindow?
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem?
    private var lastKnownWindowPresetValue: String?
    private var isApplyingPositionPreset = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default preferences
        defaults.register(defaults: [
            "fontColorName": "green",
            "clockPresence.alwaysOnTop": true,
            "disappearOnHover": true,
            "windowX": -1.0,  // -1 means not set yet, will center on first launch
            "windowY": -1.0,
            "windowWidth": 280.0,
            "windowHeight": 100.0,
            "hasCompletedOnboarding": false,
            "glassStyle": "liquid",
            "windowPositionPreset": ClockWindowPosition.topCenter.rawValue
        ])
        lastKnownWindowPresetValue = defaults.string(forKey: "windowPositionPreset") ?? ClockWindowPosition.topCenter.rawValue

        // Setup Menu Bar Extra (status bar item)
        setupMenuBarExtra()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowPresetPreferenceChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

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

        // Create initial menu
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

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

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Rebuild menu when it's about to open, so we can check modifier flags
        updateMenuBarMenu()
    }

    @objc private func updateMenuBarMenu() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let isPremium = defaults.bool(forKey: "isPremiumUnlocked")

        // Show/Hide Clock Window
        menu.addItem(NSMenuItem(title: "Show Clock Window", action: #selector(toggleClockWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Font Color submenu
        let fontColorMenu = NSMenu()

        // Free colors
        fontColorMenu.addItem(createFontColorMenuItem(title: "White", colorName: "white"))
        fontColorMenu.addItem(createFontColorMenuItem(title: "Green", colorName: "green"))

        // Premium colors
        if isPremium {
            fontColorMenu.addItem(NSMenuItem.separator())
            fontColorMenu.addItem(createFontColorMenuItem(title: "Black", colorName: "black"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Cyan", colorName: "cyan"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Red", colorName: "red"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Orange", colorName: "orange"))
            fontColorMenu.addItem(createFontColorMenuItem(title: "Yellow", colorName: "yellow"))
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

        // Glass Style submenu
        let glassStyleMenu = NSMenu()
        glassStyleMenu.addItem(createGlassStyleMenuItem(title: "Liquid Glass", styleName: "liquid"))
        glassStyleMenu.addItem(createGlassStyleMenuItem(title: "Clear Glass", styleName: "clear"))
        glassStyleMenu.addItem(createGlassStyleMenuItem(title: "Black Glass", styleName: "black"))

        let glassStyleItem = NSMenuItem(title: "Glass Style", action: nil, keyEquivalent: "")
        glassStyleItem.submenu = glassStyleMenu
        menu.addItem(glassStyleItem)
        menu.addItem(NSMenuItem.separator())

        // Clock position submenu
        let positionMenu = NSMenu()
        let currentPreset = defaults.string(forKey: "windowPositionPreset") ?? ClockWindowPosition.topCenter.rawValue
        ClockWindowPosition.allCases.forEach { position in
            let item = NSMenuItem(title: position.displayName, action: #selector(snapWindowToPreset(_:)), keyEquivalent: "")
            item.representedObject = position.rawValue
            item.state = currentPreset == position.rawValue ? .on : .off
            item.target = self
            positionMenu.addItem(item)
        }

        let positionItem = NSMenuItem(title: "Clock Position", action: nil, keyEquivalent: "")
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)
        menu.addItem(NSMenuItem.separator())

        // Premium features
        if isPremium {
            let showSecondsItem = NSMenuItem(title: "Show Seconds", action: #selector(toggleSeconds), keyEquivalent: "")
            showSecondsItem.state = defaults.bool(forKey: "showSeconds") ? .on : .off
            menu.addItem(showSecondsItem)

            let use24HourItem = NSMenuItem(title: "Use 24-Hour Format", action: #selector(toggleUse24HourFormat), keyEquivalent: "")
            use24HourItem.state = defaults.bool(forKey: "use24HourFormat") ? .on : .off
            menu.addItem(use24HourItem)

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
            menu.addItem(NSMenuItem(title: "Use 24-Hour Format 🔒 Premium", action: #selector(showPurchaseView), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Show Battery 🔒 Premium", action: #selector(showPurchaseView), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Always on Top 🔒 Premium", action: #selector(showPurchaseView), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Disappear on Hover 🔒 Premium", action: #selector(showPurchaseView), keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())

        // Upgrade option
        if !isPremium {
            menu.addItem(NSMenuItem(title: "⭐️ Upgrade to Premium ($1.99)", action: #selector(showPurchaseView), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
        }

        // About and other options
        menu.addItem(NSMenuItem(title: "About CoolClockPresence", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Help", action: #selector(showHelpWindow), keyEquivalent: "?"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Onboarding Again", action: #selector(showOnboardingAgain), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CoolClockPresence", action: #selector(quitApp), keyEquivalent: "q"))
    }

    private func createFontColorMenuItem(title: String, colorName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(changeFontColor(_:)), keyEquivalent: "")
        item.representedObject = colorName

        // Add checkmark if this is the current color
        let currentColor = defaults.string(forKey: "fontColorName") ?? "green"
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

    private func createGlassStyleMenuItem(title: String, styleName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(changeGlassStyle(_:)), keyEquivalent: "")
        item.representedObject = styleName

        // Add checkmark if this is the current style
        let currentStyle = defaults.string(forKey: "glassStyle") ?? "liquid"
        if currentStyle == styleName {
            item.state = .on
        }

        return item
    }

    @objc private func changeGlassStyle(_ sender: NSMenuItem) {
        if let styleName = sender.representedObject as? String {
            defaults.set(styleName, forKey: "glassStyle")
            updateMenuBarMenu()
        }
    }

    @objc private func snapWindowToPreset(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let position = ClockWindowPosition(rawValue: rawValue) else {
            return
        }
        applyWindowPosition(position)
    }

    @objc private func handleWindowPresetPreferenceChange() {
        let currentValue = defaults.string(forKey: "windowPositionPreset") ?? ClockWindowPosition.topCenter.rawValue
        guard currentValue != lastKnownWindowPresetValue else { return }
        lastKnownWindowPresetValue = currentValue

        guard currentValue != ClockWindowPosition.customIdentifier,
              let preset = ClockWindowPosition(rawValue: currentValue) else {
            return
        }

        applyWindowPosition(preset, persistPosition: false)
    }

    func applyWindowPosition(_ position: ClockWindowPosition, persistPosition: Bool = true) {
        let performWork = { [weak self] in
            guard let self else { return }
            guard let panel = self.window else { return }
            let candidateScreens: [NSScreen?] = [panel.screen, NSScreen.main, NSScreen.screens.first]
            guard let screen = candidateScreens.compactMap({ $0 }).first else {
                panel.center()
                return
            }

            let origin = self.origin(for: position, in: screen.visibleFrame, windowSize: panel.frame.size)
            let newFrame = NSRect(origin: origin, size: panel.frame.size)

            self.isApplyingPositionPreset = true
            panel.setFrame(newFrame, display: true, animate: false)
            panel.displayIfNeeded()
            panel.orderFrontRegardless()

            self.defaults.set(origin.x, forKey: "windowX")
            self.defaults.set(origin.y, forKey: "windowY")

            if persistPosition {
                self.lastKnownWindowPresetValue = position.rawValue
                self.defaults.set(position.rawValue, forKey: "windowPositionPreset")
            }

            DispatchQueue.main.async { [weak self] in
                self?.isApplyingPositionPreset = false
            }
        }

        if Thread.isMainThread {
            performWork()
        } else {
            DispatchQueue.main.async(execute: performWork)
        }
    }

    private func origin(for position: ClockWindowPosition, in screenFrame: NSRect, windowSize: NSSize, padding: CGFloat = 12) -> NSPoint {
        switch position {
        case .topLeft:
            return NSPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        case .topCenter:
            return NSPoint(
                x: screenFrame.midX - (windowSize.width / 2),
                y: screenFrame.maxY - windowSize.height - padding
            )
        case .topRight:
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        case .bottomLeft:
            return NSPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding
            )
        case .bottomCenter:
            return NSPoint(
                x: screenFrame.midX - (windowSize.width / 2),
                y: screenFrame.minY + padding
            )
        case .bottomRight:
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.minY + padding
            )
        }
    }

    @objc private func toggleSeconds() {
        let current = defaults.bool(forKey: "showSeconds")
        defaults.set(!current, forKey: "showSeconds")
        updateMenuBarMenu()
    }

    @objc private func toggleUse24HourFormat() {
        let current = defaults.bool(forKey: "use24HourFormat")
        defaults.set(!current, forKey: "use24HourFormat")
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 640),
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
        let panel = ActivatingPanel(
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
        panel.becomesKeyOnlyIfNeeded = true  // Non-activating panel keeps fullscreen compatibility
        panel.isRestorable = false  // Disable window restoration to fix className error

        // Set size constraints
        panel.contentMinSize = CGSize(width: 168, height: 60)
        panel.contentMaxSize = CGSize(width: 616, height: 200)

        // Hide the standard window buttons BEFORE setting the NSHostingView to avoid NSRemoteView warnings
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Set rounded corners for the window to match content
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 40
            contentView.layer?.masksToBounds = true
        }

        // Set SwiftUI content
        let contentView = ClockPresenceView()
        let hostingView = NSHostingView(rootView: contentView)
        panel.contentView = hostingView

        // Apply corner radius to hosting view
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 40
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true

        self.window = panel

        // Restore saved position, preset, or default top center
        let savedX = defaults.double(forKey: "windowX")
        let savedY = defaults.double(forKey: "windowY")
        let presetIsPersisted = defaults.object(forKey: "windowPositionPreset") != nil
        let presetValue = presetIsPersisted ? defaults.string(forKey: "windowPositionPreset") : nil

        if let presetValue,
           let preset = ClockWindowPosition(rawValue: presetValue) {
            applyWindowPosition(preset)
        } else if savedX >= 0 && savedY >= 0 {
            panel.setFrameOrigin(NSPoint(x: savedX, y: savedY))
            if !presetIsPersisted {
                defaults.set(ClockWindowPosition.customIdentifier, forKey: "windowPositionPreset")
            }
        } else {
            applyWindowPosition(.topCenter)
        }

        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.delegate = self

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
        if !isApplyingPositionPreset {
            defaults.set(ClockWindowPosition.customIdentifier, forKey: "windowPositionPreset")
            lastKnownWindowPresetValue = ClockWindowPosition.customIdentifier
        }
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

private final class ActivatingPanel: NSPanel {
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            NSApp.activate(ignoringOtherApps: true)
        default:
            break
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool {
        true
    }

    override var acceptsMouseMovedEvents: Bool {
        get { true }
        set { }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        // Trigger cursor update based on mouse position
        updateCursorForMouseLocation(event.locationInWindow)
    }

    private func updateCursorForMouseLocation(_ location: NSPoint) {
        let edgeThickness: CGFloat = 8.0

        // Get window bounds in window coordinates
        let windowBounds = NSRect(origin: .zero, size: frame.size)

        // Check if mouse is near edges
        let nearTop = location.y >= windowBounds.height - edgeThickness
        let nearBottom = location.y <= edgeThickness
        let nearLeft = location.x <= edgeThickness
        let nearRight = location.x >= windowBounds.width - edgeThickness

        // Set appropriate cursor based on position
        // Use the correct system cursors available in NSCursor
        if (nearTop && nearLeft) || (nearBottom && nearRight) {
            // Diagonal resize cursor (northwest-southeast)
            NSCursor.arrow.set() // Fallback - system will handle resize
        } else if (nearTop && nearRight) || (nearBottom && nearLeft) {
            // Diagonal resize cursor (northeast-southwest)
            NSCursor.arrow.set() // Fallback - system will handle resize
        } else if nearTop || nearBottom {
            NSCursor.resizeUpDown.set()
        } else if nearLeft || nearRight {
            NSCursor.resizeLeftRight.set()
        }
        // If not near edges, let the default cursor be used
    }
}
#endif
