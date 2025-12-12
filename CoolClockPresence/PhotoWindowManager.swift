// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  PhotoWindowManager.swift
//
//  Manages floating photo windows (add, persist, remove)
//

#if os(macOS)
import SwiftUI
import AppKit
import Combine

/// Singleton manager for photo windows
final class PhotoWindowManager: ObservableObject {
    static let shared = PhotoWindowManager()

    @Published private(set) var savedPhotos: [PhotoItem] = []
    private var openWindows: [UUID: NSPanel] = [:]
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let storageDirectory: URL

    private init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let appDirectory = base.appendingPathComponent("CoolClockPresence", isDirectory: true)
        let photoDirectory = appDirectory.appendingPathComponent("Photos", isDirectory: true)
        storageDirectory = photoDirectory

        do {
            try fileManager.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
        } catch {
            print("⚠️ Failed to create photo storage directory: \(error)")
        }

        loadPhotos()
    }

    var photosDirectory: URL { storageDirectory }

    // MARK: - Image Persistence

    func addPhoto(from url: URL) {
        guard var item = storeImage(at: url) else { return }

        let defaultSize: Double = 180

        if let mainWindow = NSApp.windows.first(where: { $0.title == "CoolClockPresence" }) {
            item.windowWidth = defaultSize
            item.windowHeight = defaultSize
            item.windowX = mainWindow.frame.origin.x + 40
            item.windowY = mainWindow.frame.origin.y - 40
        } else if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            item.windowX = frame.midX - (item.windowWidth / 2)
            item.windowY = frame.midY - (item.windowHeight / 2)
        }

        savedPhotos.append(item)
        savePhotos()
        openPhotoWindow(for: item)
    }

    func image(for photo: PhotoItem) -> NSImage? {
        let url = storageDirectory.appendingPathComponent(photo.storedFileName)
        return NSImage(contentsOf: url)
    }

    func removePhoto(id: UUID) {
        closePhotoWindow(for: id)

        if let item = savedPhotos.first(where: { $0.id == id }) {
            let url = storageDirectory.appendingPathComponent(item.storedFileName)
            try? fileManager.removeItem(at: url)
        }

        savedPhotos.removeAll { $0.id == id }
        savePhotos()
    }

    // MARK: - Window Management

    func openPhotoWindow(for photo: PhotoItem) {
        guard openWindows[photo.id] == nil else {
            openWindows[photo.id]?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NotificationCenter.default.post(
            name: NSNotification.Name("OpenPhotoWindow"),
            object: nil,
            userInfo: ["photo": photo]
        )
    }

    func registerPhotoWindow(_ window: NSPanel, for photoID: UUID) {
        openWindows[photoID] = window
    }

    func unregisterPhotoWindow(for photoID: UUID) {
        openWindows.removeValue(forKey: photoID)
    }

    func closePhotoWindow(for photoID: UUID) {
        if let window = openWindows[photoID] {
            window.close()
            openWindows.removeValue(forKey: photoID)
        }
    }

    func togglePhotoWindow(for photo: PhotoItem) {
        if openWindows[photo.id] != nil {
            closePhotoWindow(for: photo.id)
        } else {
            openPhotoWindow(for: photo)
        }
    }

    func isPhotoOpen(id: UUID) -> Bool {
        openWindows[id] != nil
    }

    func updatePhotoWindow(id: UUID, x: Double, y: Double, width: Double, height: Double) {
        if let index = savedPhotos.firstIndex(where: { $0.id == id }) {
            savedPhotos[index].windowX = x
            savedPhotos[index].windowY = y
            savedPhotos[index].windowWidth = width
            savedPhotos[index].windowHeight = height
            savePhotos()
        }
    }

    func closeAllPhotos() {
        for (_, window) in openWindows {
            window.close()
        }
        openWindows.removeAll()
    }

    // MARK: - Persistence

    private func loadPhotos() {
        guard let data = defaults.data(forKey: "photoWindows") else { return }
        do {
            savedPhotos = try JSONDecoder().decode([PhotoItem].self, from: data)
        } catch {
            print("⚠️ Failed to load photo windows: \(error)")
            savedPhotos = []
        }
    }

    private func savePhotos() {
        do {
            let data = try JSONEncoder().encode(savedPhotos)
            defaults.set(data, forKey: "photoWindows")
        } catch {
            print("⚠️ Failed to save photo windows: \(error)")
        }
    }

    // MARK: - Helpers

    private func storeImage(at url: URL) -> PhotoItem? {
        guard let image = NSImage(contentsOf: url) else {
            print("⚠️ Unable to load image from \(url.lastPathComponent)")
            return nil
        }

        guard let data = image.pngData() else {
            print("⚠️ Unable to convert image to PNG for \(url.lastPathComponent)")
            return nil
        }

        let id = UUID()
        let filename = "\(id.uuidString).png"
        let destinationURL = storageDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            print("⚠️ Failed to store image at \(destinationURL): \(error)")
            return nil
        }

        let cleanedName = url.deletingPathExtension().lastPathComponent
        let displayName = cleanedName.isEmpty ? "Photo" : cleanedName

        return PhotoItem(
            id: id,
            displayName: displayName,
            storedFileName: filename,
            originalFileName: url.lastPathComponent,
            windowX: -1,
            windowY: -1,
            windowWidth: 180,
            windowHeight: 180
        )
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif
