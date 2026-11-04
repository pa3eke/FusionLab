#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
BUILD_DIR="/private/tmp/FusionLab-build-$(id -u)"
BUILD_SOURCE_DIR="$(python3 script/snapshot_sources.py "$ROOT_DIR" "$BUILD_DIR")"
swift build --package-path "$BUILD_SOURCE_DIR" --scratch-path "$BUILD_DIR"
BIN_DIR="$(swift build --package-path "$BUILD_SOURCE_DIR" --scratch-path "$BUILD_DIR" --show-bin-path)"
PROBE_APP="/private/tmp/FusionLab-XKeys-Test.app"
PROBE_SOURCES="$(mktemp -d "$BUILD_DIR/XKeysProbe.XXXXXX")"
trap 'rm -rf "$PROBE_SOURCES"' EXIT
ditto --norsrc --noextattr script/xkeys_hardware_probe.swift "$PROBE_SOURCES/main.swift"
mkdir -p "$PROBE_APP/Contents/MacOS"
swiftc -parse-as-library -o "$PROBE_APP/Contents/MacOS/FusionLabXKeysTest" \
 -I "$BIN_DIR" -Xcc "-fmodule-map-file=$BIN_DIR/YSFCodec.build/module.modulemap" \
 -Xcc "-fmodule-map-file=$BIN_DIR/MD380Codec.build/module.modulemap" \
 -Xcc -I -Xcc "$BUILD_SOURCE_DIR/Sources/YSFCodec/include" \
 "$BUILD_SOURCE_DIR"/Sources/FusionLab/Models/*.swift "$BUILD_SOURCE_DIR"/Sources/FusionLab/Services/*.swift \
 "$PROBE_SOURCES/main.swift" "$BIN_DIR"/YSFCodec.build/*.o "$BIN_DIR"/MD380Codec.build/*.o -lc++
cat > "$PROBE_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>FusionLabXKeysTest</string><key>CFBundleIdentifier</key><string>nl.pa3eke.FusionLab.XKeysTest</string><key>CFBundleName</key><string>FusionLab X-keys test</string><key>CFBundlePackageType</key><string>APPL</string><key>NSPrincipalClass</key><string>NSApplication</string></dict></plist>
PLIST
codesign --force --sign - "$PROBE_APP"
if [[ "${1:-}" == --build-only ]]; then echo "$PROBE_APP"; else "$PROBE_APP/Contents/MacOS/FusionLabXKeysTest"; fi
