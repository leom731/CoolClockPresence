//
//  ClockPresenceView.swift
//  CoolClockPresence
//
//  Crafted for a floating, glassy clock experience on macOS.
//

#if os(macOS)
import SwiftUI
import AppKit

/// A compact glass-inspired clock that can float above other windows.
struct ClockPresenceView: View {
    @State private var windowSize: CGSize = CGSize(width: 280, height: 100)

    private let baseSize = CGSize(width: 280, height: 100)

    private var scale: CGFloat {
        // Calculate scale based on current window size relative to base size
        let widthScale = windowSize.width / baseSize.width
        let heightScale = windowSize.height / baseSize.height
        return min(widthScale, heightScale)
    }

    private var clockFont: Font {
        .system(size: 38 * scale, weight: .semibold, design: .rounded)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date

            GeometryReader { geometry in
                ZStack {
                    GlassBackdrop()

                    Text(date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute().second()))
                        .font(clockFont)
                        .foregroundStyle(Color.primary.opacity(0.92))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.vertical, 12 * scale)
                        .padding(.horizontal, 16 * scale)
                }
                .onAppear {
                    windowSize = geometry.size
                }
                .onChange(of: geometry.size) { newSize in
                    windowSize = newSize
                }
            }
            .frame(minWidth: baseSize.width * 0.6, minHeight: baseSize.height * 0.6)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Backdrop

private struct GlassBackdrop: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.3))
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color.cyan.opacity(0.08),
                            Color.purple.opacity(0.10),
                            Color.blue.opacity(0.08)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .blur(radius: 30)
                    .opacity(0.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.08)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Preview

struct ClockPresenceView_Previews: PreviewProvider {
    static var previews: some View {
        ClockPresenceView()
            .frame(width: 320, height: 180)
            .padding()
            .background(
                LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
            )
    }
}
#endif
