// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  SettingsView.swift
//
//  Settings window for CoolClockPresence
//

#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @AppStorage("fontColorName") private var fontColorName: String = "green"
    @AppStorage("showBattery") private var showBattery: Bool = true
    @AppStorage("showSeconds") private var showSeconds: Bool = true
    @AppStorage("clockPresence.alwaysOnTop") private var isAlwaysOnTop: Bool = true
    @AppStorage("disappearOnHover") private var disappearOnHover: Bool = true
    @AppStorage("clockOpacity") private var clockOpacity: Double = 1.0
    @AppStorage("use24HourFormat") private var use24HourFormat: Bool = false

    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingPurchaseSheet = false
    private let settingsColumnWidth: CGFloat = 260

    var body: some View {
        TabView {
            // Appearance Tab
            Form {
                Section(header: Text("Font Color").font(.headline).frame(maxWidth: .infinity, alignment: .center)) {
                    VStack(alignment: .center, spacing: 4) {
                        // Free colors
                        colorButton(title: "White", colorName: "white")
                        colorButton(title: "Green", colorName: "green")

                        // Premium colors
                        if purchaseManager.isPremium {
                            Divider()
                            colorButton(title: "Black", colorName: "black")
                            colorButton(title: "Cyan", colorName: "cyan")
                            colorButton(title: "Red", colorName: "red")
                            colorButton(title: "Orange", colorName: "orange")
                            colorButton(title: "Yellow", colorName: "yellow")
                            colorButton(title: "Blue", colorName: "blue")
                            colorButton(title: "Purple", colorName: "purple")
                            colorButton(title: "Pink", colorName: "pink")
                            colorButton(title: "Mint", colorName: "mint")
                            colorButton(title: "Teal", colorName: "teal")
                            colorButton(title: "Indigo", colorName: "indigo")
                                .padding(.bottom, 12)
                        } else {
                            Divider()
                            Text("9 more colors available with Premium")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if purchaseManager.isPremium {
                    Section(header: Text("Transparency").font(.headline).frame(maxWidth: .infinity, alignment: .center)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Opacity")
                                Spacer()
                                Text("\(Int(clockOpacity * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $clockOpacity, in: 0.3...1.0, step: 0.05)
                        }
                    }
                } else {
                    Section(header: Text("Transparency").font(.headline).frame(maxWidth: .infinity, alignment: .center)) {
                        Button("Clock Opacity 🔒 Premium") {
                            showingPurchaseSheet = true
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .tabItem {
                Label("Appearance", systemImage: "paintbrush.fill")
            }

            // Settings Tab (Combined Display & Behavior)
            ScrollView {
                VStack {
                    Spacer(minLength: 24)

                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 16) {
                            if purchaseManager.isPremium {
                                Toggle("Show Seconds", isOn: $showSeconds)
                                Toggle("Use 24-Hour Format", isOn: $use24HourFormat)
                            } else {
                                Button("Show Seconds 🔒 Premium") {
                                    showingPurchaseSheet = true
                                }
                                Button("Use 24-Hour Format 🔒 Premium") {
                                    showingPurchaseSheet = true
                                }
                            }

                            if purchaseManager.isPremium {
                                Toggle("Show Battery", isOn: $showBattery)
                            } else {
                                Button("Show Battery 🔒 Premium") {
                                    showingPurchaseSheet = true
                                }
                            }

                            if purchaseManager.isPremium {
                                Toggle("Always on Top", isOn: $isAlwaysOnTop)
                                Toggle("Disappear on Hover", isOn: $disappearOnHover)
                            } else {
                                Button("Always on Top 🔒 Premium") {
                                    showingPurchaseSheet = true
                                }
                                Button("Disappear on Hover 🔒 Premium") {
                                    showingPurchaseSheet = true
                                }
                            }

                            Button("Show Onboarding Again") {
                                NotificationCenter.default.post(name: NSNotification.Name("ShowOnboardingAgain"), object: nil)
                                // Close settings window after triggering onboarding
                                NSApp.windows.first(where: { $0.title == "Settings" })?.close()
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(width: settingsColumnWidth, alignment: .leading)
                        Spacer()
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }

            // Premium Tab
            if !purchaseManager.isPremium {
                VStack(spacing: 20) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)

                    Text("Upgrade to Premium")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Unlock all colors, battery display, seconds, and more!")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Button("⭐️ Upgrade to Premium ($1.99)") {
                        showingPurchaseSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem {
                    Label("Premium", systemImage: "star.fill")
                }
            }
        }
        .frame(width: 500, height: 400)
        .sheet(isPresented: $showingPurchaseSheet) {
            PurchaseView()
        }
    }

    @ViewBuilder
    private func colorButton(title: String, colorName: String) -> some View {
        Button(action: {
            fontColorName = colorName
        }) {
            HStack {
                Spacer()
                Text(title)
                if fontColorName == colorName {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .padding(.leading, 4)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
