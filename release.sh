#!/bin/bash
# Packages a built Momentum.app into a zip for a GitHub Release, so people can
# download and drag it instead of installing Xcode tools and compiling.
#
#   ./release.sh            # build fresh, then package
#   ./release.sh --skip-build
#
# The app is ad-hoc signed, not notarized — that needs a paid Apple Developer
# ID. Gatekeeper will warn on first launch; see README "Opening it the first
# time". Signing here is still worth doing: it gives the app a stable identity
# so macOS keeps its notification and permission settings between updates.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Momentum"
VERSION="$(grep -m1 'VERSION=' build.sh | cut -d'"' -f2)"
OUT="build"
APP="${OUT}/${APP_NAME}.app"
ZIP="${OUT}/${APP_NAME}-${VERSION}-macos.zip"

if [ "${1:-}" != "--skip-build" ]; then
  echo "▸ Building"
  ./build.sh --no-install --universal
fi

if [ ! -d "$APP" ]; then
  echo "No app at ${APP}. Run ./build.sh first." >&2
  exit 1
fi

echo "▸ Verifying the bundle"
ARCHES="$(lipo -archs "${APP}/Contents/MacOS/${APP_NAME}" 2>/dev/null || echo unknown)"
echo "  arches: ${ARCHES}"
case "$ARCHES" in
  *arm64*x86_64*|*x86_64*arm64*) ;;
  *) echo "  WARNING: not a universal binary — Apple Silicon users would need Rosetta." >&2 ;;
esac
codesign --verify --deep --strict "$APP" 2>/dev/null && echo "  signature ok" \
  || echo "  (ad-hoc signature could not be verified — continuing)"
test -f "${APP}/Contents/MacOS/${APP_NAME}" || { echo "  no executable!" >&2; exit 1; }
test -f "${APP}/Contents/Info.plist"        || { echo "  no Info.plist!" >&2; exit 1; }

echo "▸ Zipping"
rm -f "$ZIP"
# ditto keeps the bundle's symlinks and resource forks intact; plain zip does not.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SIZE="$(du -h "$ZIP" | cut -f1)"
echo "▸ Done: ${PWD}/${ZIP}  (${SIZE})"
echo
echo "Next: create a release and attach that zip —"
echo "  gh release create v${VERSION} \"${ZIP}\" --title \"${APP_NAME} ${VERSION}\" --notes-file RELEASE_NOTES.md"
