#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: $0 1.0.0}"
SCHEME="DevReader"
PROJECT="DevReader.xcodeproj"
DEST="platform=macOS,arch=arm64"
ARCHIVE_PATH="build/DevReader-$VERSION.xcarchive"
APP_EXPORT="build/DevReader-$VERSION.app"
DMG="build/DevReader-$VERSION.dmg"

# Configuration (fill these in)
APPLE_ID="you@appleid.com"             # <-- fill
TEAM_ID="ABCDE12345"                  # <-- fill
APP_SPEC="com.your.bundleid"           # <-- fill
KEYCHAIN_PROFILE="AC_PASSWORD_PROFILE" # set up notarytool profile

# Update version (agvtool assumes CFBundleShortVersionString/CFBundleVersion wired)
agvtool new-marketing-version "$VERSION"
agvtool next-version -all

git commit -am "chore: bump version to $VERSION"
git tag -a "v$VERSION" -m "Release v$VERSION"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" \
  -configuration Release -archivePath "$ARCHIVE_PATH" archive

APP_BUNDLE=$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name "*.app" | head -n1)
cp -R "$APP_BUNDLE" "$APP_EXPORT"

# Sign (if you need to re-sign)
codesign --force --options runtime --deep -s "Developer ID Application: $TEAM_ID" "$APP_EXPORT"

# Create DMG (simple)
hdiutil create -volname "DevReader" -srcfolder "$APP_EXPORT" -ov -format UDZO "$DMG"

# Notarize
xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "✓ Release artifact: $DMG"
echo "Next: upload to GitHub release or App Store Connect."
