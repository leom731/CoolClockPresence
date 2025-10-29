#!/usr/bin/env swift
import AppKit
import Foundation

// Simple Core Graphics icon generator
func generateIcon() {
    let size = 1024
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create context")
        return
    }

    let center = CGPoint(x: size / 2, y: size / 2)

    // Background gradient
    let backgroundColors = [
        CGColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1.0),
        CGColor(red: 0.15, green: 0.1, blue: 0.2, alpha: 1.0)
    ]

    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: backgroundColors as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size, y: size),
            options: []
        )
    }

    // Outer glow
    let glowColors = [
        CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.4),
        CGColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 0.3),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ]

    if let glowGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: glowColors as CFArray,
        locations: [0.0, 0.5, 1.0]
    ) {
        context.drawRadialGradient(
            glowGradient,
            startCenter: center,
            startRadius: 180,
            endCenter: center,
            endRadius: 500,
            options: []
        )
    }

    // Main glass sphere
    let sphereRadius: CGFloat = 300
    let sphereColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.15),
        CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.12),
        CGColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 0.12),
        CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.08)
    ]

    if let sphereGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: sphereColors as CFArray,
        locations: [0.0, 0.33, 0.66, 1.0]
    ) {
        context.drawRadialGradient(
            sphereGradient,
            startCenter: CGPoint(x: center.x - 50, y: center.y - 50),
            startRadius: 50,
            endCenter: center,
            endRadius: sphereRadius,
            options: []
        )
    }

    // Sphere border
    context.setLineWidth(3)
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3))
    context.addArc(center: center, radius: sphereRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    context.strokePath()

    // Glass highlight
    let highlightColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.4),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
    ]

    if let highlightGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: highlightColors as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.drawRadialGradient(
            highlightGradient,
            startCenter: CGPoint(x: center.x - 80, y: center.y - 80),
            startRadius: 0,
            endCenter: CGPoint(x: center.x - 80, y: center.y - 80),
            endRadius: 150,
            options: []
        )
    }

    // Clock markers (12, 3, 6, 9 positions)
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3))
    for i in 0..<4 {
        let angle = CGFloat(i) * .pi / 2 - .pi / 2
        let x = center.x + cos(angle) * 250
        let y = center.y + sin(angle) * 250
        let markerRect = CGRect(x: x - 4, y: y - 20, width: 8, height: 40)
        let markerPath = CGPath(roundedRect: markerRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        context.addPath(markerPath)
        context.fillPath()
    }

    // Hour hand (10:10 position - classic)
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: -.pi / 6) // -30 degrees

    let hourHandPath = CGPath(
        roundedRect: CGRect(x: -10, y: -80, width: 20, height: 160),
        cornerWidth: 8,
        cornerHeight: 8,
        transform: nil
    )

    let hourColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9),
        CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.8)
    ]

    if let hourGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: hourColors as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.addPath(hourHandPath)
        context.clip()
        context.drawLinearGradient(
            hourGradient,
            start: CGPoint(x: 0, y: -80),
            end: CGPoint(x: 0, y: 80),
            options: []
        )
    }

    context.restoreGState()

    // Minute hand (10:10 position)
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: .pi / 6) // 30 degrees

    let minuteHandPath = CGPath(
        roundedRect: CGRect(x: -7, y: -115, width: 14, height: 230),
        cornerWidth: 6,
        cornerHeight: 6,
        transform: nil
    )

    let minuteColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9),
        CGColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 0.8)
    ]

    if let minuteGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: minuteColors as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.addPath(minuteHandPath)
        context.clip()
        context.drawLinearGradient(
            minuteGradient,
            start: CGPoint(x: 0, y: -115),
            end: CGPoint(x: 0, y: 115),
            options: []
        )
    }

    context.restoreGState()

    // Center dot
    let centerDotColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.9)
    ]

    if let centerGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: centerDotColors as CFArray,
        locations: [0.0, 1.0]
    ) {
        context.drawRadialGradient(
            centerGradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: 25,
            options: []
        )
    }

    // Save the image
    if let cgImage = context.makeImage() {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))

        if let tiffData = nsImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {

            let outputPath = "CoolClockPresence/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
            let url = URL(fileURLWithPath: outputPath)

            do {
                try pngData.write(to: url)
                print("✓ Icon successfully generated!")
                print("  Location: \(outputPath)")
                print("")
                print("Next steps:")
                print("1. Open your project in Xcode")
                print("2. Clean build folder (Cmd+Shift+K)")
                print("3. Build and run (Cmd+R)")
            } catch {
                print("Error writing file: \(error)")
            }
        }
    }
}

print("Generating CoolClockPresence app icon...")
print("")
generateIcon()
