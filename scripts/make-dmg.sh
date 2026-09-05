#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# != 2 || ! -d "$1/Contents" ]]; then
    echo 'Usage: scripts/make-dmg.sh <Hey Voice.app> <output.dmg>' >&2
    exit 1
fi
app_source="$1"
dmg_output="$2"
mkdir -p dist
staging_dir="$(mktemp -d "$PWD/dist/dmg-stage.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
ditto "$app_source" "$staging_dir/Hey Voice.app"
ln -s /Applications "$staging_dir/Applications"
mkdir -p "$staging_dir/.background"
cp Resources/VoiceOrb.png "$staging_dir/.background/VoiceOrb.png"
cp Resources/Install.html "$staging_dir/Read me first.html"
cp CREDITS.md "$staging_dir/Credits.txt"
hdiutil create -volname 'Hey Voice' -srcfolder "$staging_dir" \
    -fs HFS+ -format UDZO -ov "$dmg_output"
hdiutil verify "$dmg_output"
