#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
BUILD_DIR="/private/tmp/FusionLab-build-$(id -u)"
mkdir -p "$BUILD_DIR"
chmod 700 "$BUILD_DIR"
BUILD_SOURCE_DIR="$(python3 "$ROOT_DIR/script/snapshot_sources.py" "$ROOT_DIR" "$BUILD_DIR")"
swift build --package-path "$BUILD_SOURCE_DIR" --scratch-path "$BUILD_DIR"
BIN_DIR="$(swift build --package-path "$BUILD_SOURCE_DIR" --scratch-path "$BUILD_DIR" --show-bin-path)"
# Compile a stable local snapshot: FileProvider may update source timestamps
# while hydrating files in Documents, which Swift correctly rejects mid-build.
TEST_SOURCES="$(mktemp -d "$BUILD_DIR/TestSources.XXXXXX")"
trap 'rm -rf "$TEST_SOURCES"' EXIT
mkdir -p "$TEST_SOURCES/Sources/FusionLab"
ditto --norsrc --noextattr "$BUILD_SOURCE_DIR/Sources/FusionLab/Models" "$TEST_SOURCES/Sources/FusionLab/Models"
ditto --norsrc --noextattr "$BUILD_SOURCE_DIR/Sources/FusionLab/Services" "$TEST_SOURCES/Sources/FusionLab/Services"
mkdir -p "$TEST_SOURCES/Sources/FusionLab/Views"
ditto --norsrc --noextattr "$BUILD_SOURCE_DIR/Sources/FusionLab/Views/PTTButton.swift" "$TEST_SOURCES/Sources/FusionLab/Views/PTTButton.swift"
ditto --norsrc --noextattr "$BUILD_SOURCE_DIR/Sources/FusionLab/Views/RadioLCDView.swift" "$TEST_SOURCES/Sources/FusionLab/Views/RadioLCDView.swift"
ditto --norsrc --noextattr Tests "$TEST_SOURCES/Tests"
# Apple's Command Line Tools omit XCTest. This runner uses production sources.
swiftc -parse-as-library -o "$TEST_SOURCES/FusionLabSelfTest" \
 -I "$BIN_DIR" -Xcc "-fmodule-map-file=$BIN_DIR/YSFCodec.build/module.modulemap" \
 -Xcc "-fmodule-map-file=$BIN_DIR/MD380Codec.build/module.modulemap" \
 -Xcc -I -Xcc "$PWD/Sources/YSFCodec/include" \
 "$TEST_SOURCES"/Sources/FusionLab/Models/*.swift "$TEST_SOURCES"/Sources/FusionLab/Services/*.swift "$TEST_SOURCES"/Sources/FusionLab/Views/*.swift \
 "$TEST_SOURCES"/Tests/FusionLabTests/*.swift "$BIN_DIR"/YSFCodec.build/*.o "$BIN_DIR"/MD380Codec.build/*.o -lc++
"$TEST_SOURCES/FusionLabSelfTest"
