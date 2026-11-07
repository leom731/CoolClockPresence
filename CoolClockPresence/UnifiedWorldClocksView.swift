#if os(macOS)
import SwiftUI

/// A single detachable window containing multiple world clocks.
struct UnifiedWorldClocksView: View {
    @StateObject private var manager = WorldClockManager.shared
    @StateObject private var photoManager = PhotoWindowManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @AppStorage("unifiedWorldClockFontScale") private var fontScale = 1.0
    @AppStorage("worldClockDimmed") private var isWorldClockDimmed = true
    @State private var showingPicker = false
    @State private var showingPurchaseSheet = false
    @State private var isHovering = false
    @State private var isCommandKeyPressed = false
    @State private var mouseLocation: CGPoint = .zero
    @State private var showResizeHints = false

    private var locations: [WorldClockLocation] {
        manager.unifiedWindowLocationIDs.compactMap { id in
            manager.savedLocations.first(where: { $0.id == id })
        }
    }

    private var settings: ClockSettings { manager.unifiedWindowSettings }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let photoID = settings.backgroundPhotoID {
                    BackgroundPhotoView(
                        photoID: photoID,
                        opacity: settings.backgroundPhotoOpacity,
                        aspectMode: settings.backgroundPhotoAspectMode
                    )
                }

                GlassBackdrop(
                    style: settings.glassStyle,
                    adjustableOpacity: settings.adjustableBlackOpacity
                )

                ScrollView(.vertical, showsIndicators: locations.count > 3) {
                    LazyVStack(spacing: 0) {
                        ForEach(locations) { location in
                            DockedWorldClockView(
                                location: location,
                                scale: fontScale,
                                onAddWorldClock: { showingPicker = true },
                                onRedockToMainClock: { manager.dockClock(for: location.id) }
                            )
                            .frame(maxWidth: .infinity, minHeight: 68 * fontScale)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button("Add World Clock…") {
                    showingPicker = true
                }

                if !locations.isEmpty {
                    Menu("Redock to Main Clock") {
                        if locations.count > 1 {
                            Button("All World Clocks") {
                                manager.redockAllUnifiedClocks()
                            }
                            Divider()
                        }

                        ForEach(locations) { location in
                            Button(location.displayName) {
                                manager.dockClock(for: location.id)
                            }
                        }
                    }

                    Divider()

                    if purchaseManager.isPremium {
                        Button {
                            manager.updateUnifiedClockSettings(\.disappearOnHover, value: !settings.disappearOnHover)
                        } label: {
                            if settings.disappearOnHover {
                                Label("Hide on Hover", systemImage: "checkmark")
                            } else {
                                Text("Hide on Hover")
                            }
                        }

                        Button {
                            manager.setUnifiedAlwaysOnTop(!settings.alwaysOnTop)
                        } label: {
                            if settings.alwaysOnTop {
                                Label("Always on Top", systemImage: "checkmark")
                            } else {
                                Text("Always on Top")
                            }
                        }
                    } else {
                        Button("Hide on Hover 🔒 Premium") { showingPurchaseSheet = true }
                        Button("Always on Top 🔒 Premium") { showingPurchaseSheet = true }
                    }

                    Menu("Background Photo") {
                        Button {
                            manager.updateUnifiedClockSettings(\.backgroundPhotoID, value: nil as UUID?)
                        } label: {
                            if settings.backgroundPhotoID == nil { Label("None", systemImage: "checkmark") }
                            else { Text("None") }
                        }

                        if !photoManager.savedPhotos.isEmpty {
                            Divider()
                            ForEach(photoManager.savedPhotos, id: \.id) { photo in
                                Button {
                                    manager.updateUnifiedClockSettings(\.backgroundPhotoID, value: photo.id as UUID?)
                                } label: {
                                    if settings.backgroundPhotoID == photo.id {
                                        Label(photo.displayName, systemImage: "checkmark")
                                    } else { Text(photo.displayName) }
                                }
                            }
                            Divider()
                            Menu("Opacity") {
                                ForEach([1.0, 0.8, 0.6, 0.4, 0.2], id: \.self) { opacity in
                                    Button {
                                        manager.updateUnifiedClockSettings(\.backgroundPhotoOpacity, value: opacity)
                                    } label: {
                                        if abs(settings.backgroundPhotoOpacity - opacity) < 0.001 {
                                            Label("\(Int(opacity * 100))%", systemImage: "checkmark")
                                        } else { Text("\(Int(opacity * 100))%") }
                                    }
                                }
                            }
                            Menu("Display Mode") {
                                photoModeButton("Aspect Fill", mode: "fill")
                                photoModeButton("Aspect Fit", mode: "fit")
                            }
                        } else {
                            Divider()
                            Text("No photos available")
                            Button("Add Photo…") {
                                NSApp.sendAction(#selector(AppDelegate.showPhotoPicker), to: NSApp.delegate, from: nil)
                            }
                        }
                    }

                    Menu("Glass Style") {
                        glassStyleButton("Liquid Glass", style: "liquid")
                        glassStyleButton("Clear Glass", style: "clear")
                        glassStyleButton("Black Glass", style: "black")
                        glassStyleButton("Adjustable Black Glass", style: "adjustableBlack")
                        Divider()
                        Menu("Black Opacity") {
                            ForEach([0.95, 0.82, 0.65, 0.5, 0.35], id: \.self) { opacity in
                                Button {
                                    manager.updateUnifiedClockSettings(\.adjustableBlackOpacity, value: opacity)
                                } label: {
                                    if abs(settings.adjustableBlackOpacity - opacity) < 0.001 {
                                        Label("\(Int(opacity * 100))%", systemImage: "checkmark")
                                    } else { Text("\(Int(opacity * 100))%") }
                                }
                            }
                        }
                    }

                    Menu("Font Size") {
                        fontSizeButton("Small", scale: 0.8)
                        fontSizeButton("Medium", scale: 1.0)
                        fontSizeButton("Large", scale: 1.2)
                    }

                    Menu("All Clocks Font Color") {
                        fontColorButton("White", color: "white")
                        fontColorButton("Green", color: "green")

                        if purchaseManager.isPremium {
                            Divider()
                            fontColorButton("Black", color: "black")
                            fontColorButton("Cyan", color: "cyan")
                            fontColorButton("Red", color: "red")
                            fontColorButton("Orange", color: "orange")
                            fontColorButton("Yellow", color: "yellow")
                            fontColorButton("Blue", color: "blue")
                            fontColorButton("Purple", color: "purple")
                            fontColorButton("Pink", color: "pink")
                            fontColorButton("Mint", color: "mint")
                            fontColorButton("Teal", color: "teal")
                            fontColorButton("Indigo", color: "indigo")
                        } else {
                            Divider()
                            Button("More Colors 🔒 Premium") {
                                showingPurchaseSheet = true
                            }
                        }
                    }

                    Button {
                        isWorldClockDimmed.toggle()
                    } label: {
                        if isWorldClockDimmed {
                            Label("Dim World Clock", systemImage: "checkmark")
                        } else {
                            Text("Dim World Clock")
                        }
                    }

                    Menu("Font Style") {
                        fontStyleButton("Rounded (Default)", style: "rounded")
                        fontStyleButton("Monospaced", style: "monospaced")
                        fontStyleButton("Serif", style: "serif")
                        fontStyleButton("Time Circuit (LED)", style: "led")
                        Divider()
                        fontStyleButton("Ultra Light", style: "ultralight")
                        fontStyleButton("Thin", style: "thin")
                        fontStyleButton("Light", style: "light")
                        fontStyleButton("Medium", style: "medium")
                        fontStyleButton("Bold", style: "bold")
                        fontStyleButton("Heavy", style: "heavy")
                        fontStyleButton("Black", style: "black")
                    }

                    Divider()

                    Button("Manage World Clocks…") {
                        NSApp.sendAction(#selector(AppDelegate.showManageWorldClocks), to: NSApp.delegate, from: nil)
                    }
                }
            }
            .background(
                HoverAndWindowController(
                    isHovering: $isHovering,
                    isCommandKeyPressed: $isCommandKeyPressed,
                    isPremium: purchaseManager.isPremium,
                    disappearOnHover: settings.disappearOnHover,
                    mouseLocation: $mouseLocation,
                    showResizeHints: $showResizeHints
                )
            )
        }
        .opacity((isHovering && !isCommandKeyPressed && purchaseManager.isPremium && settings.disappearOnHover) ? 0 : settings.clockOpacity)
        .sheet(isPresented: $showingPicker) {
            WorldClockPickerView { location in
                manager.addLocationToUnifiedWindow(location)
            }
        }
        .sheet(isPresented: $showingPurchaseSheet) { PurchaseView() }
        .onChange(of: locations.count) { _, _ in
            manager.fitUnifiedWindowToClocks(fontScale: fontScale)
        }
        .onChange(of: fontScale) { _, newScale in
            manager.fitUnifiedWindowToClocks(fontScale: newScale)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private func glassStyleButton(_ title: String, style: String) -> some View {
        Button {
            manager.updateUnifiedClockSettings(\.glassStyle, value: style)
        } label: {
            if settings.glassStyle == style { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }

    @ViewBuilder private func photoModeButton(_ title: String, mode: String) -> some View {
        Button {
            manager.updateUnifiedClockSettings(\.backgroundPhotoAspectMode, value: mode)
        } label: {
            if settings.backgroundPhotoAspectMode == mode { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }

    @ViewBuilder private func fontSizeButton(_ title: String, scale: Double) -> some View {
        Button { fontScale = scale } label: {
            if abs(fontScale - scale) < 0.001 { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }

    @ViewBuilder private func fontColorButton(_ title: String, color: String) -> some View {
        Button {
            manager.updateUnifiedClockSettings(\.fontColorName, value: color)
        } label: {
            if settings.fontColorName == color { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }

    @ViewBuilder private func fontStyleButton(_ title: String, style: String) -> some View {
        Button {
            manager.updateUnifiedClockSettings(\.fontDesign, value: style)
        } label: {
            if settings.fontDesign == style { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }
}
#endif
