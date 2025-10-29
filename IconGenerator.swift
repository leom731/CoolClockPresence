//
//  IconGenerator.swift
//  CoolClockPresence
//
//  A SwiftUI view to generate the app icon
//  Run this in Xcode Previews and screenshot at 1024x1024
//

import SwiftUI

/// Generates the "Floating Glass Time Sphere" app icon
struct AppIconGenerator: View {
    var body: some View {
        ZStack {
            // Background - subtle gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.15, blue: 0.25),
                    Color(red: 0.15, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.4),
                            Color.purple.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 180,
                        endRadius: 400
                    )
                )
                .blur(radius: 60)

            // Glass sphere - multiple layers for depth
            ZStack {
                // Back shadow layer
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 280
                        )
                    )
                    .blur(radius: 20)
                    .offset(y: 30)

                // Main glass sphere
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.cyan.opacity(0.12),
                                Color.purple.opacity(0.12),
                                Color.blue.opacity(0.08)
                            ],
                            center: UnitPoint(x: 0.4, y: 0.35),
                            startRadius: 50,
                            endRadius: 350
                        )
                    )
                    .frame(width: 600, height: 600)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.cyan.opacity(0.3),
                                        Color.purple.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    // Top highlight for glass effect
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    center: UnitPoint(x: 0.35, y: 0.3),
                                    startRadius: 0,
                                    endRadius: 200
                                )
                            )
                            .frame(width: 600, height: 600)
                    )

                // Clock hands container
                ZStack {
                    // Hour hand (shorter, thicker)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.cyan.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 20, height: 160)
                        .offset(y: -80)
                        .rotationEffect(.degrees(-30))
                        .shadow(color: Color.cyan.opacity(0.5), radius: 10, x: 0, y: 0)

                    // Minute hand (longer, thinner)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.purple.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 14, height: 230)
                        .offset(y: -115)
                        .rotationEffect(.degrees(90))
                        .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 0)

                    // Center dot
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white,
                                    Color.cyan.opacity(0.9)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.white.opacity(0.8), radius: 15, x: 0, y: 0)
                }

                // Subtle time markers (12, 3, 6, 9)
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 40)
                        .offset(y: -250)
                        .rotationEffect(.degrees(Double(index) * 90))
                }
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

// MARK: - Preview

struct AppIconGenerator_Previews: PreviewProvider {
    static var previews: some View {
        AppIconGenerator()
            .previewLayout(.fixed(width: 1024, height: 1024))
    }
}
