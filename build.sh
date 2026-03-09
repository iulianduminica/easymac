#!/bin/bash
set -euo pipefail

# Unified build script for EasyMac
# Usage:
#   ./build.sh                          (build all modules)
#   ./build.sh --modules trashkey       (only include TrashKeyModule)
#   ./build.sh --modules trashkey,cut   (include multiple modules)

APP_NAME="EasyMac"
BUNDLE_ID="com.mac.easymac"
BUILD_DIR="build"
SRC_MAIN="main.swift"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Parse optional --modules flag (comma-separated IDs matching file name prefix e.g. TrashKeyModule)
INCLUDE_PATTERN=""
if [[ ${1:-} == "--modules" && -n ${2:-} ]]; then
  IFS=',' read -r -a REQ_MODS <<< "$2"
  for m in "${REQ_MODS[@]}"; do
    # Map module id (e.g. trashkey) to file pattern (case-insensitive match on filename)
    PATTERN=$(echo "$m" | tr '[:lower:]' '[:upper:]')
  done
  INCLUDE_PATTERN="${REQ_MODS[*]}"
  shift 2 || true
fi

# Generate icon via external script (creates ${APP_NAME}.icns in build dir)
SCRIPT_ICON="scripts/icons/generate_icon.sh"
if [[ -x "$SCRIPT_ICON" ]]; then
  "$SCRIPT_ICON" "$BUILD_DIR" "$APP_NAME" || echo "Icon script failed; proceeding with placeholder."
else
  echo "(Info) Icon script missing; skipping custom icon generation."
fi

# Compile sources; optionally filter modules
if [[ -n "$INCLUDE_PATTERN" ]]; then
  # Always include main + shared + registry/router + constants
  CORE_FILES=$(ls -1 main.swift Modules/SharedUtilities.swift Modules/ModuleProtocol.swift Modules/ModuleRegistry.swift Modules/EventRouter.swift Modules/Constants.swift 2>/dev/null)
  MOD_FILES=""
  IFS=',' read -r -a REQ_MODS <<< "$INCLUDE_PATTERN"
  for id in "${REQ_MODS[@]}"; do
    # Find matching module file by id substring (case-insensitive)
    LOWER=$(echo "$id" | tr '[:upper:]' '[:lower:]')
    for f in Modules/*Module.swift; do
      NAME=$(basename "$f" | tr '[:upper:]' '[:lower:]')
      if [[ "$NAME" == *"$LOWER"* ]]; then
        MOD_FILES+=" $f"
      fi
    done
  done
  SOURCES="$CORE_FILES $MOD_FILES"
else
  # Only include unified main.swift plus module sources; ignore any legacy main_* files if still present.
  SOURCES="main.swift Preferences.swift $(ls -1 Modules/*.swift)"
fi

echo "Compiling sources: $SOURCES"

swiftc -O -o "$BUILD_DIR/$APP_NAME" $SOURCES \
  -framework Cocoa \
  -framework SwiftUI \
  -framework ApplicationServices \
  -framework UserNotifications \
  -framework ServiceManagement || { echo "Compilation failed"; exit 1; }

# Bundle structure
mkdir -p "$BUILD_DIR/${APP_NAME}.app/Contents/MacOS" "$BUILD_DIR/${APP_NAME}.app/Contents/Resources"

# Basic Info.plist
cat > "$BUILD_DIR/${APP_NAME}.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Needs automation access to control Finder for file operations.</string>
  <key>NSHumanReadableCopyright</key><string>© 2025 Your Name</string>
</dict>
</plist>
PLIST

cp "$BUILD_DIR/$APP_NAME" "$BUILD_DIR/${APP_NAME}.app/Contents/MacOS/"
if [ -f "$BUILD_DIR/${APP_NAME}.icns" ]; then
  cp "$BUILD_DIR/${APP_NAME}.icns" "$BUILD_DIR/${APP_NAME}.app/Contents/Resources/AppIcon.icns"
fi
chmod +x "$BUILD_DIR/${APP_NAME}.app/Contents/MacOS/$APP_NAME"

# Cleanup transient bits (icon artifacts handled by script; nothing to remove here)

echo "✅ Build complete: $BUILD_DIR/${APP_NAME}.app"
