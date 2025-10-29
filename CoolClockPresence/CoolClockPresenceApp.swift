//
//  CoolClockPresenceApp.swift
//  CoolClockPresence
//
//  macOS entry point that presents the floating glass clock.
//

#if os(macOS)
import SwiftUI

@main
struct CoolClockPresenceApp: App {
    @AppStorage("clockPresence.alwaysOnTop") private var isAlwaysOnTop = true

    var body: some Scene {
        WindowGroup {
            ClockPresenceView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.clear)
        }
        .defaultSize(width: 260, height: 150)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("View") {
                Toggle("Always on Top", isOn: $isAlwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}
#endif
