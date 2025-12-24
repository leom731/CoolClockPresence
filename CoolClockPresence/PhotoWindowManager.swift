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

/// Snapshot of a deleted photo so it can be restored.
struct PhotoDeletionSnapshot {
    let item: PhotoItem
    let index: Int
    let imageData: Data?
}

/// Singleton manager for photo windows
final class PhotoWindowManager: ObservableObject {
    static let shared = PhotoWindowManager()

    @Published private(set) var savedPhotos: [PhotoItem] = []
    @Published private(set) var hasVisiblePhotos: Bool = false
    private var openWindows: [UUID: NSPanel] = [:]
    private var openPhotoIDs: Set<UUID> = []
    private var arePhotosHidden: Bool = false
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    private let openPhotoIDsKey = "openPhotoWindowIDs"

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
        loadOpenPhotoIDs()
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
        _ = removePhotoWithSnapshot(id: id)
    }

    func removePhotoWithSnapshot(id: UUID) -> PhotoDeletionSnapshot? {
        guard let index = savedPhotos.firstIndex(where: { $0.id == id }) else { return nil }
        let item = savedPhotos[index]

        let fileURL = storageDirectory.appendingPathComponent(item.storedFileName)
        let data = try? Data(contentsOf: fileURL)

        closePhotoWindow(for: id)

        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }

        savedPhotos.removeAll { $0.id == id }
        savePhotos()

        return PhotoDeletionSnapshot(item: item, index: index, imageData: data)
    }

    func restorePhoto(from snapshot: PhotoDeletionSnapshot) {
        guard let data = snapshot.imageData else {
            print("⚠️ Unable to restore photo: missing image data.")
            return
        }

        let destinationURL = storageDirectory.appendingPathComponent(snapshot.item.storedFileName)

        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            print("⚠️ Failed to restore photo image: \(error)")
            return
        }

        let insertionIndex = min(snapshot.index, savedPhotos.count)
        savedPhotos.insert(snapshot.item, at: insertionIndex)
        savePhotos()
    }

    // MARK: - Reordering

    func movePhoto(draggedID: UUID, to targetID: UUID) {
        guard let fromIndex = savedPhotos.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = savedPhotos.firstIndex(where: { $0.id == targetID }) else { return }

        movePhoto(from: fromIndex, to: targetIndex)
    }

    func movePhotoToEnd(_ id: UUID) {
        guard let fromIndex = savedPhotos.firstIndex(where: { $0.id == id }) else { return }
        let item = savedPhotos.remove(at: fromIndex)
        savedPhotos.append(item)
        savePhotos()
    }

    private func movePhoto(from fromIndex: Int, to targetIndex: Int) {
        guard fromIndex != targetIndex else { return }

        let item = savedPhotos.remove(at: fromIndex)
        let insertionIndex = targetIndex > fromIndex ? targetIndex - 1 : targetIndex
        savedPhotos.insert(item, at: insertionIndex)
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
        markPhotoOpen(photo.id)
    }

    func registerPhotoWindow(_ window: NSPanel, for photoID: UUID) {
        openWindows[photoID] = window
        updateVisibility()
    }

    func unregisterPhotoWindow(for photoID: UUID) {
        openWindows.removeValue(forKey: photoID)
        updateVisibility()
    }

    func closePhotoWindow(for photoID: UUID) {
        if let window = openWindows[photoID] {
            window.close()
            openWindows.removeValue(forKey: photoID)
        }
        markPhotoClosed(photoID)
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

    private func updateVisibility() {
        hasVisiblePhotos = !openWindows.isEmpty && !arePhotosHidden
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
        var didChange = false

        for (id, window) in openWindows {
            window.close()
            if openPhotoIDs.remove(id) != nil {
                didChange = true
            }
        }
        openWindows.removeAll()

        if didChange {
            saveOpenPhotoIDs()
        }
    }

    /// Hide every open photo window without closing so they can be restored later.
    func hideAllOpenPhotos() {
        openWindows.values.forEach { $0.orderOut(nil) }
        arePhotosHidden = true
        updateVisibility()
    }

    /// Bring back every open photo window.
    func showAllOpenPhotos() {
        openWindows.values.forEach { $0.orderFrontRegardless() }
        arePhotosHidden = false
        updateVisibility()
    }

    // MARK: - Persistence

    /// Restore any photo widgets that were open the last time the app ran.
    func restoreOpenPhotos() {
        let idsToRestore = Array(openPhotoIDs)
        var didPrune = false

        for id in idsToRestore {
            guard let photo = savedPhotos.first(where: { $0.id == id }) else {
                openPhotoIDs.remove(id)
                didPrune = true
                continue
            }

            openPhotoWindow(for: photo)
        }

        if didPrune {
            saveOpenPhotoIDs()
        }
    }

    private func loadOpenPhotoIDs() {
        guard let data = defaults.data(forKey: openPhotoIDsKey) else { return }
        do {
            let ids = try JSONDecoder().decode([UUID].self, from: data)
            openPhotoIDs = Set(ids)
        } catch {
            print("⚠️ Failed to load open photo IDs: \(error)")
            openPhotoIDs = []
        }
    }

    private func saveOpenPhotoIDs() {
        do {
            let data = try JSONEncoder().encode(Array(openPhotoIDs))
            defaults.set(data, forKey: openPhotoIDsKey)
        } catch {
            print("⚠️ Failed to save open photo IDs: \(error)")
        }
    }

    private func markPhotoOpen(_ id: UUID) {
        if openPhotoIDs.insert(id).inserted {
            saveOpenPhotoIDs()
        }
    }

    private func markPhotoClosed(_ id: UUID) {
        if openPhotoIDs.remove(id) != nil {
            saveOpenPhotoIDs()
        }
    }

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
