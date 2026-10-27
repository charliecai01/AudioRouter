#!/bin/bash
# Archives, exports, notarizes, staples and packages AudioRouter into a
# ready-to-distribute signed .dmg. Requires:
#   - The "Developer ID Application" certificate installed (see project.yml).
#   - A stored notarytool credentials profile named "AudioRouter-notary"
#     (xcrun notarytool store-credentials "AudioRouter-notary" --apple-id ... --team-id WV8SAHT65Z)
#
# Usage: ./release.sh

set -euo pipefail
cd "$(dirname "$0")"

TEAM_ID="WV8SAHT65Z"
SIGNING_IDENTITY="Developer ID Application: Jose Sanchez Gonzalez ($TEAM_ID)"
NOTARY_PROFILE="AudioRouter-notary"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/AudioRouter.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/AudioRouter.app"
DMG_PATH="$BUILD_DIR/AudioRouter.dmg"

echo "==> Regenerating Xcode project"
xcodegen generate

echo "==> Cleaning previous build output"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving (Release)"
xcodebuild -project AudioRouter.xcodeproj -scheme AudioRouter -configuration Release \
  archive -archivePath "$ARCHIVE_PATH"

echo "==> Exporting signed .app"
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions.plist

echo "==> Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Building .dmg"
DMG_SRC="$BUILD_DIR/dmg-src"
rm -rf "$DMG_SRC"
mkdir -p "$DMG_SRC"
cp -R "$APP_PATH" "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"
hdiutil create -volname "AudioRouter Installer" -srcfolder "$DMG_SRC" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_SRC"

echo "==> Signing .dmg"
codesign --sign "$SIGNING_IDENTITY" "$DMG_PATH"

echo "==> Zipping .app for notarization"
APP_ZIP="$BUILD_DIR/AudioRouter-app.zip"
rm -f "$APP_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"

echo "==> Submitting .app for notarization"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait \
  || { echo "App notarization failed — inspect with 'xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE'"; exit 1; }

# Notarizing the .app alone doesn't staple it when it's inside a zip/dmg wrapper for
# submission, so staple the .app in place, then rebuild + re-sign the dmg around it,
# then separately notarize+staple the dmg itself (Apple's recommended flow for both).
echo "==> Stapling .app"
xcrun stapler staple "$APP_PATH"

echo "==> Rebuilding .dmg with stapled .app"
rm -rf "$DMG_SRC" "$DMG_PATH"
mkdir -p "$DMG_SRC"
cp -R "$APP_PATH" "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"
hdiutil create -volname "AudioRouter Installer" -srcfolder "$DMG_SRC" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_SRC"
codesign --sign "$SIGNING_IDENTITY" "$DMG_PATH"

echo "==> Submitting .dmg for notarization"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait \
  || { echo "DMG notarization failed — inspect with 'xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE'"; exit 1; }

echo "==> Stapling .dmg"
xcrun stapler staple "$DMG_PATH"

echo "==> Final Gatekeeper check"
spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

echo ""
echo "Done: $DMG_PATH"
