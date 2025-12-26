// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  SharedClockComponents.swift
//
//  Shared UI components for clock views
//

#if os(macOS)
import SwiftUI

// MARK: - Blinking Colon Helper

/// Battery-efficient blinking colon that uses GPU animation instead of timeline updates
struct BlinkingColon: View {
    let text: String
    let font: Font
    let fillColor: Color
    let strokeColor: Color
    let lineWidth: CGFloat
    let shouldBlink: Bool
    let isOutlined: Bool

    @State private var isVisible: Bool = true

    var body: some View {
        // Render the text with constant colors to prevent position shifts
        // Apply opacity to the entire view instead of to individual color components
        Group {
            if isOutlined {
                OutlinedText(
                    text: text,
                    font: font,
                    fillColor: fillColor.opacity(0.92),
                    strokeColor: strokeColor,
                    lineWidth: lineWidth
                )
            } else {
                Text(text)
                    .font(font)
                    .monospacedDigit()
                    .foregroundStyle(fillColor.opacity(0.92))
            }
        }
        // Apply opacity animation to the entire rendered view
        // This keeps the text rendering identical, preventing alignment shifts
        .opacity(shouldBlink ? (isVisible ? 1.0 : 0.27) : 1.0)
        .onAppear {
            if shouldBlink {
                // GPU-based animation that repeats without requiring view updates
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
        }
        .onChange(of: shouldBlink) { _, newValue in
            // Reset to visible when seconds are shown (shouldBlink becomes false)
            if !newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = true
                }
            } else {
                // Start blinking animation when seconds are hidden
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - Outlined Text Helper

struct OutlinedText: View {
    let text: String
    let font: Font
    let fillColor: Color
    let strokeColor: Color
    let lineWidth: CGFloat

    var body: some View {
        // Battery optimization: Use shadows instead of 9 text copies for much better performance
        // This reduces GPU/CPU load significantly while maintaining visual quality
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(fillColor)
            .shadow(color: strokeColor, radius: lineWidth * 0.4, x: 0, y: 0)
            .shadow(color: strokeColor, radius: lineWidth * 0.4, x: 0, y: 0)
            .shadow(color: strokeColor, radius: lineWidth * 0.3, x: lineWidth * 0.3, y: lineWidth * 0.3)
            .shadow(color: strokeColor, radius: lineWidth * 0.3, x: -lineWidth * 0.3, y: -lineWidth * 0.3)
    }
}

// MARK: - Glass Backdrop

struct GlassBackdrop: View {
    let style: String
    let adjustableOpacity: Double

    private var clampedAdjustableOpacity: Double {
        min(max(adjustableOpacity, 0.4), 1.0)
    }

    var body: some View {
        if style == "liquid" {
            liquidGlassStyle
        } else if style == "adjustableBlack" {
            adjustableBlackGlassStyle
        } else if style == "black" {
            blackGlassStyle
        } else {
            clearGlassStyle
        }
    }

    // New Liquid Glass effect - more vibrant and visible with blur transparency
    private var liquidGlassStyle: some View {
        ZStack {
            // Base material layer with blur and transparency
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.5)

            // Vibrant gradient overlay - slightly more opaque for visibility
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.cyan.opacity(0.12),
                        Color.purple.opacity(0.10),
                        Color.blue.opacity(0.12),
                        Color.pink.opacity(0.08)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .blur(radius: 12)  // Battery optimization: Reduced from 20 to 12 for better performance

            // Shimmer highlight layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.15),
                        Color.clear
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )

            // Inner glow for depth
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(colors: [
                        Color.white.opacity(0.1),
                        Color.clear
                    ], center: .topLeading, startRadius: 0, endRadius: 300)
                )
                .padding(2)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 25, x: 0, y: 12)
        .shadow(color: Color.cyan.opacity(0.08), radius: 15, x: 0, y: 5)
    }

    // Original Clear Glass style
    private var clearGlassStyle: some View {
        ZStack {
            // Outer border layer for smooth edge - made nearly transparent
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(0.02),
                        Color.white.opacity(0.01)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(0.5)

            // Inner glass layer - made very transparent
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.05))
                .padding(1.5)

            // Background gradient layer - made very subtle
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.cyan.opacity(0.02),
                        Color.purple.opacity(0.03),
                        Color.blue.opacity(0.02)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .blur(radius: 15)  // Battery optimization: Reduced from 30 to 15 for better performance
                .opacity(0.1)
                .padding(1.5)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
    }

    // Black Glass style - all black background
    private var blackGlassStyle: some View {
        ZStack {
            // Solid black base layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.95))

            // Subtle edge highlight for definition
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05),
                        Color.clear
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )

            // Very subtle inner glow for depth
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(colors: [
                        Color.white.opacity(0.03),
                        Color.clear
                    ], center: .topLeading, startRadius: 0, endRadius: 300)
                )
                .padding(2)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
    }

    // Adjustable Black Glass - user controlled transparency to tune visibility
    private var adjustableBlackGlassStyle: some View {
        let baseOpacity = clampedAdjustableOpacity
        let edgeHighlight = 0.12 + (1.0 - baseOpacity) * 0.2
        let overlayOpacity = 0.14 + (1.0 - baseOpacity) * 0.2
        let innerGlowOpacity = 0.03 + (1.0 - baseOpacity) * 0.07

        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.black.opacity(baseOpacity),
                        Color.black.opacity(max(0.35, baseOpacity * 0.8))
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            // Edge highlight adapts with opacity so definition remains clear
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [
                        Color.white.opacity(edgeHighlight),
                        Color.white.opacity(edgeHighlight * 0.5),
                        Color.clear
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.25
                )

            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(overlayOpacity),
                        Color.white.opacity(overlayOpacity * 0.25)
                    ], startPoint: .top, endPoint: .bottom)
                )
                .opacity(0.2)
                .blur(radius: 12)
                .padding(1)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(colors: [
                        Color.white.opacity(innerGlowOpacity),
                        Color.clear
                    ], center: .topLeading, startRadius: 0, endRadius: 280)
                )
                .padding(2)
        }
        .shadow(color: Color.black.opacity(0.3 + baseOpacity * 0.15), radius: 24, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.18 + baseOpacity * 0.08), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Background Photo View

/// Displays a photo as a background for clock windows
struct BackgroundPhotoView: View {
    let photoID: UUID?
    let opacity: Double
    let aspectMode: String

    @StateObject private var photoManager = PhotoWindowManager.shared

    var body: some View {
        if let photoID = photoID,
           let photo = photoManager.savedPhotos.first(where: { $0.id == photoID }),
           let image = photoManager.image(for: photo) {

            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .opacity(opacity)
        }
    }

    private var contentMode: ContentMode {
        switch aspectMode {
        case "fit": return .fit
        default: return .fill
        }
    }
}

// MARK: - Resize Edge Indicators

/// Visual indicators that appear near window edges to show where you can resize
struct ResizeEdgeIndicators: View {
    let size: CGSize
    let mouseLocation: CGPoint

    // Increased from 8 to 20 to match the window's edge detection
    private let edgeThickness: CGFloat = 20.0

    private var isNearTop: Bool {
        mouseLocation.y >= size.height - edgeThickness
    }

    private var isNearBottom: Bool {
        mouseLocation.y <= edgeThickness
    }

    private var isNearLeft: Bool {
        mouseLocation.x <= edgeThickness
    }

    private var isNearRight: Bool {
        mouseLocation.x >= size.width - edgeThickness
    }

    var body: some View {
        ZStack {
            // Top edge indicator
            if isNearTop {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: edgeThickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            // Bottom edge indicator
            if isNearBottom {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: edgeThickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            // Left edge indicator
            if isNearLeft {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: edgeThickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            // Right edge indicator
            if isNearRight {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: edgeThickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }

            // Corner indicators (only show when near corners)
            if isNearTop && isNearLeft {
                cornerIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if isNearTop && isNearRight {
                cornerIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            if isNearBottom && isNearLeft {
                cornerIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            if isNearBottom && isNearRight {
                cornerIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isNearTop)
        .animation(.easeInOut(duration: 0.15), value: isNearBottom)
        .animation(.easeInOut(duration: 0.15), value: isNearLeft)
        .animation(.easeInOut(duration: 0.15), value: isNearRight)
    }

    private var cornerIndicator: some View {
        Circle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 8, height: 8)
            .padding(6)
    }
}
#endif
