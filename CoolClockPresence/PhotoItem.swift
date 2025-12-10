// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  PhotoItem.swift
//
//  Data model for floating photo windows
//

#if os(macOS)
import Foundation

/// Represents a saved photo window with persisted position and backing file.
struct PhotoItem: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var storedFileName: String
    var originalFileName: String?
    var windowX: Double
    var windowY: Double
    var windowWidth: Double
    var windowHeight: Double

    init(
        id: UUID = UUID(),
        displayName: String,
        storedFileName: String,
        originalFileName: String? = nil,
        windowX: Double = -1,
        windowY: Double = -1,
        windowWidth: Double = 180,
        windowHeight: Double = 180
    ) {
        self.id = id
        self.displayName = displayName
        self.storedFileName = storedFileName
        self.originalFileName = originalFileName
        self.windowX = windowX
        self.windowY = windowY
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
    }

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}
#endif
