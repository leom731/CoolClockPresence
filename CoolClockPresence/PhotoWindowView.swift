// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  PhotoWindowView.swift
//
//  Floating photo display window (mirrors world clock behavior)
//

#if os(macOS)
import SwiftUI
import AppKit

struct PhotoWindowView: View {
    let photo: PhotoItem
    let image: NSImage?

    @AppStorage("photo.glassStyle") private var photoGlassStyle: String = "liquid"
    @AppStorage("photo.adjustableBlackOpacity") private var photoAdjustableBlackOpacity: Double = 0.82
    @AppStorage("photo.disappearOnHover") private var photoDisappearOnHover: Bool = true
    @AppStorage("photoWindowOpacity") private var photoWindowOpacity: Double = 1.0

    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var photoManager = PhotoWindowManager.shared
    @StateObject private var worldClockManager = WorldClockManager.shared
    @StateObject private var settingsManager = ClockSettingsManager.shared
    @State private var isHovering: Bool = false
    @State private var isCommandKeyPressed: Bool = false
    @State private var mouseLocation: CGPoint = .zero
    @State private var showResizeHints: Bool = false
    @State private var hasMigratedPhotoSettings = false

    private var appDelegate: AppDelegate? {
        NSApplication.shared.delegate as? AppDelegate
    }

    private func performMenuAction(_ selector: Selector) {
        let send = {
            if !NSApp.sendAction(selector, to: NSApp.delegate, from: nil) {
                NSApp.sendAction(selector, to: nil, from: nil)
            }
        }

        if Thread.isMainThread {
            send()
        } else {
            DispatchQueue.main.async(execute: send)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let radius = min(44, min(geometry.size.width, geometry.size.height) * 0.18)
            ZStack {
                GlassBackdrop(style: photoGlassStyle, adjustableOpacity: photoAdjustableBlackOpacity)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    placeholderView
                }
            }
            .mask(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .contentShape(Rectangle())
        .contextMenu { contextMenu }
        .overlay(
            HoverAndWindowController(
                isHovering: $isHovering,
                isCommandKeyPressed: $isCommandKeyPressed,
                isPremium: purchaseManager.isPremium,
                disappearOnHover: photoDisappearOnHover,
                mouseLocation: $mouseLocation,
                showResizeHints: $showResizeHints
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        )
        .overlay(
            GeometryReader { geometry in
                if showResizeHints {
                    ResizeEdgeIndicators(size: geometry.size, mouseLocation: mouseLocation)
                }
            }
            .allowsHitTesting(false)
        )
        .ignoresSafeArea()
        .opacity((isHovering && !isCommandKeyPressed && purchaseManager.isPremium && photoDisappearOnHover) ? 0 : photoWindowOpacity)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isCommandKeyPressed)
        .animation(.easeInOut(duration: 0.2), value: photoWindowOpacity)
        .onAppear {
            migrateLegacyPhotoSettingsIfNeeded()
        }
    }

    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.6), .indigo.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button {
            performMenuAction(#selector(AppDelegate.toggleClockWindow))
        } label: {
            let hasMainClock = settingsManager.isMainClockVisible
            let hasWorldClocks = worldClockManager.hasVisibleWindows
            let hasPhotos = photoManager.hasVisiblePhotos
            let isVisible = hasMainClock || hasWorldClocks || hasPhotos
            Text(isVisible ? "Hide Clock Window" : "Show Clock Window")
        }

        Button {
            performMenuAction(#selector(AppDelegate.toggleClocksOnly))
        } label: {
            let hasMainClock = settingsManager.isMainClockVisible
            let hasWorldClocks = worldClockManager.hasVisibleWindows
            let isVisible = hasMainClock || hasWorldClocks
            Text(isVisible ? "Hide Clocks Only" : "Show Clocks Only")
        }

        Button {
            performMenuAction(#selector(AppDelegate.togglePhotosOnly))
        } label: {
            let isVisible = photoManager.hasVisiblePhotos
            Text(isVisible ? "Hide Photos Only" : "Show Photos Only")
        }

        Divider()

        Button {
            PhotoWindowManager.shared.closePhotoWindow(for: photo.id)
        } label: {
            Text("Close This Photo")
        }

        Button(role: .destructive) {
            PhotoWindowManager.shared.removePhoto(id: photo.id)
        } label: {
            Text("Remove Photo")
        }

        Divider()

        Toggle("Disappear on Hover", isOn: $photoDisappearOnHover)

        Divider()

        Menu("Photo Opacity") {
            opacityButton(title: "100%", value: 1.0)
            opacityButton(title: "80%", value: 0.8)
            opacityButton(title: "60%", value: 0.6)
            opacityButton(title: "40%", value: 0.4)
        }

        Divider()

        Button("Manage Photos…") {
            performMenuAction(#selector(AppDelegate.showManagePhotos))
        }

        Button("Settings…") {
            performMenuAction(#selector(AppDelegate.openSettingsWindow))
        }
    }

    @ViewBuilder
    private func opacityButton(title: String, value: Double) -> some View {
        Button {
            photoWindowOpacity = value
        } label: {
            if abs(photoWindowOpacity - value) < 0.001 {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func migrateLegacyPhotoSettingsIfNeeded() {
        guard !hasMigratedPhotoSettings else { return }
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "photo.glassStyle") == nil,
           let legacyStyle = defaults.string(forKey: "glassStyle") {
            photoGlassStyle = legacyStyle
        }

        if defaults.object(forKey: "photo.adjustableBlackOpacity") == nil,
           let legacyOpacity = defaults.object(forKey: "adjustableBlackOpacity") as? Double {
            photoAdjustableBlackOpacity = min(max(legacyOpacity, 0.4), 1.0)
        }

        if defaults.object(forKey: "photo.disappearOnHover") == nil,
           defaults.object(forKey: "disappearOnHover") != nil {
            photoDisappearOnHover = defaults.bool(forKey: "disappearOnHover")
        }

        hasMigratedPhotoSettings = true
    }
}

// MARK: - Preview

struct PhotoWindowView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImage = NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil)
        PhotoWindowView(
            photo: PhotoItem(displayName: "Sample Photo", storedFileName: "preview.png"),
            image: sampleImage
        )
        .frame(width: 260, height: 260)
        .padding()
        .background(
            LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
        )
    }
}
#endif
