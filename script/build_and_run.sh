#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
BUILD_DIR="/private/tmp/FusionLab-build-$(id -u)"
mkdir -p "$BUILD_DIR"
chmod 700 "$BUILD_DIR"
BUILD_SOURCE_DIR="$(python3 "$ROOT_DIR/script/snapshot_sources.py" "$ROOT_DIR" "$BUILD_DIR")"
case "$MODE" in run|--debug|--logs|--telemetry|--verify|--build-only) ;; *) echo "usage: $0 [--debug|--logs|--telemetry|--verify|--build-only]"; exit 2;; esac
APP_BUNDLE="$BUILD_DIR/FusionLab.app"
if [[ "$MODE" == --build-only ]]; then
 if pgrep -x FusionLab >/dev/null; then APP_BUNDLE="$BUILD_DIR/FusionLab-next.app"; fi
else
 pkill -x FusionLab >/dev/null 2>&1 || true
fi
swift build --package-path "$BUILD_SOURCE_DIR" --scratch-path "$BUILD_DIR"
BINARY="$(swift build --package-path "$BUILD_SOURCE_DIR" --scratch-path "$BUILD_DIR" --show-bin-path)/FusionLab"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp -X "$BINARY" "$APP_BUNDLE/Contents/MacOS/FusionLab"
mkdir -p "$APP_BUNDLE/Contents/Resources"
ditto --norsrc --noextattr "$(dirname "$BINARY")/FusionLab_FusionLab.bundle" "$APP_BUNDLE/Contents/Resources/FusionLab_FusionLab.bundle"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FusionLab</string>
<key>CFBundleIdentifier</key><string>nl.pa3eke.FusionLab</string>
<key>CFBundleName</key><string>FusionLab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.9</string>
<key>CFBundleVersion</key><string>24</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSMicrophoneUsageDescription</key><string>FusionLab gebruikt de microfoon voor de niveautest en voor spraak tijdens PTT-zenden.</string>
<key>NSLocalNetworkUsageDescription</key><string>FusionLab verbindt met jouw AMBEserver voor digitale spraak.</string>
</dict></plist>
PLIST
# Finder may attach presentation metadata to a previously opened local bundle.
# Remove only those two forbidden signing attributes from our own build output.
xattr -dr com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP_BUNDLE" 2>/dev/null || true
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
if [[ "$MODE" != --build-only ]]; then
 # Documents can be managed by FileProvider, which reintroduces FinderInfo when
 # opening a bundle. Run a local copy from the user's Applications directory.
 INSTALLED_APP="$HOME/Applications/FusionLab.app"
 mkdir -p "$HOME/Applications"
 ditto --norsrc --noextattr "$APP_BUNDLE" "$INSTALLED_APP"
 xattr -dr com.apple.FinderInfo "$INSTALLED_APP" 2>/dev/null || true
 xattr -dr com.apple.ResourceFork "$INSTALLED_APP" 2>/dev/null || true
 codesign --force --sign - "$INSTALLED_APP"
 codesign --verify --deep --strict "$INSTALLED_APP"
 APP_BUNDLE="$INSTALLED_APP"
fi
case "$MODE" in
 --build-only) echo "$APP_BUNDLE";;
 --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/FusionLab";;
 --logs|--telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "FusionLab"';;
 --verify) open -n "$APP_BUNDLE"; sleep 1; pgrep -x FusionLab >/dev/null;;
 run) open -n "$APP_BUNDLE";;
esac
