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
                    appDelegate.showAbout()
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
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem?
    private var lastKnownWindowPresetValue: String?
    private var isApplyingPositionPreset = false
    private var isAdjustingBlackOpacity = false
    private var isUpdatingGlassStyleInline = false
    private var isBuildingMenu = false
    private var adjustableOpacityUpdateWorkItem: DispatchWorkItem?
    private let checkmarkImage = NSImage(named: NSImage.menuOnStateTemplateName) ?? NSImage(size: NSSize(width: 12, height: 12))
    private var appStoreProductID: String? {
        // Prefer an Info.plist override so you can set this without code changes
        let rawID = (Bundle.main.object(forInfoDictionaryKey: "AppStoreProductID") as? String) ?? "0000000000"
        let trimmed = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reject placeholder or empty values
        if trimmed.isEmpty || trimmed == "0000000000" { return nil }
        return trimmed
    }
    private var appDisplayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
        "CoolClockPresence"
    }
    private var appStoreRegionCode: String {
        Locale.current.region?.identifier.lowercased() ?? "us"
    }
    private var appStoreProductURL: URL? {
        // Standard HTTPS link works even if the Mac App Store deep link is blocked by region
        guard let appStoreProductID else { return nil }
        return URL(string: "https://apps.apple.com/\(appStoreRegionCode)/app/id\(appStoreProductID)")
    }
    private var appStoreDeepLinkURL: URL? {
        // Deep link into the Mac App Store app
        guard let appStoreProductID else { return nil }
        return URL(string: "macappstore://itunes.apple.com/app/id\(appStoreProductID)?mt=12")
    }
    private var appStoreSearchURL: URL? {
        // Fallback search inside the Mac App Store if no product ID is set
        let encoded = appDisplayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "CoolClockPresence"
        return URL(string: "macappstore://itunes.apple.com/search?term=\(encoded)&entity=macSoftware")
    }
    private var appStoreSearchWebURL: URL? {
        let encoded = appDisplayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "CoolClockPresence"
        return URL(string: "https://apps.apple.com/search?term=\(encoded)&entity=macSoftware")
    }
    private lazy var emptyCheckmarkImage: NSImage = {
        let image = NSImage(size: checkmarkImage.size)
        image.lockFocus()
        NSColor.clear.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: checkmarkImage.size)).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon; control surface lives in the menu bar status item
        NSApp.setActivationPolicy(.accessory)

        // Set default preferences
        defaults.register(defaults: [
            "fontColorName": "green",
            "fontDesign": "rounded",
            "clockPresence.alwaysOnTop": true,
            "disappearOnHover": true,
            "windowX": -1.0,  // -1 means not set yet, will center on first launch
            "windowY": -1.0,
            "windowWidth": 280.0,
            "windowHeight": 100.0,
            "hasCompletedOnboarding": false,
            "glassStyle": "liquid",
            "adjustableBlackOpacity": 0.82,
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
            selector: #selector(handleDefaultsChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Rebuild menu when it's about to open, so we can check modifier flags
        updateMenuBarMenu()
    }

    @objc private func handleDefaultsChange() {
        if isAdjustingBlackOpacity || isUpdatingGlassStyleInline || isBuildingMenu { return }
        DispatchQueue.main.async { [weak self] in
            self?.updateMenuBarMenu()
        }
    }

    @objc private func updateMenuBarMenu() {
        let rebuild = { [weak self] in
            guard let self else { return }
            if self.isBuildingMenu { return }
            self.isBuildingMenu = true
            defer { self.isBuildingMenu = false }

            guard let menu = self.statusItem?.menu else { return }
            menu.removeAllItems()

            let isPremium = self.defaults.bool(forKey: "isPremiumUnlocked")

            // Show/Hide Clock Window
            let showClockItem = NSMenuItem(title: "Show Clock Window", action: #selector(self.toggleClockWindow), keyEquivalent: "")
            if let window = self.window {
                showClockItem.state = window.isVisible ? .on : .off
            }
            menu.addItem(showClockItem)
            menu.addItem(NSMenuItem.separator())

            // Font Color submenu
            let fontColorMenu = NSMenu()

            // Free colors
            fontColorMenu.addItem(self.createFontColorMenuItem(title: "White", colorName: "white"))
            fontColorMenu.addItem(self.createFontColorMenuItem(title: "Green", colorName: "green"))

            // Premium colors
            if isPremium {
                fontColorMenu.addItem(NSMenuItem.separator())
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Black", colorName: "black"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Cyan", colorName: "cyan"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Red", colorName: "red"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Orange", colorName: "orange"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Yellow", colorName: "yellow"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Blue", colorName: "blue"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Purple", colorName: "purple"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Pink", colorName: "pink"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Mint", colorName: "mint"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Teal", colorName: "teal"))
                fontColorMenu.addItem(self.createFontColorMenuItem(title: "Indigo", colorName: "indigo"))
            }

            let fontColorItem = NSMenuItem(title: "Font Color", action: nil, keyEquivalent: "")
            fontColorItem.submenu = fontColorMenu
            menu.addItem(fontColorItem)
            
            // Font Style submenu
            let fontStyleMenu = NSMenu()
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Rounded (Default)", fontName: "rounded"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Monospaced", fontName: "monospaced"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Serif", fontName: "serif"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Time Circuit (LED)", fontName: "led"))
            fontStyleMenu.addItem(NSMenuItem.separator())
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Ultra Light", fontName: "ultralight"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Thin", fontName: "thin"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Light", fontName: "light"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Medium", fontName: "medium"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Bold", fontName: "bold"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Heavy", fontName: "heavy"))
            fontStyleMenu.addItem(self.createFontStyleMenuItem(title: "Black", fontName: "black"))
            
            let fontStyleItem = NSMenuItem(title: "Font Style", action: nil, keyEquivalent: "")
            fontStyleItem.submenu = fontStyleMenu
            menu.addItem(fontStyleItem)
            menu.addItem(NSMenuItem.separator())

            // Glass Style submenu
            let glassStyleItem = NSMenuItem(title: "Glass Style", action: nil, keyEquivalent: "")
            glassStyleItem.submenu = self.makeGlassStyleMenu()
            menu.addItem(glassStyleItem)
            menu.addItem(NSMenuItem.separator())

            // Clock position submenu
            let positionMenu = NSMenu()
            let currentPreset = self.defaults.string(forKey: "windowPositionPreset") ?? ClockWindowPosition.topCenter.rawValue
            ClockWindowPosition.allCases.forEach { position in
                let item = NSMenuItem(title: position.displayName, action: #selector(self.snapWindowToPreset(_:)), keyEquivalent: "")
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
                let showSecondsItem = NSMenuItem(title: "Show Seconds", action: #selector(self.toggleSeconds), keyEquivalent: "")
                showSecondsItem.state = self.defaults.bool(forKey: "showSeconds") ? .on : .off
                menu.addItem(showSecondsItem)

                let use24HourItem = NSMenuItem(title: "Use 24-Hour Format", action: #selector(self.toggleUse24HourFormat), keyEquivalent: "")
                use24HourItem.state = self.defaults.bool(forKey: "use24HourFormat") ? .on : .off
                menu.addItem(use24HourItem)

                let showBatteryItem = NSMenuItem(title: "Show Battery", action: #selector(self.toggleBattery), keyEquivalent: "")
                showBatteryItem.state = self.defaults.bool(forKey: "showBattery") ? .on : .off
                menu.addItem(showBatteryItem)

                let alwaysOnTopItem = NSMenuItem(title: "Always on Top", action: #selector(self.toggleAlwaysOnTop), keyEquivalent: "")
                alwaysOnTopItem.state = self.defaults.bool(forKey: "clockPresence.alwaysOnTop") ? .on : .off
                menu.addItem(alwaysOnTopItem)

                let disappearOnHoverItem = NSMenuItem(title: "Disappear on Hover", action: #selector(self.toggleDisappearOnHover), keyEquivalent: "")
                disappearOnHoverItem.state = self.defaults.bool(forKey: "disappearOnHover") ? .on : .off
                menu.addItem(disappearOnHoverItem)
            } else {
                menu.addItem(NSMenuItem(title: "Show Seconds 🔒 Premium", action: #selector(self.showPurchaseView), keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Use 24-Hour Format 🔒 Premium", action: #selector(self.showPurchaseView), keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Show Battery 🔒 Premium", action: #selector(self.showPurchaseView), keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Always on Top 🔒 Premium", action: #selector(self.showPurchaseView), keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "Disappear on Hover 🔒 Premium", action: #selector(self.showPurchaseView), keyEquivalent: ""))
            }

            menu.addItem(NSMenuItem.separator())

            // Upgrade option
            if !isPremium {
                menu.addItem(NSMenuItem(title: "⭐️ Upgrade to Premium ($1.99)", action: #selector(self.showPurchaseView), keyEquivalent: ""))
                menu.addItem(NSMenuItem.separator())
            }

            let settingsItem = NSMenuItem(title: "Settings…", action: #selector(self.openSettingsWindow), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)

            // About and other options
            menu.addItem(NSMenuItem(title: "About CoolClockPresence", action: #selector(self.showAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Help", action: #selector(self.showHelpWindow), keyEquivalent: "?"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Show Onboarding Again", action: #selector(self.showOnboardingAgain), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit CoolClockPresence", action: #selector(self.quitApp), keyEquivalent: "q"))

            // Ensure every actionable item routes to this delegate, including submenu items.
            self.assignMenuTargets(menu)
        }

        if Thread.isMainThread {
            rebuild()
        } else {
            DispatchQueue.main.async(execute: rebuild)
        }
    }

    /// Recursively sets the AppDelegate as the target for any menu item that defines an action but no explicit target.
    private func assignMenuTargets(_ menu: NSMenu) {
        for item in menu.items {
            if item.action != nil && item.target == nil {
                item.target = self
            }
            if let submenu = item.submenu {
                assignMenuTargets(submenu)
            }
        }
    }

    private func createFontColorMenuItem(title: String, colorName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(changeFontColor(_:)), keyEquivalent: "")
        item.representedObject = colorName
        item.onStateImage = checkmarkImage
        item.offStateImage = emptyCheckmarkImage
        item.mixedStateImage = emptyCheckmarkImage

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

    private func createFontStyleMenuItem(title: String, fontName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(changeFontStyle(_:)), keyEquivalent: "")
        item.representedObject = fontName

        // Add checkmark if this is the current font
        let currentFont = defaults.string(forKey: "fontDesign") ?? "rounded"
        if currentFont == fontName {
            item.state = .on
        }

        return item
    }

    @objc private func changeFontStyle(_ sender: NSMenuItem) {
        if let fontName = sender.representedObject as? String {
            defaults.set(fontName, forKey: "fontDesign")
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

    private func adjustableGlassStyleSelectionItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.representedObject = "adjustableBlack"

        return glassStyleSelectionItem(title: "Adjustable Black Glass", styleName: "adjustableBlack", action: #selector(handleAdjustableGlassSelection(_:)))
    }

    @objc private func changeGlassStyle(_ sender: NSMenuItem) {
        guard let styleName = sender.representedObject as? String else { return }
        updateGlassStyleInline(to: styleName, menu: sender.menu)
    }

    @objc private func handleGlassSelectionButton(_ sender: NSButton) {
        let styleName = sender.identifier?.rawValue ?? sender.title
        updateGlassStyleInline(to: styleName, menu: sender.enclosingMenuItem?.menu)
    }

    @objc private func handleAdjustableGlassSelection(_ sender: NSButton) {
        updateGlassStyleInline(to: "adjustableBlack", menu: sender.enclosingMenuItem?.menu)
    }

    private func refreshGlassStyleMenuUI(_ menu: NSMenu?, currentStyleOverride: String? = nil) {
        guard let menu else { return }
        let currentStyle = currentStyleOverride ?? (defaults.string(forKey: "glassStyle") ?? "liquid")

        for item in menu.items {
            if let button = item.view?.subviews.compactMap({ $0 as? NSButton }).first {
                let styleName = button.identifier?.rawValue ?? item.representedObject as? String ?? button.title
                button.state = styleName == currentStyle ? .on : .off
            } else if let styleName = item.representedObject as? String {
                item.state = currentStyle == styleName ? .on : .off
            }

            if let container = item.view as? NSStackView {
                let enabled = currentStyle == "adjustableBlack"
                if let header = container.arrangedSubviews.first as? NSStackView,
                   let titleLabel = header.arrangedSubviews.first as? NSTextField,
                   let valueLabel = header.arrangedSubviews.last as? NSTextField {
                    titleLabel.textColor = enabled ? NSColor.labelColor : NSColor.secondaryLabelColor
                    valueLabel.textColor = enabled ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
                }

                container.arrangedSubviews
                    .compactMap { $0 as? NSSlider }
                    .forEach { $0.isEnabled = enabled }
            }
        }
    }

    /// Applies a glass style change while keeping the Glass Style menu open and refreshed.
    private func updateGlassStyleInline(to styleName: String, menu: NSMenu?) {
        isUpdatingGlassStyleInline = true
        defaults.set(styleName, forKey: "glassStyle")
        refreshGlassStyleMenuUI(menu, currentStyleOverride: styleName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.isUpdatingGlassStyleInline = false
        }
    }

    /// Creates a view-based menu item for glass style that does not dismiss the menu when clicked.
    private func glassStyleSelectionItem(title: String, styleName: String, action: Selector? = #selector(handleGlassSelectionButton(_:))) -> NSMenuItem {
        let item = NSMenuItem()
        item.representedObject = styleName

        let button = NSButton(title: title, target: self, action: action)
        button.setButtonType(.radio)
        button.state = (defaults.string(forKey: "glassStyle") ?? "liquid") == styleName ? .on : .off
        button.identifier = NSUserInterfaceItemIdentifier(styleName)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        button.bezelStyle = .shadowlessSquare
        button.isBordered = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
        ])

        item.view = container
        return item
    }

    private func adjustableBlackOpacityMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.isEnabled = true
        let currentStyle = defaults.string(forKey: "glassStyle") ?? "liquid"
        let isAdjustableSelected = currentStyle == "adjustableBlack"

        let container = NSStackView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.orientation = .vertical
        container.spacing = 6
        container.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 8, right: 12)
        container.widthAnchor.constraint(equalToConstant: 220).isActive = true
        container.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fillProportionally

        let titleLabel = NSTextField(labelWithString: "Black Glass Opacity")
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = isAdjustableSelected ? NSColor.labelColor : NSColor.secondaryLabelColor

        let value = defaults.double(forKey: "adjustableBlackOpacity")
        let valueLabel = NSTextField(labelWithString: "\(Int(value * 100))%")
        valueLabel.font = NSFont.systemFont(ofSize: 11)
        valueLabel.textColor = isAdjustableSelected ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
        valueLabel.alignment = .right

        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(valueLabel)

        let slider = NSSlider(value: value, minValue: 0.4, maxValue: 1.0, target: self, action: #selector(changeAdjustableBlackOpacity(_:)))
        slider.isContinuous = true
        slider.numberOfTickMarks = 0
        slider.controlSize = .small
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        slider.isEnabled = isAdjustableSelected

        container.addArrangedSubview(header)
        container.addArrangedSubview(slider)

        item.view = container
        return item
    }

    @objc private func changeAdjustableBlackOpacity(_ sender: NSSlider) {
        isAdjustingBlackOpacity = true
        adjustableOpacityUpdateWorkItem?.cancel()

        let clampedValue = max(0.4, min(1.0, sender.doubleValue))
        defaults.set(clampedValue, forKey: "adjustableBlackOpacity")
        sender.doubleValue = clampedValue

        if let container = sender.superview as? NSStackView,
           let header = container.arrangedSubviews.first as? NSStackView,
           let valueLabel = header.arrangedSubviews.last as? NSTextField {
            valueLabel.stringValue = "\(Int(clampedValue * 100))%"
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isAdjustingBlackOpacity = false
        }
        adjustableOpacityUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    /// Shared Glass Style submenu used by both the status item menu and the clock context menu.
    func makeGlassStyleMenu() -> NSMenu {
        let glassStyleMenu = NSMenu()
        glassStyleMenu.autoenablesItems = false
        glassStyleMenu.addItem(glassStyleSelectionItem(title: "Liquid Glass", styleName: "liquid"))
        glassStyleMenu.addItem(glassStyleSelectionItem(title: "Clear Glass", styleName: "clear"))
        glassStyleMenu.addItem(glassStyleSelectionItem(title: "Black Glass", styleName: "black"))
        glassStyleMenu.addItem(adjustableGlassStyleSelectionItem())
        glassStyleMenu.addItem(NSMenuItem.separator())
        glassStyleMenu.addItem(adjustableBlackOpacityMenuItem())
        return glassStyleMenu
    }

    /// Presents the Glass Style submenu at the current mouse location (used for the clock's context menu).
    @objc func showGlassStyleMenuFromContextMenu() {
        popGlassStyleMenu(at: NSEvent.mouseLocation)
    }

    private func popGlassStyleMenu(at location: NSPoint) {
        let menu = makeGlassStyleMenu()
        assignMenuTargets(menu)
        menu.popUp(positioning: nil, at: location, in: nil)
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

    @objc func toggleClockWindow() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        updateMenuBarMenu()
    }

    @objc func showAbout() {
        if let aboutWindow {
            aboutWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "About CoolClockPresence"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("AboutWindow")

        let aboutView = AboutView(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            onCheckForUpdates: { [weak self] in
                self?.openUpdatesPage()
            },
            onOpenAppStore: { [weak self] in
                self?.openAppStorePage()
            }
        )

        window.contentView = NSHostingView(rootView: aboutView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: nil
        ) { [weak self] _ in
            self?.aboutWindow = nil
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func openUpdatesPage() {
        guard let updatesURL = URL(string: "macappstore://showUpdatesPage") else { return }
        NSWorkspace.shared.open(updatesURL)
    }

    private func openAppStorePage() {
        // Try product deep link first (opens the App Store app)
        if let appStoreDeepLinkURL, NSWorkspace.shared.open(appStoreDeepLinkURL) {
            return
        }

        // Fallback to the HTTPS listing (opens in Safari and routes to App Store)
        if let appStoreProductURL, NSWorkspace.shared.open(appStoreProductURL) {
            return
        }

        // If no product ID is set, fall back to a search for the app name
        if let appStoreSearchURL, NSWorkspace.shared.open(appStoreSearchURL) {
            return
        }

        if let appStoreSearchWebURL {
            NSWorkspace.shared.open(appStoreSearchWebURL)
        }
    }

    @objc func openSettingsWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SettingsWindow")
        window.contentView = NSHostingView(rootView: SettingsView())

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: nil
        ) { [weak self] _ in
            self?.settingsWindow = nil
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc func showHelpWindow() {
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
        // Keep app hidden from Dock/Cmd-Tab during onboarding
        NSApp.setActivationPolicy(.accessory)

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
        panel.isMovableByWindowBackground = false  // Disable to allow edge resizing - custom drag handling in ActivatingPanel
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

        // Keep app hidden from Dock/Cmd-Tab
        NSApp.setActivationPolicy(.accessory)

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

    @objc func showOnboardingAgain() {
        // If onboarding window already exists, just bring it to front
        if let existingWindow = onboardingWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Keep app hidden from Dock/Cmd-Tab
        NSApp.setActivationPolicy(.accessory)

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
                    // Keep app hidden from Dock/Cmd-Tab after onboarding
                    NSApp.setActivationPolicy(.accessory)
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
    private enum ResizeRegion {
        case none, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight
    }

    private let resizeHitThickness: CGFloat = 14.0
    private var dragStartLocation: NSPoint?
    private var windowOriginAtDragStart: NSPoint?
    private var resizeStartLocation: NSPoint?
    private var resizeStartFrame: NSRect?
    private var activeResizeRegion: ResizeRegion = .none
    
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
        updateCursor(for: resizeRegion(for: event.locationInWindow))
    }
    
    override func mouseDown(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        
        let region = resizeRegion(for: locationInWindow)
        if region != .none {
            // Begin a custom resize so the hit area is larger than the default system border
            activeResizeRegion = region
            resizeStartLocation = NSEvent.mouseLocation
            resizeStartFrame = frame
            return
        }
        
        // Otherwise, prepare for manual dragging from center
        dragStartLocation = event.locationInWindow
        windowOriginAtDragStart = self.frame.origin
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let dragStartLocation = dragStartLocation,
              let windowOriginAtDragStart = windowOriginAtDragStart else {
            if activeResizeRegion != .none,
               let resizeStartLocation,
               let resizeStartFrame {
                let currentMouseLocation = NSEvent.mouseLocation
                let dx = currentMouseLocation.x - resizeStartLocation.x
                let dy = currentMouseLocation.y - resizeStartLocation.y

                let newFrame = resizedFrame(
                    from: resizeStartFrame,
                    region: activeResizeRegion,
                    dx: dx,
                    dy: dy
                )

                setFrame(newFrame, display: true)
                return
            }
            // No drag start recorded, let system handle
            super.mouseDragged(with: event)
            return
        }
        
        // Only handle dragging if we started in the center area
        let currentMouseLocation = NSEvent.mouseLocation
        
        // Calculate offset from initial click
        let dx = currentMouseLocation.x - (windowOriginAtDragStart.x + dragStartLocation.x)
        let dy = currentMouseLocation.y - (windowOriginAtDragStart.y + dragStartLocation.y)
        
        // Move window
        let newOrigin = NSPoint(
            x: windowOriginAtDragStart.x + dx,
            y: windowOriginAtDragStart.y + dy
        )
        self.setFrameOrigin(newOrigin)
    }
    
    override func mouseUp(with event: NSEvent) {
        dragStartLocation = nil
        windowOriginAtDragStart = nil
        resizeStartFrame = nil
        resizeStartLocation = nil
        activeResizeRegion = .none
        super.mouseUp(with: event)
    }
    
    private func resizeRegion(for location: NSPoint) -> ResizeRegion {
        let windowBounds = NSRect(origin: .zero, size: frame.size)

        let nearTop = location.y >= windowBounds.height - resizeHitThickness
        let nearBottom = location.y <= resizeHitThickness
        let nearLeft = location.x <= resizeHitThickness
        let nearRight = location.x >= windowBounds.width - resizeHitThickness

        if nearTop && nearLeft { return .topLeft }
        if nearTop && nearRight { return .topRight }
        if nearBottom && nearLeft { return .bottomLeft }
        if nearBottom && nearRight { return .bottomRight }
        if nearTop { return .top }
        if nearBottom { return .bottom }
        if nearLeft { return .left }
        if nearRight { return .right }
        return .none
    }

    private func resizedFrame(from frame: NSRect, region: ResizeRegion, dx: CGFloat, dy: CGFloat) -> NSRect {
        let minFrameSize = effectiveMinFrameSize()
        let maxFrameSize = effectiveMaxFrameSize()

        func clampWidth(_ width: CGFloat) -> CGFloat {
            let minWidth = max(minFrameSize.width, 1)
            let maxWidth = maxFrameSize.width > 0 ? maxFrameSize.width : CGFloat.greatestFiniteMagnitude
            return min(max(width, minWidth), maxWidth)
        }

        func clampHeight(_ height: CGFloat) -> CGFloat {
            let minHeight = max(minFrameSize.height, 1)
            let maxHeight = maxFrameSize.height > 0 ? maxFrameSize.height : CGFloat.greatestFiniteMagnitude
            return min(max(height, minHeight), maxHeight)
        }

        let rightEdge = frame.maxX
        let topEdge = frame.maxY
        var newFrame = frame

        switch region {
        case .right:
            newFrame.size.width = clampWidth(frame.size.width + dx)
        case .left:
            let newWidth = clampWidth(frame.size.width - dx)
            newFrame.size.width = newWidth
            newFrame.origin.x = rightEdge - newWidth
        case .top:
            newFrame.size.height = clampHeight(frame.size.height + dy)
        case .bottom:
            let newHeight = clampHeight(frame.size.height - dy)
            newFrame.size.height = newHeight
            newFrame.origin.y = topEdge - newHeight
        case .topLeft:
            let newWidth = clampWidth(frame.size.width - dx)
            let newHeight = clampHeight(frame.size.height + dy)
            newFrame.size.width = newWidth
            newFrame.origin.x = rightEdge - newWidth
            newFrame.size.height = newHeight
        case .topRight:
            newFrame.size.width = clampWidth(frame.size.width + dx)
            newFrame.size.height = clampHeight(frame.size.height + dy)
        case .bottomLeft:
            let newWidth = clampWidth(frame.size.width - dx)
            let newHeight = clampHeight(frame.size.height - dy)
            newFrame.size.width = newWidth
            newFrame.origin.x = rightEdge - newWidth
            newFrame.size.height = newHeight
            newFrame.origin.y = topEdge - newHeight
        case .bottomRight:
            newFrame.size.width = clampWidth(frame.size.width + dx)
            let newHeight = clampHeight(frame.size.height - dy)
            newFrame.size.height = newHeight
            newFrame.origin.y = topEdge - newHeight
        case .none:
            break
        }

        return newFrame
    }

    private func effectiveMinFrameSize() -> CGSize {
        let contentMin = contentMinSize
        if contentMin != .zero {
            return frameRect(forContentRect: NSRect(origin: .zero, size: contentMin)).size
        }
        return minSize == .zero ? frame.size : minSize
    }

    private func effectiveMaxFrameSize() -> CGSize {
        let contentMax = contentMaxSize
        if contentMax != .zero {
            return frameRect(forContentRect: NSRect(origin: .zero, size: contentMax)).size
        }
        return maxSize == .zero ? CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude) : maxSize
    }

    private func updateCursor(for region: ResizeRegion) {
        switch region {
        case .topLeft:
            if let cursor = NSCursor.perform(NSSelectorFromString("_windowResizeNorthWestCursor"))?.takeUnretainedValue() as? NSCursor {
                cursor.set()
            } else {
                NSCursor.arrow.set()
            }
        case .topRight:
            if let cursor = NSCursor.perform(NSSelectorFromString("_windowResizeNorthEastCursor"))?.takeUnretainedValue() as? NSCursor {
                cursor.set()
            } else {
                NSCursor.arrow.set()
            }
        case .bottomLeft:
            if let cursor = NSCursor.perform(NSSelectorFromString("_windowResizeSouthWestCursor"))?.takeUnretainedValue() as? NSCursor {
                cursor.set()
            } else {
                NSCursor.arrow.set()
            }
        case .bottomRight:
            if let cursor = NSCursor.perform(NSSelectorFromString("_windowResizeSouthEastCursor"))?.takeUnretainedValue() as? NSCursor {
                cursor.set()
            } else {
                NSCursor.arrow.set()
            }
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .none:
            NSCursor.arrow.set()
        }
    }
}
#endif
