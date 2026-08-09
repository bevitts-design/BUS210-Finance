#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SVG="$ROOT_DIR/MissionControl/Assets/AppIcon.svg"
DIST_DIR="$ROOT_DIR/MissionControl/dist"
WORK_DIR="$DIST_DIR/icon-build"
ICONSET_DIR="$WORK_DIR/AppIcon.iconset"
RENDER_DIR="$WORK_DIR/rendered"
MASTER_PNG="$WORK_DIR/AppIcon-master.png"
OUTPUT_ICNS="${1:-$DIST_DIR/BUS210MissionControl.icns}"

case "$WORK_DIR" in
  "$ROOT_DIR/MissionControl/dist/icon-build") ;;
  *) echo "Refusing to clean unexpected icon work directory: $WORK_DIR" >&2; exit 2 ;;
esac

rm -rf "$WORK_DIR"
mkdir -p "$ICONSET_DIR" "$RENDER_DIR" "$(dirname "$OUTPUT_ICNS")"

/usr/bin/qlmanage -t -s 1024 -o "$RENDER_DIR" "$SOURCE_SVG" >/dev/null 2>&1
cp "$RENDER_DIR/AppIcon.svg.png" "$MASTER_PNG"

make_icon() {
  local pixels="$1"
  local filename="$2"
  /usr/bin/sips -z "$pixels" "$pixels" "$MASTER_PNG" --out "$ICONSET_DIR/$filename" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
echo "$OUTPUT_ICNS"
