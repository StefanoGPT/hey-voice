#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${VERSION:?Set VERSION to the release version, for example 0.1.0}"
: "${SIGNING_IDENTITY:?Set a Developer ID Application signing identity}"
: "${NOTARY_PROFILE:?Set the name of an existing notarytool keychain profile}"
if [[ "$SIGNING_IDENTITY" != "Developer ID Application:"* ]]; then
    echo "Public binaries require Developer ID Application signing." >&2
    exit 1
fi
export UNIVERSAL=1
scripts/build-app.sh
app_dir="$PWD/dist/Hey Voice.app"
submission="$PWD/dist/HeyVoice-notarization.zip"
ditto -c -k --keepParent "$app_dir" "$submission"
xcrun notarytool submit "$submission" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"
spctl --assess --type execute --verbose=2 "$app_dir"
release="$PWD/dist/HeyVoice-$VERSION-macOS.zip"
ditto -c -k --keepParent "$app_dir" "$release"
shasum -a 256 "$release" > "$release.sha256"
echo "Verified signed release: $release"
