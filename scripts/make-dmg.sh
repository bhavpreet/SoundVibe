#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_NAME="SoundVibe"
APP_BUNDLE="$PROJECT_DIR/dist/${APP_NAME}.app"
DMG_DIR="$PROJECT_DIR/dist/dmg"
DMG_PATH="$PROJECT_DIR/dist/${APP_NAME}.dmg"

echo "=== Building SoundVibe Release ==="
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -3

echo ""
echo "=== Creating App Bundle ==="
rm -rf "$APP_BUNDLE" "$DMG_DIR" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/SoundVibe" "$APP_BUNDLE/Contents/MacOS/SoundVibe"

# Copy Info.plist and update minimum version
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 14.0" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Generate app icon using system SF Symbol
echo "=== Generating App Icon ==="
generate_icon() {
    local size=$1
    local scale=$2
    local pixel_size=$((size * scale))
    local filename="icon_${size}x${size}"
    if [ "$scale" -gt 1 ]; then
        filename="${filename}@${scale}x"
    fi
    filename="${filename}.png"
    
    # Use sips and a temporary tiff from an SF Symbol rendered by swift
    swift -e "
import AppKit
let size = CGSize(width: ${pixel_size}, height: ${pixel_size})
let image = NSImage(size: size, flipped: false) { rect in
    // Background circle
    let bg = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
    NSColor(calibratedRed: 0.2, green: 0.5, blue: 1.0, alpha: 1.0).setFill()
    bg.fill()
    // Waveform symbol
    if let symbol = NSImage(systemSymbolName: \"waveform\", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(${pixel_size}) * 0.4, weight: .bold)
        let configured = symbol.withSymbolConfiguration(config) ?? symbol
        let symbolSize = configured.size
        let symbolRect = NSRect(
            x: (rect.width - symbolSize.width) / 2,
            y: (rect.height - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        NSColor.white.setFill()
        configured.draw(in: symbolRect)
    }
    return true
}
let tiff = image.tiffRepresentation!
let bitmap = NSBitmapImageRep(data: tiff)!
let png = bitmap.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: \"/tmp/soundvibe_icon_${pixel_size}.png\"))
" 2>/dev/null
    
    cp "/tmp/soundvibe_icon_${pixel_size}.png" "$ICONSET_DIR/$filename"
}

ICONSET_DIR="/tmp/SoundVibe.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate all required icon sizes
for size in 16 32 128 256 512; do
    generate_icon $size 1
    generate_icon $size 2
done

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR" /tmp/soundvibe_icon_*.png

echo "=== App Bundle Created: $APP_BUNDLE ==="
echo "  Binary: $(du -h "$APP_BUNDLE/Contents/MacOS/SoundVibe" | cut -f1)"

# Verify the bundle works
codesign -s - --force --deep "$APP_BUNDLE" 2>/dev/null || echo "  (ad-hoc signing)"

echo ""
echo "=== Creating DMG ==="
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create a symlink to /Applications for drag-and-drop install
ln -s /Applications "$DMG_DIR/Applications"

# Create the DMG
hdiutil create \
    -volname "SoundVibe" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" 2>&1 | grep -v "^$"

rm -rf "$DMG_DIR"

echo ""
echo "=== Done ==="
echo "DMG: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "To install: Open the DMG and drag SoundVibe to Applications"
