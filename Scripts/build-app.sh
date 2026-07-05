#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/Fork.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$ROOT_DIR/Assets/ForkAppIcon.jpg"
ICON_TIFF_DIR="$ROOT_DIR/.build/ForkAppIcon.tiffs"
ICON_TIFF="$ICON_TIFF_DIR/ForkAppIcon.tiff"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-module-cache}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$ROOT_DIR/.build/cache}"
export HOME="${HOME:-$ROOT_DIR/.build/home}"

swift build --disable-sandbox --product ForkApp

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/debug/ForkApp" "$MACOS_DIR/Fork"
chmod +x "$MACOS_DIR/Fork"

if [[ -f "$ICON_SOURCE" ]]; then
  rm -rf "$ICON_TIFF_DIR"
  mkdir -p "$ICON_TIFF_DIR"
  for size in 16 32 128 256 512 1024; do
    sips -s format tiff -z "$size" "$size" "$ICON_SOURCE" --out "$ICON_TIFF_DIR/icon_${size}.tiff" >/dev/null
  done
  tiffutil -cat \
    "$ICON_TIFF_DIR/icon_16.tiff" \
    "$ICON_TIFF_DIR/icon_32.tiff" \
    "$ICON_TIFF_DIR/icon_128.tiff" \
    "$ICON_TIFF_DIR/icon_256.tiff" \
    "$ICON_TIFF_DIR/icon_512.tiff" \
    "$ICON_TIFF_DIR/icon_1024.tiff" \
    -out "$ICON_TIFF" >/dev/null 2>&1
  tiff2icns "$ICON_TIFF" "$RESOURCES_DIR/ForkAppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Fork</string>
  <key>CFBundleExecutable</key>
  <string>Fork</string>
  <key>CFBundleIconFile</key>
  <string>ForkAppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>app.fork.prototype</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Fork</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
