#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PROCESS_NAME="BUS210MissionControl"
BUNDLE_NAME="BUS210 Mission Control"
BUNDLE_ID="edu.endicott.bus210.mission-control"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/MissionControl"
DIST_DIR="$PACKAGE_DIR/dist"
FINAL_APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
PACKAGE_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/bus210-mission-control-package.XXXXXX")"
trap 'rm -rf "$PACKAGE_STAGE"' EXIT
APP_BUNDLE="$PACKAGE_STAGE/$BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PROCESS_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_NAME="BUS210MissionControl.icns"

pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true

swift build --package-path "$PACKAGE_DIR"
BUILD_BINARY="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)/$PROCESS_NAME"

mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
"$ROOT_DIR/script/build_app_icon.sh" "$APP_RESOURCES/$ICON_NAME"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$PROCESS_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundleName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# File Provider-backed folders can attach Finder/provenance metadata that macOS
# rejects inside a code-signed bundle. Remove only bundle extended attributes
# after packaging and before signing; source files are not touched.
/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/xattr -c "$APP_BUNDLE"
/usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -rf "$FINAL_APP_BUNDLE"
mkdir -p "$DIST_DIR"
/usr/bin/ditto --norsrc "$APP_BUNDLE" "$FINAL_APP_BUNDLE"
/usr/bin/xattr -cr "$FINAL_APP_BUNDLE"
/usr/bin/xattr -c "$FINAL_APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$FINAL_APP_BUNDLE"
APP_BUNDLE="$FINAL_APP_BUNDLE"

open_app() {
  BUS210_REPO_ROOT="$ROOT_DIR" /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    BUS210_REPO_ROOT="$ROOT_DIR" lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$PROCESS_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
