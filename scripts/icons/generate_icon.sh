#!/usr/bin/env bash
# Simple icon generation script for EasyMac
# Usage: generate_icon.sh <build_dir> <AppName>
set -euo pipefail
BUILD_DIR=${1:-build}
APP_NAME=${2:-EasyMac}
mkdir -p "$BUILD_DIR/${APP_NAME}.iconset"

# Use sips to create colored square placeholder icons; replace with real design assets as needed.
BASE_COLOR="#274fA6" # brand-ish blue
TMP_PNG="$BUILD_DIR/icon_base.png"

# Create 1024 base canvas using ImageMagick if available else sips fallback
if command -v convert >/dev/null 2>&1; then
  convert -size 1024x1024 "canvas:${BASE_COLOR}" "$TMP_PNG"
else
  # sips cannot directly create solid color; fallback to Swift generation if convert missing
  cat > "$BUILD_DIR/icon_gen.swift" <<'EOF'
import Cocoa
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
NSColor(calibratedRed: 0.15, green: 0.31, blue: 0.65, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let cfg = NSImage.SymbolConfiguration(pointSize: 520, weight: .regular)
if let sym = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    sym.draw(in: NSRect(x: 160, y: 160, width: 704, height: 704))
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
EOF
  swiftc -O -o "$BUILD_DIR/icon_gen" "$BUILD_DIR/icon_gen.swift" -framework Cocoa
  "$BUILD_DIR/icon_gen" "$TMP_PNG"
fi

SIZES=(16 32 64 128 256 512)
for s in "${SIZES[@]}"; do
  sips -Z "$s" "$TMP_PNG" --out "$BUILD_DIR/${APP_NAME}.iconset/icon_${s}x${s}.png" >/dev/null 2>&1 || true
  s2=$((s*2))
  sips -Z "$s2" "$TMP_PNG" --out "$BUILD_DIR/${APP_NAME}.iconset/icon_${s}x${s}@2x.png" >/dev/null 2>&1 || true
done

if command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "$BUILD_DIR/${APP_NAME}.iconset" -o "$BUILD_DIR/${APP_NAME}.icns"
  echo "Generated $BUILD_DIR/${APP_NAME}.icns"
else
  echo "iconutil not found; .icns not generated (placeholder PNGs present)."
fi

# Clean intermediates
rm -f "$BUILD_DIR/icon_gen.swift" "$BUILD_DIR/icon_gen" "$TMP_PNG" 2>/dev/null || true
