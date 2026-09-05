#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${VERSION:?Set VERSION, for example 0.1.0}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
    echo 'VERSION must be a version number, optionally followed by a prerelease label.' >&2
    exit 1
fi
# Community builds never use a personal signing certificate or Apple account.
export SIGNING_IDENTITY=-
export UNIVERSAL=1
scripts/build-app.sh
app_dir="$PWD/dist/Hey Voice.app"
signature="$(codesign -dvv "$app_dir" 2>&1)"
if ! [[ "$signature" == *'Signature=adhoc'* ]] || [[ "$signature" == *'Authority='* ]]; then
    echo 'Expected an ad-hoc signature without a personal signing identity.' >&2
    exit 1
fi
release_base="HeyVoice-$VERSION-macOS"
scripts/make-dmg.sh "$app_dir" "$PWD/dist/$release_base.dmg"
ditto -c -k --keepParent "$app_dir" "$PWD/dist/$release_base.zip"
(
    cd dist
    shasum -a 256 "$release_base.dmg" "$release_base.zip" > "$release_base.sha256"
)
echo "Community preview: dist/$release_base.dmg"
echo 'Ad-hoc signed; not notarized by Apple. Read docs/INSTALL.md before distributing.'
