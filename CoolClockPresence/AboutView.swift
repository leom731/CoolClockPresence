// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  AboutView.swift
//
//  Custom About window with update + App Store affordances.
//

#if os(macOS)
import SwiftUI
import AppKit

struct AboutView: View {
    let version: String
    let buildNumber: String
    let onCheckForUpdates: () -> Void
    let onOpenAppStore: () -> Void

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("CoolClockPresence")
                            .font(.system(size: 22, weight: .bold, design: .rounded))

                        Text("Floating glass clock for macOS")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text("Version \(version) • Build \(buildNumber)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Keep the app fresh")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    Text("Jump straight to the Mac App Store updates tab to make sure you're on the latest build, or pop open the store listing to leave a review.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Button {
                        onCheckForUpdates()
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        onOpenAppStore()
                    } label: {
                        Label("View in App Store", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Spacer()

                Text("No tracking. No analytics. Just a beautiful clock that stays out of your way.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(width: 480, height: 340)
    }
}
#endif
