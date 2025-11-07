// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  OnboardingView.swift
//
//  First-launch onboarding experience for CoolClockPresence
//

#if os(macOS)
import SwiftUI
import AppKit

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "clock.fill",
            iconColor: .cyan,
            title: "Welcome to CoolClockPresence",
            description: "A beautiful floating glass clock that stays on your screen",
            features: [],
            isPremiumPage: false
        ),
        OnboardingPage(
            icon: "hand.tap.fill",
            iconColor: .purple,
            title: "Easy to Use",
            description: "Control your clock with simple gestures",
            features: [
                "Drag anywhere to move",
                "Resize from corners/edges",
                "Access settings from menu bar or right-click",
                "Hold ⌘ while hovering to keep the clock visible"
            ],
            isPremiumPage: false
        ),
        OnboardingPage(
            icon: "star.circle.fill",
            iconColor: .yellow,
            title: "Upgrade to Premium",
            description: "Unlock powerful features for just $1.99",
            features: [
                "Battery Monitor - Track level and charging status",
                "Advanced Time Controls - Show seconds or use 24-hour format",
                "All Font Colors - Unlock 13 vibrant styles",
                "Clock Opacity - Fine tune transparency",
                "Always on Top - Keep clock over all windows",
                "Hover Transparency - Auto-fade for clear view",
                "Position Memory - Remember window location and size"
            ],
            isPremiumPage: true
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "You're All Set!",
            description: "Your clock is ready to use. Enjoy!",
            features: [
                "Press ⌘Q to quit anytime",
                "The clock appears on all desktops",
                "Access all settings from menu bar or right-click"
            ],
            isPremiumPage: false
        )
    ]

    var body: some View {
        ZStack {
            // Glass background
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                // Content area
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.automatic)
                .frame(maxWidth: .infinity)

                // Navigation buttons
                HStack(spacing: 16) {
                    // Skip button (only show on first pages)
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Spacer()

                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.cyan : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }

                    Spacer()

                    // Next/Get Started button
                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .frame(height: 60)
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .background(Color.black.opacity(0.1))
            }
            .padding(.bottom, 8)
        }
        .frame(width: 600, height: 480)
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let features: [String]
    let isPremiumPage: Bool
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var showingPurchaseView = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 20)

                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.iconColor, page.iconColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 4)

                // Title
                Text(page.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Description
                Text(page.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)

                // Features list
                if !page.features.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(page.features, id: \.self) { feature in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: page.isPremiumPage ? "star.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(page.iconColor)

                                Text(feature)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 80)
                    .padding(.top, 8)
                }

                // Premium button
                if page.isPremiumPage {
                    Button("View Premium Features") {
                        showingPurchaseView = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 12)
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingPurchaseView) {
            PurchaseView()
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.2))
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
    }
}
#endif
