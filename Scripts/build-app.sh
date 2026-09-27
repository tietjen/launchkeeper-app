#!/bin/bash
# Build LaunchKeeper.app from the SwiftPM package (no Xcode project).
#   Scripts/build-app.sh [--version X.Y.Z] [--universal] [--no-sign]
# The version defaults to the VERSION file (the release script checks the tag
# against it); the build number is the commit count, which Sparkle compares.
# LAUNCHKEEPER_KIT_PATH=../launchkeeper builds against a local kit checkout.
# Lessons from SparkMenu (wiki "Swift & macOS Development"): patch the SwiftPM
# resource accessor (Bundle.main.bundleURL misses Contents/Resources on other
# Macs), sign inside-out without --deep, hardened runtime + timestamp.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
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
# Sparkle (Phase 8): the feed is the appcast of the latest GitHub release;
# the public key is SparkMenu's (TJ, 2026-09-26: one EdDSA key for both apps,
# private half in Vaultwarden "Sparkle EdDSA Private Key (SparkMenu)").
FEED_URL="https://github.com/tietjen/launchkeeper-app/releases/latest/download/appcast.xml"
SPARKLE_PUBLIC_KEY="Rpi6AeS/KJGAqiLQJaMhCgL/78B9KDxkP71QyV4IoMw="
APP_NAME="LaunchKeeper"
BUNDLE_ID="de.paranoidsecurity.LaunchKeeper"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "==> swift build (release ${ARCHS[*]})"
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"
# Resource accessor patch, then rebuild so the patched accessor is compiled in.
for ACCESSOR in $(find .build -path "*release/LaunchKeeperGUI.build/DerivedSources/resource_bundle_accessor.swift" 2>/dev/null); do
  if ! grep -q "Bundle.main.resourceURL ??" "$ACCESSOR"; then
    sed -i '' 's|Bundle\.main\.bundleURL|(Bundle.main.resourceURL ?? Bundle.main.bundleURL)|g' "$ACCESSOR"
    PATCHED=1
  fi
done
if [ "${PATCHED:-0}" = 1 ]; then swift build -c release "${ARCHS[@]}"; fi

echo "==> assemble $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
# The SwiftPM product is LaunchKeeperGUI (see Package.swift); the bundle keeps "LaunchKeeper".
cp "$BIN/LaunchKeeperGUI" "$APP/Contents/MacOS/$APP_NAME"
# Sparkle.framework (universal in the xcframework) with its Updater.app and
# XPC services. SwiftPM sets no rpath for an embedded framework — add it.
SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[ -d "$SPARKLE_FRAMEWORK" ] || { echo "Sparkle.framework missing — run: swift package resolve" >&2; exit 1; }
cp -R "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$APP_NAME"
# Privileged helper (Phase 5): binary next to the app's, launchd plist where
# SMAppService.daemon(plistName:) looks for it. BundleProgram is relative to
# the bundle, so the app may live anywhere — /Applications is recommended.
HELPER_ID="de.paranoidsecurity.LaunchKeeper.Helper"
cp "$BIN/LaunchKeeperHelper" "$APP/Contents/MacOS/LaunchKeeperHelper"
mkdir -p "$APP/Contents/Library/LaunchDaemons"
cat > "$APP/Contents/Library/LaunchDaemons/$HELPER_ID.plist" <<HPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$HELPER_ID</string>
  <key>BundleProgram</key><string>Contents/MacOS/LaunchKeeperHelper</string>
  <key>MachServices</key><dict><key>$HELPER_ID</key><true/></dict>
  <key>AssociatedBundleIdentifiers</key><array><string>$BUNDLE_ID</string></array>
</dict>
</plist>
HPLIST
# Only the app's own resource bundle — a glob would also ship stale bundles
# of earlier target names left in .build.
cp -R "$BIN/launchkeeper-app_LaunchKeeperGUI.bundle" "$APP/Contents/Resources/"
# Localization: the String Catalog (keys = German source text) compiled into
# de.lproj/en.lproj of the MAIN bundle — SwiftUI's Text and String(localized:)
# look there by default. Scripts/localize.sh keeps the catalog complete.
xcrun xcstringstool compile Localization/Localizable.xcstrings --output-directory "$APP/Contents/Resources"
# App icon: no asset catalog without Xcode — iconutil turns the .iconset into .icns.
iconutil -c icns Assets/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
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
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>de</string><string>en</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Jan Tietjen — MIT License</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>SUFeedURL</key><string>$FEED_URL</string>
  <key>SUPublicEDKey</key><string>$SPARKLE_PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key><true/>
</dict>
</plist>
PLIST

# Inside-out in both modes: a nested binary left unsigned fails the outer
# signature ("code object is not signed at all"). --no-sign signs ad hoc
# (CI, no certificate) — no timestamp, no Developer ID.
if [ "$SIGN" = 1 ]; then
  echo "==> codesign ($IDENTITY), inside-out, hardened runtime"
  SIGN_ARGS=(--force --options runtime --timestamp --sign "$IDENTITY")
else
  echo "==> codesign ad hoc, inside-out (--no-sign)"
  SIGN_ARGS=(--force --options runtime --sign -)
fi
# The helper's identifier is what the app's XPC requirement checks.
codesign "${SIGN_ARGS[@]}" --identifier "$HELPER_ID" "$APP/Contents/MacOS/LaunchKeeperHelper"
# Sparkle's parts first (innermost out), all re-signed with our identity,
# so no library-validation exception is needed.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for PART in "$SPARKLE/XPCServices/Downloader.xpc" "$SPARKLE/XPCServices/Installer.xpc" \
            "$SPARKLE/Updater.app" "$SPARKLE/Autoupdate" "$APP/Contents/Frameworks/Sparkle.framework"; do
  codesign "${SIGN_ARGS[@]}" "$PART"
done
codesign "${SIGN_ARGS[@]}" "$APP/Contents/MacOS/$APP_NAME"
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "==> $APP ($VERSION, build $BUILD)"
