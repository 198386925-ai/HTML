#!/bin/bash
# Build unsigned HTML IPA from repository source (macOS runner).
# Reuses the LUIYoAdmin-Build workflow contract:
#   - project HTML.xcodeproj, scheme HTML
#   - output/*.ipa and output/*-src.zip (the workflow shasums both)
#   - unsigned; sign before installation, as with LUIYo
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP_NAME=HTML

xcodebuild -version
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
case "$SDK_VERSION" in
  26.*) ;;
  *) echo "ERROR: This app requires an iOS 26 SDK (native UIGlassEffect); found $SDK_VERSION"; exit 1 ;;
esac

mkdir -p output
xcodebuild \
  -project HTML.xcodeproj \
  -scheme HTML -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon build

APP="build/Build/Products/Release-iphoneos/${APP_NAME}.app"
test -f "$APP/$APP_NAME"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")
BUILT_SDK=$(/usr/libexec/PlistBuddy -c 'Print :DTSDKName' "$APP/Info.plist")
case "$BUILT_SDK" in
  iphoneos26.*) ;;
  *) echo "ERROR: Incorrect built SDK: $BUILT_SDK (expected iphoneos26.*)"; exit 1 ;;
esac

STAGE=$(mktemp -d "$ROOT/build/package.XXXXXX")
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
NAME="${APP_NAME}-${VERSION}-Build(${BUILD}).ipa"
(cd "$STAGE" && /usr/bin/zip -qry "$ROOT/output/$NAME" Payload)
unzip -t "output/$NAME"

# Clean source backup zip (full real source only; no build artifacts,
# no git metadata, no output). This is the file the standing IPA rules
# require to accompany every IPA delivery.
SRC_NAME="${APP_NAME}-${VERSION}-Build(${BUILD})-src.zip"
(cd "$ROOT" && /usr/bin/zip -qry "output/$SRC_NAME" . -x 'build/*' -x 'output/*' -x '.git/*' -x '.gitignore')
unzip -t "output/$SRC_NAME"

echo "IPA: output/$NAME (unsigned; sign before installation)"
echo "SRC: output/$SRC_NAME"
