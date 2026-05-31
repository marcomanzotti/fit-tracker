#!/bin/bash
#
# Builds an UNSIGNED FitTracker.ipa for sideloading with SideStore.
# SideStore re-signs the app on your iPhone with your own (free) Apple ID,
# so we deliberately build with code signing turned off here.
#
set -euo pipefail
cd "$(dirname "$0")"

APP="FitTracker"

# 1. Make sure xcodebuild points at the full Xcode (not just Command Line Tools).
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "❌  'xcodebuild' can't find Xcode."
  echo "    Run this once, then retry:"
  echo "      sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "▶︎  Using $(xcodebuild -version | head -1)"
echo "▶︎  Cleaning…"
rm -rf build Payload "$APP.ipa"

# 2. Compile a Release build for a real device, with signing disabled.
echo "▶︎  Building (this can take a minute)…"
xcodebuild \
  -project "$APP.xcodeproj" \
  -scheme "$APP" \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build

# 3. Locate the built .app and package it as an .ipa (a zip with a Payload/ folder).
APP_PATH=$(find build/Build/Products -name "$APP.app" -maxdepth 3 -type d | head -1)
if [ -z "$APP_PATH" ]; then
  echo "❌  Build succeeded but $APP.app was not found."
  exit 1
fi

echo "▶︎  Packaging $APP.ipa…"
mkdir -p Payload
cp -R "$APP_PATH" Payload/
/usr/bin/zip -qry "$APP.ipa" Payload
rm -rf Payload

echo ""
echo "✅  Done →  $(pwd)/$APP.ipa"
echo "    Send this .ipa to your iPhone and open it with SideStore (see README)."
