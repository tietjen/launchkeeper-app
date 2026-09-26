#!/usr/bin/env bash
# LaunchKeeper release build — universal app, Developer ID signed, notarized
# and stapled (app and DMG), Sparkle-signed DMG, appcast.xml for the feed.
#
#   Scripts/release.sh <version> [--no-notarize] [--publish] [--notes <file>]
#
#   <version>       e.g. 0.1.0 — must match the VERSION file
#   --no-notarize   rehearsal: skip Apple's notary service (DMG not distributable)
#   --publish       maintainer-local path: tag v<version>, push it to GitHub and
#                   create the GitHub release with the assets (needs `gh`).
#                   Public releases are normally built by
#                   .github/workflows/release.yml on the tag instead.
#   --notes FILE    release notes (Markdown); default: the version's section
#                   of CHANGELOG.md
#
# Credentials — never printed, never written to the repo:
#   notarization  APPLE_ID + APPLE_APP_PASSWORD + APPLE_TEAM_ID (CI), else the
#                 notarytool keychain profile $NOTARY_PROFILE (default "SparkMenu")
#   Sparkle key   SPARKLE_ED_PRIVATE_KEY (CI), else Vaultwarden via rbw:
#                 "Sparkle EdDSA Private Key (SparkMenu)" — one key for both apps
#
# Output in dist/release/: LaunchKeeper-<version>.dmg, appcast.xml, SHA256SUMS.
# Rules: refuses a dirty tree and a version mismatch; notarization counts only
# when Apple's status line says Accepted (the exit code does not prove it).
set -euo pipefail

VERSION="${1:-}"; shift || true
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "usage: $0 <version> [--no-notarize] [--publish] [--notes <file>]" >&2; exit 2; }
NOTARIZE=1; PUBLISH=0; NOTES_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-notarize) NOTARIZE=0 ;;
        --publish)     PUBLISH=1 ;;
        --notes)       NOTES_FILE="${2:?--notes needs a file}"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
NOTARY_PROFILE="${NOTARY_PROFILE:-SparkMenu}"
SPARKLE_VAULT_ITEM="Sparkle EdDSA Private Key (SparkMenu)"
GITHUB_REPO="tietjen/launchkeeper-app"
TAG="v$VERSION"
OUT="$ROOT/dist/release"
APP="$ROOT/dist/LaunchKeeper.app"
DMG="$OUT/LaunchKeeper-$VERSION.dmg"
SIGN_UPDATE="$ROOT/.build/artifacts/sparkle/Sparkle/bin/sign_update"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Jan Tietjen (Y2LTPLFG6D)}"

echo "==> Preflight"
[[ -z "$(git status --porcelain)" ]] || { echo "working tree is not clean — commit or stash first" >&2; exit 1; }
[[ "$(tr -d '[:space:]' < VERSION)" == "$VERSION" ]] || { echo "VERSION file does not say $VERSION" >&2; exit 1; }
grep -q "^## \[$VERSION\]" CHANGELOG.md || { echo "CHANGELOG.md has no section [$VERSION]" >&2; exit 1; }
[[ -x "$SIGN_UPDATE" ]] || swift package resolve >/dev/null

# Release notes: the CHANGELOG section of this version, unless given.
if [[ -n "$NOTES_FILE" ]]; then
    NOTES_MD="$(cat "$NOTES_FILE")"
else
    NOTES_MD="$(awk -v v="$VERSION" '
        $0 ~ "^## \\[" v "\\]" { on = 1; next }
        on && /^## \[/ { exit }
        on { print }' CHANGELOG.md)"
fi

echo "==> Tests"
swift test 2>&1 | grep -E "Executed [0-9]+ tests" | tail -1

echo "==> Build universal app"
Scripts/build-app.sh --universal --version "$VERSION"
lipo -archs "$APP/Contents/MacOS/LaunchKeeper" | grep -qE "x86_64 arm64|arm64 x86_64" \
    || { echo "app binary is not universal" >&2; exit 1; }
lipo -archs "$APP/Contents/MacOS/LaunchKeeperHelper" | grep -qE "x86_64 arm64|arm64 x86_64" \
    || { echo "helper binary is not universal" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"

# Submits a file to Apple's notary service and staples the ticket.
# The status line is the verdict: `notarytool --wait` exits 0 on "Invalid" too.
notarize() {
    local file="$1" upload="$1" log="$OUT/notarytool-$(basename "$1").log"
    if [[ -d "$file" ]]; then
        upload="$OUT/notarize-upload.zip"
        ditto -c -k --keepParent "$file" "$upload"
    fi
    if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
        xcrun notarytool submit "$upload" --wait --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID" | tee "$log"
    else
        xcrun notarytool submit "$upload" --wait --keychain-profile "$NOTARY_PROFILE" | tee "$log"
    fi
    [[ "$upload" == "$file" ]] || rm -f "$upload"
    grep -q '^  status: Accepted' "$log" || { echo "notarization NOT accepted — see $log" >&2; exit 1; }
    xcrun stapler staple "$file"
    xcrun stapler validate "$file"
}

if [[ $NOTARIZE -eq 1 ]]; then
    echo "==> Notarize and staple the app"
    notarize "$APP"
fi

echo "==> DMG"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/LaunchKeeper.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "LaunchKeeper $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
if [[ $NOTARIZE -eq 1 ]]; then
    echo "==> Notarize and staple the DMG"
    notarize "$DMG"
    STATUS="notarized"
else
    STATUS="NOT notarized (rehearsal)"
fi

echo "==> Sparkle signature"
# The key goes through a 0600 temp file (no keychain ACL prompts in CI) that
# is removed on exit; it is never echoed.
KEY_FILE="$STAGE/sparkle.key"
( umask 077
  if [[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
      printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | tr -d '[:space:]%' > "$KEY_FILE"
  else
      rbw get "$SPARKLE_VAULT_ITEM" | tr -d '[:space:]%' > "$KEY_FILE"
  fi )
[[ -s "$KEY_FILE" ]] || { echo "no Sparkle key (SPARKLE_ED_PRIVATE_KEY or rbw '$SPARKLE_VAULT_ITEM')" >&2; exit 1; }
SIGNATURE="$("$SIGN_UPDATE" --ed-key-file "$KEY_FILE" "$DMG")"
rm -f "$KEY_FILE"
ED_SIGNATURE="$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' <<<"$SIGNATURE")"
LENGTH="$(sed -n 's/.*length="\([^"]*\)".*/\1/p' <<<"$SIGNATURE")"
[[ -n "$ED_SIGNATURE" && -n "$LENGTH" ]] || { echo "cannot parse sign_update output" >&2; exit 1; }

echo "==> appcast.xml"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
printf '%s\n' "$NOTES_MD" > "$OUT/release-notes.md"
python3 - "$OUT/appcast.xml" "$VERSION" "$BUILD" "$LENGTH" "$ED_SIGNATURE" "$GITHUB_REPO" "$OUT/release-notes.md" <<'PY'
import html, sys
from email.utils import formatdate
out, version, build, length, signature, repo, notes_file = sys.argv[1:8]
notes = open(notes_file).read().strip()
# Release notes as simple HTML: headings and bullet lists are all CHANGELOG uses.
lines, in_list = [], False
for raw in notes.splitlines():
    line = raw.rstrip()
    if line.startswith("- "):
        if not in_list: lines.append("<ul>"); in_list = True
        lines.append("<li>" + html.escape(line[2:]) + "</li>")
        continue
    if line.startswith("  ") and in_list and lines:
        lines[-1] = lines[-1][:-5] + " " + html.escape(line.strip()) + "</li>"
        continue
    if in_list: lines.append("</ul>"); in_list = False
    if line.startswith("### "): lines.append("<h3>" + html.escape(line[4:]) + "</h3>")
    elif line: lines.append("<p>" + html.escape(line) + "</p>")
if in_list: lines.append("</ul>")
url = f"https://github.com/{repo}/releases/download/v{version}/LaunchKeeper-{version}.dmg"
feed = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>LaunchKeeper</title>
    <link>https://github.com/{repo}</link>
    <description>LaunchKeeper update feed</description>
    <language>de</language>
    <item>
      <title>LaunchKeeper {version}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/{repo}/releases/tag/v{version}</sparkle:fullReleaseNotesLink>
      <description><![CDATA[{"".join(lines)}]]></description>
      <enclosure url="{url}" length="{length}" type="application/octet-stream" sparkle:edSignature="{signature}"/>
    </item>
  </channel>
</rss>
"""
open(out, "w").write(feed)
PY

( cd "$OUT" && shasum -a 256 "LaunchKeeper-$VERSION.dmg" > SHA256SUMS )
rm -f "$OUT"/notarytool-*.log
echo "  $DMG ($STATUS, build $BUILD)"
cat "$OUT/SHA256SUMS"

if [[ $PUBLISH -eq 0 ]]; then
    echo "==> Done (not published). Publish: push tag $TAG to GitHub (CI) or rerun with --publish"
    exit 0
fi
[[ $NOTARIZE -eq 1 ]] || { echo "refusing to publish a DMG that is not notarized" >&2; exit 1; }

echo "==> Tag $TAG and GitHub release"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || git tag -a "$TAG" -m "LaunchKeeper $TAG"
git push github HEAD:main "$TAG"
gh release create "$TAG" --repo "$GITHUB_REPO" --title "LaunchKeeper $VERSION" \
    --notes-file "$OUT/release-notes.md" \
    "$DMG" "$OUT/appcast.xml" "$OUT/SHA256SUMS"
echo "==> Published: https://github.com/$GITHUB_REPO/releases/tag/$TAG"
