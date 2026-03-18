#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_NAME="SoundVibe"
APP_BUNDLE="$PROJECT_DIR/dist/${APP_NAME}.app"
DMG_DIR="$PROJECT_DIR/dist/dmg"
DMG_PATH="$PROJECT_DIR/dist/${APP_NAME}.dmg"

# Clean up any stale mounts and old build artifacts
for vol in /Volumes/SoundVibe*; do
    [ -d "$vol" ] && hdiutil detach "$vol" -force 2>/dev/null || true
done
rm -f "$PROJECT_DIR/dist/${APP_NAME}_temp.dmg"
rm -f "$DMG_PATH"

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
echo "=== Generating DMG Background ==="
BG_IMAGE="/tmp/soundvibe_dmg_bg.png"
swift "$PROJECT_DIR/scripts/generate-dmg-background.swift" "$BG_IMAGE"

echo ""
echo "=== Creating DMG ==="
DMG_TEMP="$PROJECT_DIR/dist/${APP_NAME}_temp.dmg"
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create a symlink to /Applications for drag-and-drop install
ln -s /Applications "$DMG_DIR/Applications"

# Create a hidden .background folder with the background image
mkdir -p "$DMG_DIR/.background"
cp "$BG_IMAGE" "$DMG_DIR/.background/background.png"

# Detach any existing SoundVibe volumes to avoid "SoundVibe 1" naming
for vol in /Volumes/SoundVibe*; do
    [ -d "$vol" ] && hdiutil detach "$vol" -force 2>/dev/null || true
done
sleep 1

# Create a read-write DMG first
hdiutil create \
    -volname "SoundVibe" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDRW \
    "$DMG_TEMP" 2>&1 | grep -v "^$"

# Mount the read-write DMG
ATTACH_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP")
MOUNT_DIR=$(echo "$ATTACH_OUTPUT" | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')
VOLUME_NAME=$(basename "$MOUNT_DIR")
echo "Mounted at: $MOUNT_DIR (volume: $VOLUME_NAME)"

# Give Finder time to detect the volume
sleep 3

# Use AppleScript to set Finder view options
osascript <<EOF
tell application "Finder"
    -- Wait for the disk to appear
    set volumeName to "$VOLUME_NAME"
    set maxWait to 15
    set waited to 0
    repeat while waited < maxWait
        try
            set theDisk to disk volumeName
            exit repeat
        on error
            delay 1
            set waited to waited + 1
        end try
    end repeat

    tell disk volumeName
        open
        delay 2
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        set position of item "SoundVibe.app" of container window to {150, 190}
        set position of item "Applications" of container window to {450, 190}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Ensure Finder writes changes
sync
sleep 2

# Detach the DMG
hdiutil detach "$MOUNT_DIR" -quiet -force

# Convert to compressed read-only DMG
hdiutil convert \
    "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" 2>&1 | grep -v "^$"

rm -f "$DMG_TEMP"
rm -rf "$DMG_DIR"
rm -f "$BG_IMAGE"

echo ""
echo "=== Done ==="
echo "DMG: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "To install: Open the DMG and drag SoundVibe to Applications"
