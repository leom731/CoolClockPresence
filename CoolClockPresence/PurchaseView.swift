// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  PurchaseView.swift
//
//  Premium upgrade view with StoreKit integration
//

#if os(macOS)
import SwiftUI
import StoreKit

struct PurchaseView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 32)

                Text("Upgrade to Premium")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Unlock all features for just $1.99")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "battery.100percent.bolt", color: .green, title: "Battery Monitor", description: "Track level and charging status")
                FeatureRow(icon: "timer", color: .cyan, title: "Advanced Time Controls", description: "Show seconds or switch to 24-hour format")
                FeatureRow(icon: "paintpalette.fill", color: .pink, title: "All Font Colors", description: "Unlock 13 vibrant styles")
                FeatureRow(icon: "slider.horizontal.3", color: .purple, title: "Clock Opacity", description: "Dial in the perfect transparency")
                FeatureRow(icon: "pin.fill", color: .blue, title: "Always on Top", description: "Keep the clock above every window")
                FeatureRow(icon: "eye.slash.fill", color: .indigo, title: "Hover Transparency", description: "Auto-fade on hover for a clear view")
                FeatureRow(icon: "memorychip.fill", color: .orange, title: "Position Memory", description: "Remember window location and size")
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)

            Spacer()

            // Error message
            if let error = purchaseError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }

            // Success message
            if showingSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Premium Unlocked! Enjoy!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            }

            // Purchase button
            if purchaseManager.isPremium {
                Button("Already Premium - Close") {
                    dismiss()
                }
                .buttonStyle(PrimaryPurchaseButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            } else {
                Button(action: {
                    Task {
                        await purchase()
                    }
                }) {
                    if isPurchasing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                            Text("Processing...")
                        }
                    } else if let product = purchaseManager.products.first {
                        Text("Purchase Premium - \(product.displayPrice)")
                    } else {
                        Text("Purchase Premium - $1.99")
                    }
                }
                .buttonStyle(PrimaryPurchaseButtonStyle())
                .disabled(isPurchasing)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

                Button("Restore Purchases") {
                    Task {
                        await restorePurchases()
                    }
                }
                .buttonStyle(SecondaryPurchaseButtonStyle())
                .disabled(isPurchasing)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }

            // Close button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(TertiaryPurchaseButtonStyle())
            .keyboardShortcut(.cancelAction)
            .padding(.bottom, 24)
        }
        .frame(width: 500, height: 600)
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))
    }

    private func purchase() async {
        isPurchasing = true
        purchaseError = nil

        do {
            if let _ = try await purchaseManager.purchase() {
                showingSuccess = true
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }

        isPurchasing = false
    }

    private func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil

        await purchaseManager.restorePurchases()

        if purchaseManager.isPremium {
            showingSuccess = true
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else {
            purchaseError = "No previous purchases found"
        }

        isPurchasing = false
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Button Styles

struct PrimaryPurchaseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryPurchaseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.2))
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TertiaryPurchaseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.secondary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Preview

struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView()
    }
}
#endif
