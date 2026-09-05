#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

app_dir="$PWD/dist/Hey Voice.app"
if [[ -f "$app_dir/Contents/MacOS/HeyVoice" ]] && /usr/sbin/lsof -t "$app_dir/Contents/MacOS/HeyVoice" >/dev/null 2>&1; then
    echo "Quit the running Hey Voice preview before rebuilding it." >&2
    exit 1
fi

# Native architecture by default. UNIVERSAL=1 builds arm64 + x86_64.
build_args=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    build_args+=(--arch arm64 --arch x86_64)
fi
swift build "${build_args[@]}"
bin_dir="$(swift build "${build_args[@]}" --show-bin-path)"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/HeyVoice" "$app_dir/Contents/MacOS/HeyVoice"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Resources/VoiceOrb.png "$app_dir/Contents/Resources/VoiceOrb.png"
swift scripts/make-icon.swift "$PWD/dist/HeyVoice.iconset" "$PWD/Resources/VoiceOrb.png"
iconutil -c icns "$PWD/dist/HeyVoice.iconset" -o "$app_dir/Contents/Resources/HeyVoice.icns"
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$app_dir/Contents/Info.plist"
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set CFBundleVersion $BUILD_NUMBER" "$app_dir/Contents/Info.plist"
fi
/usr/bin/codesign --force --options runtime --entitlements Resources/HeyVoice.entitlements \
    --sign "${SIGNING_IDENTITY:--}" "$app_dir"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_dir"
echo "Built: $app_dir"
echo "For microphone permission, open the .app bundle, not the raw Swift executable."
