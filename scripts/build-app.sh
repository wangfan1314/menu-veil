#!/bin/zsh
set -euo pipefail

ROOT_DIR=${0:A:h:h}
APP_DIR="$ROOT_DIR/dist/MenuVeil.app"
CONTENTS_DIR="$APP_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGN_IDENTITY=${MENUVEIL_SIGN_IDENTITY:-${BAR_EVERYTHING_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(.*\)"/\1/p' | head -n 1)}}

swift build --package-path "$ROOT_DIR" -c release
mkdir -p "$CONTENTS_DIR/MacOS" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/BarEverything" "$CONTENTS_DIR/MacOS/BarEverything"
cp "$ROOT_DIR/Assets/MenuVeil.icns" "$RESOURCES_DIR/MenuVeil.icns"

plutil -create xml1 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleDevelopmentRegion -string zh_CN "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleDisplayName -string MenuVeil "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleExecutable -string BarEverything "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIconFile -string MenuVeil.icns "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIdentifier -string com.wangzhizhong.MenuVeil "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleName -string MenuVeil "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleShortVersionString -string 0.1.0 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleVersion -string 1 "$CONTENTS_DIR/Info.plist"
plutil -insert LSMinimumSystemVersion -string 14.0 "$CONTENTS_DIR/Info.plist"

SIGN_ARGS=(--force --deep --sign "${SIGN_IDENTITY:--}")
if [[ "$SIGN_IDENTITY" == "Developer ID Application:"* ]]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi
codesign "${SIGN_ARGS[@]}" "$APP_DIR"
echo "Signed with: ${SIGN_IDENTITY:-ad-hoc}"
echo "$APP_DIR"
