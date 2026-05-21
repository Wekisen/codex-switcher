#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Codex Switcher"
BUILD_DIR="$ROOT_DIR/.build/debug"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/Assets/CodexSwitcher.iconset"
ICNS_PATH="$ROOT_DIR/Assets/CodexSwitcher.icns"

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
swift build --disable-sandbox

swift scripts/generate-icon.swift

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/CodexSwitcher" "$MACOS_DIR/CodexSwitcher"
cp "$ICNS_PATH" "$RESOURCES_DIR/CodexSwitcher.icns"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CodexSwitcher</string>
  <key>CFBundleIdentifier</key>
  <string>com.codexswitcher.app</string>
  <key>CFBundleName</key>
  <string>Codex Switcher</string>
  <key>CFBundleDisplayName</key>
  <string>Codex Switcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>CodexSwitcher</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.1</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>SMPrivilegedExecutables</key>
  <dict/>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Codex Switcher uses localhost to receive the OpenAI login callback.</string>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/CodexSwitcher"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
