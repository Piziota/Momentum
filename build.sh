#!/bin/bash
# Builds Momentum.app from source using the Command Line Tools (no Xcode needed).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Momentum"
BUNDLE_ID="com.piyush.momentum"
VERSION="1.0"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos13.0"

OUT="build"
APP="${OUT}/${APP_NAME}.app"
MACOS_DIR="${APP}/Contents/MacOS"
RES_DIR="${APP}/Contents/Resources"

echo "▸ Cleaning"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo "▸ Compiling (${TARGET})"
swiftc \
  -parse-as-library \
  -target "$TARGET" \
  -sdk "$SDK" \
  -O \
  -framework SwiftUI -framework AppKit -framework UserNotifications -framework Carbon \
  -o "${MACOS_DIR}/${APP_NAME}" \
  Sources/*.swift

echo "▸ Writing Info.plist"
cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSSupportsSuddenTermination</key><false/>
  <key>NSHumanReadableCopyright</key><string>Personal build</string>
</dict>
</plist>
PLIST

echo "▸ Generating app icon"
make_icon() {
  local tmp="${OUT}/icon"
  rm -rf "$tmp" && mkdir -p "$tmp/AppIcon.iconset"
  swiftc -target "$TARGET" -sdk "$SDK" -o "$tmp/makeicon" tools/MakeIcon.swift
  "$tmp/makeicon" "$tmp/icon_1024.png"
  for s in 16 32 64 128 256 512 1024; do
    sips -z $s $s "$tmp/icon_1024.png" --out "$tmp/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  done
  # Retina variants that iconutil expects.
  cp "$tmp/AppIcon.iconset/icon_32x32.png"     "$tmp/AppIcon.iconset/icon_16x16@2x.png"
  cp "$tmp/AppIcon.iconset/icon_64x64.png"     "$tmp/AppIcon.iconset/icon_32x32@2x.png"
  cp "$tmp/AppIcon.iconset/icon_256x256.png"   "$tmp/AppIcon.iconset/icon_128x128@2x.png"
  cp "$tmp/AppIcon.iconset/icon_512x512.png"   "$tmp/AppIcon.iconset/icon_256x256@2x.png"
  cp "$tmp/AppIcon.iconset/icon_1024x1024.png" "$tmp/AppIcon.iconset/icon_512x512@2x.png"
  rm -f "$tmp/AppIcon.iconset/icon_64x64.png" "$tmp/AppIcon.iconset/icon_1024x1024.png"
  iconutil -c icns "$tmp/AppIcon.iconset" -o "${RES_DIR}/AppIcon.icns"
}
make_icon >/dev/null 2>&1 && echo "  icon ok" || echo "  (icon step skipped)"

echo "▸ Signing (ad-hoc, so notifications work)"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (ad-hoc signing skipped)"

echo "▸ Done: ${PWD}/${APP}"

# Install into /Applications.
# Everything above succeeded (set -e), so the app being replaced is always a good build.
# Pass --no-install to build without touching the installed copy.
if [ "${1:-}" = "--no-install" ]; then
  echo "▸ Skipping install (--no-install)"
  exit 0
fi

INSTALLED="/Applications/${APP_NAME}.app"
echo "▸ Installing to ${INSTALLED}"

WAS_RUNNING=0
if pgrep -x "$APP_NAME" >/dev/null; then
  WAS_RUNNING=1
  echo "  quitting the running copy"
  osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x "$APP_NAME" >/dev/null || break
    sleep 0.3
  done
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 0.5
fi

# Stage next to the target so the swap is quick, then move the old one aside
# and only delete it once the new one is in place.
STAGING="/Applications/.${APP_NAME}.new"
rm -rf "$STAGING"
cp -R "$APP" "$STAGING"
codesign --force --deep --sign - "$STAGING" 2>/dev/null || true

OLD="/Applications/.${APP_NAME}.old"
rm -rf "$OLD"
[ -d "$INSTALLED" ] && mv "$INSTALLED" "$OLD"

if mv "$STAGING" "$INSTALLED"; then
  rm -rf "$OLD"
  echo "  installed"
  if [ "$WAS_RUNNING" = "1" ]; then
    open "$INSTALLED"
    echo "  relaunched"
  fi
else
  # Put the working copy back rather than leaving nothing in /Applications.
  [ -d "$OLD" ] && mv "$OLD" "$INSTALLED"
  echo "  install failed — the previous version is still in place" >&2
  exit 1
fi

# Explicit, so the script never inherits a non-zero status from the
# "was it running?" test above.
exit 0
