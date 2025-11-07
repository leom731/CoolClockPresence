// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  HelpView.swift
//
//  Help and instructions for CoolClockPresence
//

#if os(macOS)
import SwiftUI
import AppKit

struct HelpView: View {
    @Binding var isPresented: Bool
    @State private var selectedSection = 0

    private let helpSections: [HelpSection] = [
        HelpSection(
            icon: "questionmark.circle.fill",
            iconColor: .cyan,
            title: "Getting Started",
            items: [
                HelpItem(question: "How do I move the clock?", answer: "Click and drag anywhere on the clock window to move it around your screen."),
                HelpItem(question: "How do I resize the clock?", answer: "Click and drag from any corner or edge of the clock window to resize it."),
                HelpItem(question: "Where are the settings?", answer: "Click the clock icon in the menu bar, or right-click on the clock window to access settings.")
            ]
        ),
        HelpSection(
            icon: "paintbrush.fill",
            iconColor: .purple,
            title: "Customization",
            items: [
                HelpItem(question: "How do I change the clock color?", answer: "Click the menu bar icon and select 'Font Color' to choose from available colors. Free colors include White, Cyan, and Default. Premium unlocks 10+ additional colors."),
                HelpItem(question: "Can I show battery level?", answer: "Yes! The 'Show Battery' feature is available with Premium. It displays your current battery level and charging status on the clock."),
                HelpItem(question: "How do I keep the clock always on top?", answer: "Enable 'Always on Top' from the menu bar (Premium feature). This keeps the clock visible even when other windows are active.")
            ]
        ),
        HelpSection(
            icon: "gear",
            iconColor: .blue,
            title: "Features",
            items: [
                HelpItem(question: "What is 'Always on Top'?", answer: "This Premium feature keeps the clock visible above all other windows, even in full-screen apps."),
                HelpItem(question: "Does the clock remember my settings?", answer: "Yes! Your clock position, size, color, and all settings are automatically saved."),
                HelpItem(question: "Can I hide the clock temporarily?", answer: "Yes, click 'Show Clock Window' in the menu bar to toggle visibility, or use the standard window controls.")
            ]
        ),
        HelpSection(
            icon: "star.circle.fill",
            iconColor: .yellow,
            title: "Premium Features",
            items: [
                HelpItem(question: "What does Premium include?", answer: "Premium unlocks: Battery Monitor, 13+ font colors, Always on Top, Hover Transparency, and Position Memory."),
                HelpItem(question: "How much does Premium cost?", answer: "Premium is a one-time purchase of $1.99. No subscriptions!"),
                HelpItem(question: "How do I upgrade to Premium?", answer: "Click the menu bar icon and select 'Upgrade to Premium', or click the lock icon next to any premium feature.")
            ]
        ),
        HelpSection(
            icon: "keyboard",
            iconColor: .green,
            title: "Keyboard Shortcuts",
            items: [
                HelpItem(question: "What keyboard shortcuts are available?", answer: "• ⌘Q - Quit CoolClockPresence\n• ⌘? - Open this help window"),
                HelpItem(question: "Can I create custom shortcuts?", answer: "The app uses standard macOS menu shortcuts. You can customize these in System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts.")
            ]
        ),
        HelpSection(
            icon: "exclamationmark.triangle.fill",
            iconColor: .orange,
            title: "Troubleshooting",
            items: [
                HelpItem(question: "The clock disappeared, how do I get it back?", answer: "Click the clock icon in the menu bar and select 'Show Clock Window' to make it visible again. If it fades while you're hovering, hold the ⌘ key to keep it visible and interact with it."),
                HelpItem(question: "How do I reset my settings?", answer: "You can view the onboarding tutorial again from the menu bar by selecting 'Show Onboarding Again'."),
                HelpItem(question: "The clock doesn't stay on top in full-screen", answer: "Make sure 'Always on Top' is enabled (Premium feature). The clock should appear on all desktops and spaces.")
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Glass background
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)

            HStack(spacing: 0) {
                // Sidebar with sections
                VStack(alignment: .leading, spacing: 4) {
                    Text("Help Topics")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(0..<helpSections.count, id: \.self) { index in
                                HelpSectionButton(
                                    section: helpSections[index],
                                    isSelected: selectedSection == index,
                                    action: { selectedSection = index }
                                )
                            }
                        }
                    }

                    Spacer()

                    // Close button at bottom
                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(16)
                }
                .frame(width: 200)
                .background(Color.black.opacity(0.05))

                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Section header
                        HStack(spacing: 12) {
                            Image(systemName: helpSections[selectedSection].icon)
                                .font(.system(size: 32, weight: .thin))
                                .foregroundStyle(helpSections[selectedSection].iconColor)

                            Text(helpSections[selectedSection].title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .padding(.bottom, 8)

                        // Help items
                        ForEach(helpSections[selectedSection].items, id: \.question) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.question)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Text(item.answer)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 8)

                            if item.question != helpSections[selectedSection].items.last?.question {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Help Section Model

struct HelpSection {
    let icon: String
    let iconColor: Color
    let title: String
    let items: [HelpItem]
}

struct HelpItem {
    let question: String
    let answer: String
}

// MARK: - Help Section Button

struct HelpSectionButton: View {
    let section: HelpSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? section.iconColor : .secondary)
                    .frame(width: 20)

                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.cyan.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView(isPresented: .constant(true))
    }
}
#endif
