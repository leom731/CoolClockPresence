#!/bin/bash

# Icon Generator Script for CoolClockPresence
# This script takes a 1024x1024 source image and generates all required macOS app icon sizes

SOURCE_IMAGE="$1"
ICON_DIR="CoolClockPresence/Assets.xcassets/AppIcon.appiconset"

if [ -z "$SOURCE_IMAGE" ]; then
    echo "Usage: ./generate_icons.sh <path_to_1024x1024_icon.png>"
    echo ""
    echo "First, generate the icon image:"
    echo "1. Open IconGenerator.swift in Xcode"
    echo "2. Show the Preview pane (Cmd+Option+Enter)"
    echo "3. Take a screenshot of the 1024x1024 preview"
    echo "4. Save it as icon_1024.png"
    echo "5. Run: ./generate_icons.sh icon_1024.png"
    exit 1
fi

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image '$SOURCE_IMAGE' not found!"
    exit 1
fi

echo "Generating app icons from $SOURCE_IMAGE..."
echo ""

# Create icon directory if it doesn't exist
mkdir -p "$ICON_DIR"

# Function to generate icon
generate_icon() {
    local size=$1
    local filename=$2
    echo "  Creating $filename (${size}x${size}px)..."
    sips -z $size $size "$SOURCE_IMAGE" --out "$ICON_DIR/$filename" > /dev/null 2>&1
}

# Generate all required sizes
generate_icon 16 "icon_16x16.png"
generate_icon 32 "icon_16x16@2x.png"
generate_icon 32 "icon_32x32.png"
generate_icon 64 "icon_32x32@2x.png"
generate_icon 128 "icon_128x128.png"
generate_icon 256 "icon_128x128@2x.png"
generate_icon 256 "icon_256x256.png"
generate_icon 512 "icon_256x256@2x.png"
generate_icon 512 "icon_512x512.png"
generate_icon 1024 "icon_512x512@2x.png"

echo ""
echo "✓ All app icons generated successfully!"
echo "  Location: $ICON_DIR"
echo ""
echo "Next steps:"
echo "1. Clean build folder in Xcode (Cmd+Shift+K)"
echo "2. Build and run your app"
echo "3. Your new icon should appear!"
