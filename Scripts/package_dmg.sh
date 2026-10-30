#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Scripts/Info.plist)}"
VERSION="${VERSION#v}"
ASSET_VERSION="${APP_VERSION:-v$VERSION}"
BUILD="${APP_BUILD:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Scripts/Info.plist)}"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
    APP_VERSION="$VERSION" APP_BUILD="$BUILD" ./Scripts/package_app.sh release
fi

SOURCE="dist/dmg-source"
OUTPUT="dist/Finances-${ASSET_VERSION}.dmg"

rm -rf "$SOURCE"
rm -f "$OUTPUT"
mkdir -p "$SOURCE"
cp -R "dist/Финансы.app" "$SOURCE/"

create-dmg \
    --volname "Финансы ${VERSION}" \
    --volicon "Assets/AppIcon.icns" \
    --background "$PWD/Assets/dmg-background.png" \
    --window-pos 200 120 \
    --window-size 660 420 \
    --text-size 13 \
    --icon-size 128 \
    --icon "Финансы.app" 180 190 \
    --app-drop-link 480 190 \
    --hide-extension "Финансы.app" \
    --no-internet-enable \
    "$OUTPUT" "$SOURCE"

rm -rf "$SOURCE"
echo "✓ DMG: $OUTPUT"
