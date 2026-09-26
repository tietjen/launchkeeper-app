#!/bin/bash
# Build LaunchKeeper.app from the SwiftPM package (no Xcode project).
#   Scripts/build-app.sh [--version X.Y.Z] [--universal] [--no-sign]
# LAUNCHKEEPER_KIT_PATH=../launchkeeper builds against a local kit checkout.
# Lessons from SparkMenu (wiki "Swift & macOS Development"): patch the SwiftPM
# resource accessor (Bundle.main.bundleURL misses Contents/Resources on other
# Macs), sign inside-out without --deep, hardened runtime + timestamp.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
ARCHS=(--arch arm64)
SIGN=1
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --universal) ARCHS=(--arch arm64 --arch x86_64); shift ;;
    --no-sign) SIGN=0; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Jan Tietjen (Y2LTPLFG6D)}"
APP_NAME="LaunchKeeper"
BUNDLE_ID="de.paranoidsecurity.LaunchKeeper"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "==> swift build (release ${ARCHS[*]})"
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"
# Resource accessor patch, then rebuild so the patched accessor is compiled in.
for ACCESSOR in $(find .build -path "*release/LaunchKeeper.build/DerivedSources/resource_bundle_accessor.swift" 2>/dev/null); do
  if ! grep -q "Bundle.main.resourceURL ??" "$ACCESSOR"; then
    sed -i '' 's|Bundle\.main\.bundleURL|(Bundle.main.resourceURL ?? Bundle.main.bundleURL)|g' "$ACCESSOR"
    PATCHED=1
  fi
done
if [ "${PATCHED:-0}" = 1 ]; then swift build -c release "${ARCHS[@]}"; fi

echo "==> assemble $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
for BUNDLE in "$BIN"/*.bundle; do [ -e "$BUNDLE" ] && cp -R "$BUNDLE" "$APP/Contents/Resources/"; done
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>LaunchKeeper</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleDevelopmentRegion</key><string>de</string>
  <key>CFBundleLocalizations</key><array><string>de</string><string>en</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Jan Tietjen — MIT License</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

if [ "$SIGN" = 1 ]; then
  echo "==> codesign ($IDENTITY), inside-out, hardened runtime"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/MacOS/$APP_NAME"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  codesign --force --sign - "$APP"
fi
echo "==> $APP ($VERSION, build $BUILD)"
